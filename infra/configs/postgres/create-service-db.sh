#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-service-db.sh <service_key>

Example:
  create-service-db.sh auth
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

service_key="${1^^}"
db_name_file="/run/secrets/DB_${service_key}_SERVICE_NAME"
db_user_file="/run/secrets/DB_${service_key}_SERVICE_USER"
db_pass_file="/run/secrets/DB_${service_key}_SERVICE_PASS"

for file in "$db_name_file" "$db_user_file" "$db_pass_file"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing secret file: $file" >&2
    exit 1
  fi
done

db_name="$(cat "$db_name_file")"
db_user="$(cat "$db_user_file")"
db_password="$(cat "$db_pass_file")"

pg_password=$(cat "/run/secrets/POSTGRES_PASSWORD")
pg_user=$(cat "/run/secrets/POSTGRES_USER")

export PGPASSWORD="$pg_password"

psql \
  -h 127.0.0.1 \
  -U "$pg_user" \
  -d postgres \
  -v ON_ERROR_STOP=1 \
  -v db_name="$db_name" \
  -v db_user="$db_user" \
  -v db_password="$db_password" <<'EOSQL'
SELECT format(
  'CREATE ROLE %I LOGIN PASSWORD %L',
  :'db_user',
  :'db_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = :'db_user'
)\gexec

SELECT format(
  'CREATE DATABASE %I OWNER %I',
  :'db_name',
  :'db_user'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = :'db_name'
)\gexec
EOSQL
