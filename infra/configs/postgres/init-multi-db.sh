#!/usr/bin/env bash
set -euo pipefail

IFS=',' read -ra DBS <<< "$POSTGRES_MULTIPLE_DATABASES"

for db in "${DBS[@]}"; do
  /usr/local/bin/create-service-db.sh "$db"
done
