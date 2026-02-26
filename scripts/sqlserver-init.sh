#!/bin/bash
set -eu

SQLCMD_BIN="/opt/mssql-tools18/bin/sqlcmd"
SQLSERVER_BIN="/opt/mssql/bin/sqlservr"
SA_USER="sa"
DB_NAME="IdabusIdentitySolution"
TABLE_NAMES="Resources Events EventsArchive WorkflowExecutions"

shutdown() {
  if kill -0 "$SQL_PID" >/dev/null 2>&1; then
    kill -TERM "$SQL_PID"
    wait "$SQL_PID"
  fi
}

trap shutdown INT TERM

# Start SQL Server because the compose command overrides image defaults.
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
if [ "$DB_EXISTS" != "1" ]; then
  echo "Failed to ensure database [$DB_NAME]." >&2
  exit 1
fi
echo "Database [$DB_NAME] is ready."

echo "Ensuring READ_COMMITTED_SNAPSHOT is enabled..."
"$SQLCMD_BIN" -S localhost -U "$SA_USER" -P "$SA_PASSWORD" -C -Q "IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'$DB_NAME' AND is_read_committed_snapshot_on = 0) ALTER DATABASE [$DB_NAME] SET READ_COMMITTED_SNAPSHOT ON;"

for table_name in $TABLE_NAMES; do
  echo "Ensuring table [$table_name] and indexes exist..."
  "$SQLCMD_BIN" -S localhost -U "$SA_USER" -P "$SA_PASSWORD" -C -Q "
USE [$DB_NAME];
IF OBJECT_ID(N'dbo.[$table_name]', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[$table_name]
  (
    [Id] BIGINT IDENTITY(1,1) NOT NULL,
    [ObjectId] UNIQUEIDENTIFIER NOT NULL,
    [LastUpdateTime] BIGINT NOT NULL,
    [JsonData] NVARCHAR(MAX) NOT NULL,
    CONSTRAINT [PK_${table_name}] PRIMARY KEY CLUSTERED ([Id])
  );
END;

IF NOT EXISTS (
  SELECT 1
  FROM sys.indexes
  WHERE object_id = OBJECT_ID(N'dbo.[$table_name]')
    AND name = N'UQ_${table_name}_ObjectId'
)
BEGIN
  CREATE UNIQUE NONCLUSTERED INDEX [UQ_${table_name}_ObjectId]
    ON [dbo].[$table_name] ([ObjectId]);
END;

IF NOT EXISTS (
  SELECT 1
  FROM sys.indexes
  WHERE object_id = OBJECT_ID(N'dbo.[$table_name]')
    AND name = N'IX_${table_name}_LastUpdateTime'
)
BEGIN
  CREATE NONCLUSTERED INDEX [IX_${table_name}_LastUpdateTime]
    ON [dbo].[$table_name] ([LastUpdateTime]);
END;
"
done

echo "SQL bootstrap completed successfully."

wait "$SQL_PID"
