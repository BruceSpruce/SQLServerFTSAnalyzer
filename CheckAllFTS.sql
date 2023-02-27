USE [master]
GO

IF EXISTS (
  SELECT * 
    FROM INFORMATION_SCHEMA.ROUTINES 
   WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'usp_CheckAllFTSCatalogs' 
)
   DROP PROCEDURE [dbo].[usp_CheckAllFTSCatalogs]
GO

----------------------------------------------------------------------------
--- EXECUTE [dbo].[usp_CheckAllFTSCatalogs] --------------------------------
--- EXECUTE [dbo].[usp_CheckAllFTSCatalogs] @DynatraceOutput = 1 -----------
----------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[usp_CheckAllFTSCatalogs]
	@DynatraceOutput BIT = 0
AS

----------------------------------------------------------------------
--- Getting all information about all FTS catalogs on the instance ---
--- Author: miroslaw.swierk@gmail.com - 02.2023 ----------------------
----------------------------------------------------------------------
--- Parameters -------------------------------------------------------
--- @DynatraceOutput - true create output for custom metrics in DT ---
----------------------------------------------------------------------

SET NOCOUNT ON;

DECLARE @query TABLE
(
    query NVARCHAR(MAX) NULL
);
DECLARE @databases TABLE
(
    name NVARCHAR(128) NOT NULL
);
DECLARE @catalogs TABLE
(
    dbname NVARCHAR(128) NOT NULL,
    catalogname NVARCHAR(128) NOT NULL
);
DECLARE @FTS TABLE
(
    dbname NVARCHAR(128) NOT NULL,
    catalogname NVARCHAR(128) NOT NULL,
    AccentSensitivity BIT NOT NULL,
    IndexSizeMB INT NOT NULL,
    ItemCount INT NOT NULL,
    UniqueKeyCount INT NOT NULL,
    LogSizeMB INT NOT NULL,
    MergeStatus BIT NOT NULL,
    PopulateStatus SMALLINT NOT NULL,
    ImportStatus BIT NOT NULL
);
DECLARE @FTS2 TABLE
(
     dbname NVARCHAR(128) NOT NULL,
     catalogname NVARCHAR(128) NOT NULL,
     PopulateCompletionAge DateTime NOT NULL,
     PopulateCompletionDelayMinutes INT NOT NULL
);
DECLARE @var NVARCHAR(MAX);
DECLARE @NewLineChar AS CHAR(2) = CHAR(13) + CHAR(10);
INSERT INTO @databases
SELECT name
FROM sys.databases
WHERE database_id > 4;
---- PRE query ----------------
INSERT INTO @query
SELECT v.line
FROM (
    VALUES
        ('DECLARE @catalogs TABLE'),
        ('('),
        ('dbname NVARCHAR(128) NOT NULL,'),
        ('catalogname NVARCHAR(128) NOT NULL'),
        (');')
) AS v (line);
---- Main query ---------------
INSERT INTO @query
SELECT v.line
FROM @databases d
    CROSS APPLY
