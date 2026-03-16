#!/bin/bash
set -e

IFS=',' read -ra DBS <<< "$POSTGRES_MULTIPLE_DATABASES"

for db in "${DBS[@]}"; do
  DB_NAME=$(cat "/run/secrets/DB_${db^^}_SERVICE_NAME")
  DB_USER=$(cat "/run/secrets/DB_${db^^}_SERVICE_USER")
  DB_PASSWORD=$(cat "/run/secrets/DB_${db^^}_SERVICE_PASS")

  echo "Creating database $DB_NAME"

  psql "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/postgres" -v ON_ERROR_STOP=1 <<-EOSQL
      CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
      CREATE DATABASE $DB_NAME OWNER $DB_USER;
EOSQL

done