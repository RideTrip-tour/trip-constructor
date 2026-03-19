#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: infra/run-swarm-migrations.sh <docker_context> <run_id> <service_key> <image_ref>

Example:
  infra/run-swarm-migrations.sh swarm 123456 auth ride2trip/auth-service:dev-abcd123

For service_key=auth the script expects these swarm secrets:
  DB_AUTH_SERVICE_HOST
  DB_AUTH_SERVICE_PORT
  DB_AUTH_SERVICE_NAME
  DB_AUTH_SERVICE_USER
  DB_AUTH_SERVICE_PASS
EOF
}

if [[ $# -ne 4 ]]; then
  usage >&2
  exit 1
fi

docker_context="$1"
run_id="$2"
service_key="$3"
image_ref="$4"

service_slug="${service_key//_/-}"
service_upper="${service_key^^}"
service_name="${service_slug}-migrate-${run_id}"
network_name="data-network"

docker_cmd=(docker --context "$docker_context")

secrets=(
  "DB_${service_upper}_SERVICE_HOST"
  "DB_${service_upper}_SERVICE_PORT"
  "DB_${service_upper}_SERVICE_NAME"
  "DB_${service_upper}_SERVICE_USER"
  "DB_${service_upper}_SERVICE_PASS"
)

envs=(
  "APP_MODE=migrate"
  "DB_${service_upper}_SERVICE_HOST_FILE=/run/secrets/DB_${service_upper}_SERVICE_HOST"
  "DB_${service_upper}_SERVICE_PORT_FILE=/run/secrets/DB_${service_upper}_SERVICE_PORT"
  "DB_${service_upper}_SERVICE_NAME_FILE=/run/secrets/DB_${service_upper}_SERVICE_NAME"
  "DB_${service_upper}_SERVICE_USER_FILE=/run/secrets/DB_${service_upper}_SERVICE_USER"
  "DB_${service_upper}_SERVICE_PASS_FILE=/run/secrets/DB_${service_upper}_SERVICE_PASS"
)

create_args=(
  service create
  --name "$service_name"
  --restart-condition none
  --mode replicated-job
  --network "$network_name"
)

for secret_name in "${secrets[@]}"; do
  create_args+=(--secret "$secret_name")
done

for env_var in "${envs[@]}"; do
  create_args+=(--env "$env_var")
done

create_args+=(--with-registry-auth "$image_ref")

"${docker_cmd[@]}" service rm "$service_name" >/dev/null 2>&1 || true
"${docker_cmd[@]}" "${create_args[@]}"

deadline=$((SECONDS + 300))
completed="false"

while (( SECONDS < deadline )); do
  state="$("${docker_cmd[@]}" service ps "$service_name" --format "{{.CurrentState}}" | head -n1)"
  echo "state=$state"

  if [[ -z "$state" ]]; then
    replicas="$("${docker_cmd[@]}" service ls --filter "name=$service_name" --format "{{.Replicas}}" | head -n1)"
    echo "replicas=$replicas"
    if echo "$replicas" | grep -q "(1/1 completed)"; then
      completed="true"
      break
    fi
  fi

  if echo "$state" | grep -q "Complete"; then
    completed="true"
    break
  fi

  if echo "$state" | grep -Eqi "Failed|Rejected|non-zero exit"; then
    break
  fi

  sleep 5
done

if [[ "$completed" != "true" ]]; then
  "${docker_cmd[@]}" service logs "$service_name" || true
  "${docker_cmd[@]}" service rm "$service_name" || true
  exit 1
fi

"${docker_cmd[@]}" service logs "$service_name" || true
"${docker_cmd[@]}" service rm "$service_name" || true