(
    VALUES
        ('INSERT INTO @catalogs SELECT ''' + d.name + ''', name FROM [' + d.name + '].[sys].[fulltext_catalogs];')
) AS v (line);
---- POST query ----------------
INSERT INTO @query
SELECT v.line
FROM (
    VALUES
        ('SELECT * FROM @catalogs;')
) AS v (line);
---- Print & Execute ----
SELECT @var = REPLACE(STUFF(( SELECT ISNULL(q.query + @NewLineChar, ' ') 
                              FROM @query q FOR XML PATH('')), 1, 0, ''), '&#x0D;', '');
-- TIP: SQL Server >= 2017 use SELECT @var = STRING_AGG(ISNULL(query, ' '), CHAR(13) + CHAR(10)) FROM @query;
--PRINT @var;
IF (@var IS NOT NULL) 
    INSERT INTO @catalogs EXEC (@var);

--- clean up query
DELETE FROM @query;
---- PRE query for FTS ----------------
INSERT INTO @query
SELECT v.line
FROM (
    VALUES
        ('DECLARE @FTS TABLE'),
        ('('),
        ('dbname NVARCHAR(128) NOT NULL,'),
        ('catalogname NVARCHAR(128) NOT NULL,'),
        ('AccentSensitivity BIT NOT NULL,'),
        ('IndexSizeMB INT NOT NULL,'),
        ('UniqueKeyCount INT NOT NULL,'),
        ('ItemCount INT NOT NULL,'),
        ('LogSizeMB INT NOT NULL,'),
        ('MergeStatus BIT NOT NULL,'),
        ('PopulateStatus SMALLINT NOT NULL,'),
        ('ImportStatus BIT NOT NULL'),
        (');')
) AS v (line);
---- Prepare final query ----
INSERT INTO @query
SELECT v.line
FROM @catalogs d
    CROSS APPLY
(
    VALUES
        ('USE [' + d.dbname + ']'),
        ('INSERT INTO @FTS'),
        ('SELECT ''' + d.dbname + ''', ''' + d.catalogname + ''', FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''AccentSensitivity'') AS AccentSensitivity,'),
        ('CONVERT(NVARCHAR(MAX), FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''IndexSize'')) AS IndexSizeMB,'),
        ('FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''ItemCount''),'),
        ('FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''UniqueKeyCount''),'),
        ('FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''LogSize'') AS LogSizeMB,'),
        ('FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''MergeStatus''),'),
        ('FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''PopulateStatus''),'),
        ('FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''ImportStatus'')')
) AS v (line);
---- Print & Execute ----
---- POST query ----------------
INSERT INTO @query
SELECT v.line
FROM (
    VALUES
        ('SELECT * FROM @FTS;')
) AS v (line);
SELECT @var = REPLACE(STUFF(( SELECT ISNULL(q.query + @NewLineChar, ' ') 
                              FROM @query q FOR XML PATH('')), 1, 0, ''), '&#x0D;', '');
-- TIP: SQL Server >= 2017 use SELECT @var = STRING_AGG(ISNULL(query, ' '), CHAR(13) + CHAR(10)) FROM @query;
PRINT @var;
IF (@var IS NOT NULL) 
    INSERT INTO @FTS EXEC (@var);
--- clean up query
DELETE FROM @query;
---- PRE query for FTS2 ----------------
INSERT INTO @query
SELECT v.line
FROM (
    VALUES
        ('DECLARE @FTS2 TABLE'),
        ('('),
        ('dbname NVARCHAR(128) NOT NULL,'),
        ('catalogname NVARCHAR(128) NOT NULL,'),
        ('PopulateCompletionAge DateTime NOT NULL,'),
        ('PopulateCompletionDelayMinutes INT NOT NULL'),
        (');')
) AS v (line);
---- Prepare final query ----
INSERT INTO @query
SELECT v.line
FROM @catalogs d
    CROSS APPLY
(
    VALUES
        ('USE [' + d.dbname + ']'),
        ('INSERT INTO @FTS2'),
        ('SELECT ''' + d.dbname + ''', ''' + d.catalogname + ''','),
        ('DATEADD(ss, IIF(FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''PopulateCompletionAge'') = 0, DATEDIFF(SECOND,''1/1/1990'', GETDATE()), FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''PopulateCompletionAge'')), ''1/1/1990''),'),    
        ('DATEDIFF(minute, DATEADD(ss, IIF(FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''PopulateCompletionAge'') = 0, DATEDIFF(SECOND,''1/1/1990'', GETDATE()), FULLTEXTCATALOGPROPERTY(''' + d.catalogname + ''', ''PopulateCompletionAge'')), ''1/1/1990''), GETDATE()) AS PopulateCompletionDelayMinutes')
) AS v (line);
---- Print & Execute ----
---- POST query ----------------
INSERT INTO @query
SELECT v.line
FROM (
    VALUES
        ('SELECT * FROM @FTS2;')
) AS v (line);
SELECT @var = REPLACE(STUFF(( SELECT ISNULL(q.query + @NewLineChar, ' ') 
                              FROM @query q FOR XML PATH('')), 1, 0, ''), '&#x0D;', '');
-- TIP: SQL Server >= 2017 use SELECT @var = STRING_AGG(ISNULL(query, ' '), CHAR(13) + CHAR(10)) FROM @query;
PRINT @var;
IF (@var IS NOT NULL) 
    INSERT INTO @FTS2 EXEC (@var);

IF @DynatraceOutput = 0
    SELECT [@FTS].dbname,
           [@FTS].catalogname,
           AccentSensitivity,
           IndexSizeMB,
           ItemCount,
           UniqueKeyCount,
           LogSizeMB,
           MergeStatus,
           MergeStatusDesc =
           (
               SELECT CASE MergeStatus
                          WHEN 0 THEN
                              'Isn''t in progress'
                          WHEN 1 THEN
                              'In progress'
                      END
           ),
           PopulateStatus,
           PopulateStatusDesc =
           (
               SELECT CASE PopulateStatus
                          WHEN 0 THEN
                              'Idle'
                          WHEN 1 THEN
                              'Full Population In Progress'
                          WHEN 2 THEN
                              'Paused'
                          WHEN 3 THEN
                              'Throttled'
                          WHEN 4 THEN
                              'Recovering'
                          WHEN 5 THEN
                              'Shutdown'
                          WHEN 6 THEN
                              'Incremental Population In Progress'
                          WHEN 7 THEN
                              'Building Index'
                          WHEN 8 THEN
                              'Disk Full.  Paused'
                          WHEN 9 THEN
                              'Change Tracking'
                      END
           ),
           ImportStatus,
           ImportStatusDesc =
           (
               SELECT CASE ImportStatus
                          WHEN 0 THEN
                              'Isn''t being imported'
                          WHEN 1 THEN
                              'Is being imported'
                      END
           ),
           PopulateCompletionAge,
           PopulateCompletionDelayMinutes
    FROM @FTS
        LEFT JOIN @FTS2
            ON [@FTS2].dbname = [@FTS].dbname
               AND [@FTS2].catalogname = [@FTS].catalogname;
ELSE -- IF @DynatraceOutput = 0
BEGIN
    DECLARE @FTS3 TABLE
    (
        MetricName NVARCHAR(max) NOT NULL,
        catalogname NVARCHAR(max) NOT NULL,
        IndexSizeMB INT NOT NULL,
        ItemCount INT NOT NULL,
        UniqueKeyCount INT NOT NULL,
        MergeStatus BIT NOT NULL,
        PopulateStatus SMALLINT NOT NULL,
        ImportStatus BIT NOT NULL,
        PopulateCompletionDelayMinutes INT NOT NULL
    )

    INSERT INTO @FTS3
    SELECT (IIF(@@SERVICENAME = 'MSSQLSERVER', @@SERVERNAME, @@SERVICENAME) + '_' + [@FTS].dbname) AS MetricName,
           [@FTS].catalogname,
           IndexSizeMB,
           ItemCount,
           UniqueKeyCount,
           MergeStatus,
           PopulateStatus,
           ImportStatus,
           PopulateCompletionDelayMinutes
    FROM @FTS
        LEFT JOIN @FTS2
            ON [@FTS2].dbname = [@FTS].dbname
               AND [@FTS2].catalogname = [@FTS].catalogname;

    SELECT MetricName + '.FTSIndexSizeMB,catalog=' + catalogname + ' ' + CAST(IndexSizeMB AS NVARCHAR)
    FROM @FTS3
    UNION
    SELECT MetricName + '.FTSItemCount,catalog=' + catalogname + ' ' + CAST(ItemCount AS NVARCHAR)
    FROM @FTS3
    UNION
    SELECT MetricName + '.FTSUniqueKeyCount,catalog=' + catalogname + ' ' + CAST(UniqueKeyCount AS NVARCHAR)
    FROM @FTS3
    UNION
    SELECT MetricName + '.FTSMergeStatus,catalog=' + catalogname + ' ' + CAST(MergeStatus AS NVARCHAR)
    FROM @FTS3
    UNION
    SELECT MetricName + '.FTSPopulateStatus,catalog=' + catalogname + ' ' + CAST(PopulateStatus AS NVARCHAR)
    FROM @FTS3
    UNION
    SELECT MetricName + '.FTSImportStatus,catalog=' + catalogname + ' ' + CAST(ImportStatus AS NVARCHAR)
    FROM @FTS3
    UNION
    SELECT MetricName + '.FTSDelayMin,catalog=' + catalogname + ' ' + CAST(PopulateCompletionDelayMinutes AS NVARCHAR)
    FROM @FTS3
END
GO

---- DICTIONARY ---

-- MergeStatus 
--  1 - Master merge in progress

-- PopulateStatus
--  0 - Idle
--  1 - Full Population In Progress
--  2 - Paused
--  3 - Throttled
--  4 - Recovering
--  5 - Shutdown
--  6 - Incremental Population In Progress
--  7 - Building Index
--  8 - Disk Full.  Paused
--  9 - Change Tracking

-- ImportStatus
--  1 The full-text catalog is being imported



