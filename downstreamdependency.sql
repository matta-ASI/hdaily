-- Find procedures that depend on a specific table
SELECT 
    OBJECT_NAME(referencing_id) AS DependentObjectName,
    referenced_entity_name AS ReferencedTableName
FROM 
    sys.sql_expression_dependencies
WHERE 
    referenced_entity_name IN ('YourTableName') -- Replace with dynamic list of modified tables
    AND referenced_class = 1; -- 1 = Object or column


-- Find SQL Agent jobs that reference modified tables or dependent procedures
SELECT 
    j.name AS JobName,
    js.step_name AS StepName,
    js.command AS JobCommand
FROM 
    msdb.dbo.sysjobsteps js
INNER JOIN 
    msdb.dbo.sysjobs j ON js.job_id = j.job_id
WHERE 
    js.subsystem = 'TSQL'
    AND (
        js.command LIKE '%YourTableName%' OR
        js.command LIKE '%YourProcName%'
    );


-- Query SQL Agent job steps for table references
SELECT 
    j.name AS JobName,
    js.step_name AS StepName,
    js.command AS JobCommand,
    t.name AS TableName
FROM 
    msdb.dbo.sysjobsteps js
INNER JOIN 
    msdb.dbo.sysjobs j ON js.job_id = j.job_id
CROSS APPLY (
    -- Extract table names from job step commands (simplified example)
    SELECT 
        SUBSTRING(js.command, CHARINDEX('FROM ', js.command) + 5, CHARINDEX(' ', js.command, CHARINDEX('FROM ', js.command) + 5) - (CHARINDEX('FROM ', js.command) + 5)) AS TableName
    WHERE 
        js.command LIKE '%FROM %'
    UNION ALL
    SELECT 
        SUBSTRING(js.command, CHARINDEX('INTO ', js.command) + 5, CHARINDEX(' ', js.command, CHARINDEX('INTO ', js.command) + 5) - (CHARINDEX('INTO ', js.command) + 5)) AS TableName
    WHERE 
        js.command LIKE '%INTO %'
) t
WHERE 
    js.subsystem = 'TSQL' -- Filter for T-SQL job steps
    AND t.TableName IS NOT NULL;