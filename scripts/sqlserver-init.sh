#!/bin/bash
set -eu

SQLCMD_BIN="/opt/mssql-tools18/bin/sqlcmd"
SQLSERVER_BIN="/opt/mssql/bin/sqlservr"
SA_USER="sa"
DB_NAME="resources"

shutdown() {
  if kill -0 "$SQL_PID" >/dev/null 2>&1; then
    kill -TERM "$SQL_PID"
    wait "$SQL_PID"
  fi
}

trap shutdown INT TERM

# start squl server, because the custom command overrides the default entrypoint
echo "Starting SQL Server..."
"$SQLSERVER_BIN" &
SQL_PID=$!

echo "Waiting for SQL Server to accept connections..."
until "$SQLCMD_BIN" -S localhost -U "$SA_USER" -P "$SA_PASSWORD" -C -Q "SELECT 1" >/dev/null 2>&1; do
  sleep 2
done

echo "Ensuring database [$DB_NAME] exists..."
"$SQLCMD_BIN" -S localhost -U "$SA_USER" -P "$SA_PASSWORD" -C -Q "IF DB_ID(N'$DB_NAME') IS NULL CREATE DATABASE [$DB_NAME];"

DB_EXISTS=$("$SQLCMD_BIN" -S localhost -U "$SA_USER" -P "$SA_PASSWORD" -C -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN DB_ID(N'$DB_NAME') IS NULL THEN 0 ELSE 1 END;")
if [ "$DB_EXISTS" = "1" ]; then
  echo "Database [$DB_NAME] is ready."
else
  echo "Failed to ensure database [$DB_NAME]." >&2
  exit 1
fi

wait "$SQL_PID"
