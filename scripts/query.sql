-- ============================================================================
-- Configuration Variables (stored in temp table to persist across GO batches)
-- ============================================================================
IF OBJECT_ID('tempdb..#IdabusInstallConfig') IS NOT NULL DROP TABLE #IdabusInstallConfig;
CREATE TABLE #IdabusInstallConfig (
    DatabaseName NVARCHAR(128),
    DataFilePath NVARCHAR(512),
    LogFilePath NVARCHAR(512),
    DataFileSizeGB INT,
    DataFileGrowthGB INT,
    LogFileSizeGB INT,
    LogFileGrowthMB INT,
    TableNames NVARCHAR(MAX)
);

INSERT INTO #IdabusInstallConfig VALUES (
    'IdabusIdentitySolution',                                                  -- DatabaseName
    'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\',   -- DataFilePath
    'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\',   -- LogFilePath
    9,                                                                         -- DataFileSizeGB
    1,                                                                          -- DataFileGrowthGB
    2,                                                                          -- LogFileSizeGB
    512,                                                                        -- LogFileGrowthMB
    'Resources,Events,EventsArchive,WorkflowExecutions'                        -- TableNames
);
GO

-- ============================================================================
-- Check if database already exists
-- ============================================================================
DECLARE @DatabaseName NVARCHAR(128);
SELECT @DatabaseName = DatabaseName FROM #IdabusInstallConfig;

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
BEGIN
    RAISERROR('Database already exists. Aborting.', 16, 1);
    DROP TABLE #IdabusInstallConfig;
    -- Note: RAISERROR doesn't stop execution in all contexts, so we return
END
ELSE
BEGIN
    PRINT 'Database does not exist. Proceeding with creation...';
END
GO

-- ============================================================================
-- Create Database
-- ============================================================================
DECLARE @DatabaseName NVARCHAR(128);
DECLARE @DataFilePath NVARCHAR(512);
DECLARE @LogFilePath NVARCHAR(512);
DECLARE @DataFileSizeGB INT;
DECLARE @DataFileGrowthGB INT;
DECLARE @LogFileSizeGB INT;
DECLARE @LogFileGrowthMB INT;
DECLARE @SQL NVARCHAR(MAX);

SELECT 
    @DatabaseName = DatabaseName,
    @DataFilePath = DataFilePath,
    @LogFilePath = LogFilePath,
    @DataFileSizeGB = DataFileSizeGB,
    @DataFileGrowthGB = DataFileGrowthGB,
    @LogFileSizeGB = LogFileSizeGB,
    @LogFileGrowthMB = LogFileGrowthMB
FROM #IdabusInstallConfig;

-- Only proceed if database doesn't exist
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
BEGIN
    SET @SQL = N'
    CREATE DATABASE ' + QUOTENAME(@DatabaseName) + N'
    ON PRIMARY
    (
        NAME = ' + QUOTENAME(@DatabaseName + N'_Data', '''') + N',
        FILENAME = ''' + @DataFilePath + @DatabaseName + N'.mdf'',
        SIZE = ' + CAST(@DataFileSizeGB AS NVARCHAR(10)) + N'GB,
        FILEGROWTH = ' + CAST(@DataFileGrowthGB AS NVARCHAR(10)) + N'GB
    )
    LOG ON
    (
        NAME = ' + QUOTENAME(@DatabaseName + N'_Log', '''') + N',
        FILENAME = ''' + @LogFilePath + @DatabaseName + N'_log.ldf'',
        SIZE = ' + CAST(@LogFileSizeGB AS NVARCHAR(10)) + N'GB,
        FILEGROWTH = ' + CAST(@LogFileGrowthMB AS NVARCHAR(10)) + N'MB
    );';

    EXEC sp_executesql @SQL;
    PRINT 'Database created successfully.';
END
GO

-- ============================================================================
-- Enable RCSI
-- ============================================================================
DECLARE @DatabaseName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

