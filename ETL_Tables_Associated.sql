USE msdb;
GO

-- Check for ETL jobs and their impacted tables
SELECT 
    j.[name] AS JobName,
    j.[description] AS JobDescription,
    js.step_name AS StepName,
    js.subsystem AS Subsystem,
    CASE 
        WHEN js.subsystem = 'SSIS' THEN 'Tables are embedded in SSIS package: ' + js.command
        ELSE js.command 
    END AS CommandText,
    CASE
        WHEN js.subsystem = 'TSQL' THEN 
            (
                -- Extract potential table names from T-SQL commands (simplified parsing)
                SELECT STRING_AGG(DISTINCT QUOTENAME(tbl.value), ', ')
                FROM (
                    SELECT 
                        TRIM(SUBSTRING(cmd.value, CHARINDEX(' ', cmd.value) + 1, 255)) AS value
                    FROM STRING_SPLIT(REPLACE(REPLACE(js.command, CHAR(13), ' '), CHAR(10)) AS cmd
                    WHERE 
                        cmd.value LIKE '%FROM %' 
                        OR cmd.value LIKE '%JOIN %' 
                        OR cmd.value LIKE '%INSERT INTO%' 
                        OR cmd.value LIKE '%UPDATE %' 
                        OR cmd.value LIKE '%MERGE INTO%'
                ) AS parsed
                CROSS APPLY (
                    SELECT 
                        CASE 
                            WHEN CHARINDEX('.', parsed.value) > 0 THEN parsed.value
                            ELSE NULL -- Ignore unqualified names if needed
                        END AS tbl
                ) AS tbl
                WHERE tbl.tbl IS NOT NULL
            )
        ELSE NULL 
    END AS PotentialTables
FROM 
    dbo.sysjobs j
INNER JOIN 
    dbo.sysjobsteps js ON j.job_id = js.job_id
LEFT JOIN 
    dbo.sysjobstepsubsystems jss ON js.subsystem = jss.subsystem
WHERE 
    jss.subsystem IN ('TSQL', 'SSIS') -- Focus on T-SQL and SSIS ETL steps
    AND j.enabled = 1 -- Only active jobs
ORDER BY 
    JobName, js.step_id;