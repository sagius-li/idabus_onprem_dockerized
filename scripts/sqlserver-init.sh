#!/bin/bash
set -eu

SQLCMD_BIN="/opt/mssql-tools18/bin/sqlcmd"
SA_USER="sa"
DB_NAME="IdabusIdentitySolution"
TABLE_NAMES="Resources Events EventsArchive WorkflowExecutions"
SQLSERVER_HOST="${SQLSERVER_HOST:-sqlserver}"
SQLSERVER_PORT="${SQLSERVER_PORT:-1433}"
MAX_RETRIES="${MAX_RETRIES:-90}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

echo "Waiting for SQL Server at ${SQLSERVER_HOST}:${SQLSERVER_PORT} to accept connections..."
retry=1
until "$SQLCMD_BIN" -S "${SQLSERVER_HOST},${SQLSERVER_PORT}" -U "$SA_USER" -P "$SA_PASSWORD" -C -b -Q "SELECT 1" >/dev/null 2>&1; do
  if [ "$retry" -ge "$MAX_RETRIES" ]; then
    echo "SQL Server did not become ready after $((MAX_RETRIES * SLEEP_SECONDS)) seconds." >&2
    exit 1
  fi
  echo "SQL Server not ready yet (attempt ${retry}/${MAX_RETRIES}), retrying in ${SLEEP_SECONDS}s..."
  retry=$((retry + 1))
  sleep "$SLEEP_SECONDS"
done

echo "Ensuring database [$DB_NAME] exists..."
"$SQLCMD_BIN" -S "${SQLSERVER_HOST},${SQLSERVER_PORT}" -U "$SA_USER" -P "$SA_PASSWORD" -C -b -Q "IF DB_ID(N'$DB_NAME') IS NULL CREATE DATABASE [$DB_NAME];"

DB_EXISTS=$("$SQLCMD_BIN" -S "${SQLSERVER_HOST},${SQLSERVER_PORT}" -U "$SA_USER" -P "$SA_PASSWORD" -C -b -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN DB_ID(N'$DB_NAME') IS NULL THEN 0 ELSE 1 END;")
if [ "$DB_EXISTS" != "1" ]; then
  echo "Failed to ensure database [$DB_NAME]." >&2
  exit 1
fi
echo "Database [$DB_NAME] is ready."

echo "Ensuring READ_COMMITTED_SNAPSHOT is enabled..."
"$SQLCMD_BIN" -S "${SQLSERVER_HOST},${SQLSERVER_PORT}" -U "$SA_USER" -P "$SA_PASSWORD" -C -b -Q "IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'$DB_NAME' AND is_read_committed_snapshot_on = 0) ALTER DATABASE [$DB_NAME] SET READ_COMMITTED_SNAPSHOT ON;"

for table_name in $TABLE_NAMES; do
  echo "Ensuring table [$table_name] and indexes exist..."
  "$SQLCMD_BIN" -S "${SQLSERVER_HOST},${SQLSERVER_PORT}" -U "$SA_USER" -P "$SA_PASSWORD" -C -b -Q "
USE [$DB_NAME];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
IF OBJECT_ID(N'dbo.[$table_name]', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[$table_name]
  (
    [Id] BIGINT IDENTITY(1,1) NOT NULL,
    [ObjectId] UNIQUEIDENTIFIER NOT NULL,
    [LastUpdateTime] BIGINT NOT NULL,
    [JsonData] NVARCHAR(MAX) NOT NULL,
    [IsDeleted] BIT NOT NULL CONSTRAINT [DF_${table_name}_IsDeleted] DEFAULT ((0)),
    CONSTRAINT [PK_${table_name}] PRIMARY KEY CLUSTERED ([Id])
  );
  CREATE UNIQUE NONCLUSTERED INDEX [UQ_${table_name}_ObjectId]
    ON [dbo].[$table_name] ([ObjectId])
    WHERE [IsDeleted] = 0;
  CREATE NONCLUSTERED INDEX [IX_${table_name}_IsDeleted_LastUpdateTime]
    ON [dbo].[$table_name] ([IsDeleted], [LastUpdateTime]);
END;
"
done

echo "Ensuring table [Metadata] exists..."
"$SQLCMD_BIN" -S "${SQLSERVER_HOST},${SQLSERVER_PORT}" -U "$SA_USER" -P "$SA_PASSWORD" -C -b -Q "
USE [$DB_NAME];
IF OBJECT_ID(N'dbo.[Metadata]', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[Metadata]
  (
    [EntryKey] NVARCHAR(128) NOT NULL,
    [LastSuccessfulFlushUtc] BIGINT NOT NULL,
    [FailedItemsJson] NVARCHAR(MAX) NOT NULL,
    [UpdatedUtc] BIGINT NOT NULL,
    CONSTRAINT [PK_Metadata] PRIMARY KEY CLUSTERED ([EntryKey])
  );
END;
"

echo "SQL bootstrap completed successfully."