SELECT @DatabaseName = DatabaseName FROM #IdabusInstallConfig;

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
BEGIN
    SET @SQL = N'ALTER DATABASE ' + QUOTENAME(@DatabaseName) + N' SET READ_COMMITTED_SNAPSHOT ON;';
    EXEC sp_executesql @SQL;
    PRINT 'RCSI enabled successfully.';
END
GO

-- ============================================================================
-- Create all tables using a loop
-- ============================================================================
DECLARE @DatabaseName NVARCHAR(128);
DECLARE @TableNames NVARCHAR(MAX);
DECLARE @TableName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

SELECT 
    @DatabaseName = DatabaseName,
    @TableNames = TableNames 
FROM #IdabusInstallConfig;

-- Only proceed if database exists
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
BEGIN
    -- Create a table variable to hold table names
    DECLARE @TableList TABLE (TableName NVARCHAR(128));

    INSERT INTO @TableList (TableName)
    SELECT TRIM(value) 
    FROM STRING_SPLIT(@TableNames, ',');

    -- Loop through each table name and create table with indexes
    DECLARE table_cursor CURSOR FOR 
        SELECT TableName FROM @TableList;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Create table (note: we specify the database name in the SQL)
        SET @SQL = N'
        USE ' + QUOTENAME(@DatabaseName) + N';
        CREATE TABLE ' + QUOTENAME(@TableName) + N'
        (
            Id BIGINT IDENTITY(1,1) NOT NULL,
            ObjectId UNIQUEIDENTIFIER NOT NULL,
            LastUpdateTime BIGINT NOT NULL,
            JsonData NVARCHAR(MAX) NOT NULL,
            
            CONSTRAINT PK_' + @TableName + N' PRIMARY KEY CLUSTERED (Id)
            WITH (FILLFACTOR = 100)
        );';
        EXEC sp_executesql @SQL;

        -- Create unique index on ObjectId
        SET @SQL = N'
        USE ' + QUOTENAME(@DatabaseName) + N';
        CREATE UNIQUE NONCLUSTERED INDEX UQ_' + @TableName + N'_ObjectId 
            ON ' + QUOTENAME(@TableName) + N'(ObjectId)
            WITH (FILLFACTOR = 90);';
        EXEC sp_executesql @SQL;

        -- Create index on LastUpdateTime
        SET @SQL = N'
        USE ' + QUOTENAME(@DatabaseName) + N';
        CREATE NONCLUSTERED INDEX IX_' + @TableName + N'_LastUpdateTime 
            ON ' + QUOTENAME(@TableName) + N'(LastUpdateTime)
            WITH (FILLFACTOR = 90);';
        EXEC sp_executesql @SQL;

        PRINT 'Created table: ' + @TableName;

        FETCH NEXT FROM table_cursor INTO @TableName;
    END;

    CLOSE table_cursor;
    DEALLOCATE table_cursor;
END
GO

-- ============================================================================
-- Verification
-- ============================================================================
DECLARE @DatabaseName NVARCHAR(128);
SELECT @DatabaseName = DatabaseName FROM #IdabusInstallConfig;

PRINT '';
PRINT '=== Database Created Successfully ===';
PRINT '';

SELECT name, is_read_committed_snapshot_on
FROM sys.databases
WHERE name = @DatabaseName;

PRINT '';
PRINT '=== Tables Created ===';
PRINT '';

DECLARE @SQL NVARCHAR(MAX);
SET @SQL = N'
USE ' + QUOTENAME(@DatabaseName) + N';
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.tables t
LEFT JOIN sys.indexes i ON t.object_id = i.object_id
WHERE t.name IN (''Resources'', ''Events'', ''EventsArchive'', ''WorkflowExecutions'')
ORDER BY t.name, i.index_id;';

EXEC sp_executesql @SQL;
GO

-- ============================================================================
-- Cleanup
-- ============================================================================
DROP TABLE #IdabusInstallConfig;
GO
