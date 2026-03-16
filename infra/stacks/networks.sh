#!/usr/bin/env bash
set -euo pipefail

networks=(
  "data-network"
  "internal-network"
)

for network in "${networks[@]}"; do
  if docker network inspect "$network" >/dev/null 2>&1; then
    echo "Network '$network' already exists"
  else
    echo "Creating network '$network'"
    docker network create --driver overlay --attachable "$network" >/dev/null
  fi
done
