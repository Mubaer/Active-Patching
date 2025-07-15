# Aufrufen auf WSUS-Server
# Fuehrt einen CLeanup durch, alte Updates werden declined und anschliessend gelöscht.
# Regelmaessig ausführen, einmal pro Woche Montag Abend
# Parameter: keine
# Rueckgabe: Ergebnis des Bereinigungsvorgangs.

# Diese Variante kommt ohne zusätzliche Software aus :)

function ShrinkDatabaseFile(){ 
 $connection = New-Object System.Data.SqlClient.SqlConnection
 $connection.ConnectionString = 'server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true;'
 $connection.Open()
 $command = $connection.CreateCommand()
 $command.CommandText = "USE SUSDB; DBCC SHRINKFILE (N'SUSDB' , 0)"
 $command.CommandTimeout=0
 $result = $command.ExecuteReader()
 $connection.Close()
}

function ShrinkDatabaseLogFile(){ 
 $connection = New-Object System.Data.SqlClient.SqlConnection
 $connection.ConnectionString = 'server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true;'
 $connection.Open()
 $command = $connection.CreateCommand()
 $command.CommandText = "USE SUSDB; DBCC SHRINKFILE (N'SUSDB_LOG' , 0)"
 $command.CommandTimeout=0
 $result = $command.ExecuteReader()
 $connection.Close()
}

function CleanUpDatabase($server, $database, $query)
{
 $connection = New-Object System.Data.SqlClient.SqlConnection
 $connection.ConnectionString = 'server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true;'
 $connection.Open()
 $command = $connection.CreateCommand()
 $command.CommandText = $query
 $command.CommandTimeout=0
 $result = $command.ExecuteReader()
 $table = new-object "System.Data.DataTable"
 $table.Load($result)
 $connection.Close()
 return $table
}

$server = "localhost"
$database = "SUSDB"
$sql = "
USE SUSDB; 
SET NOCOUNT ON; 
DECLARE @work_to_do TABLE ( 
    objectid int 
    , indexid int 
    , pagedensity float 
    , fragmentation float 
    , numrows int 
) 
DECLARE @objectid int; 
DECLARE @indexid int; 
DECLARE @schemaname nvarchar(130);  
DECLARE @objectname nvarchar(130);  
DECLARE @indexname nvarchar(130);  
DECLARE @numrows int 
DECLARE @density float; 
DECLARE @fragmentation float; 
DECLARE @command nvarchar(4000);  
DECLARE @fillfactorset bit 
DECLARE @numpages int 
PRINT 'Estimating fragmentation: Begin. ' + convert(nvarchar, getdate(), 121)  
INSERT @work_to_do 
SELECT 
    f.object_id 
    , index_id 
    , avg_page_space_used_in_percent 
    , avg_fragmentation_in_percent 
    , record_count 
FROM  
    sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'SAMPLED') AS f 
WHERE 
    (f.avg_page_space_used_in_percent < 85.0 and f.avg_page_space_used_in_percent/100.0 * page_count < page_count - 1) 
    or (f.page_count > 50 and f.avg_fragmentation_in_percent > 15.0) 
    or (f.page_count > 10 and f.avg_fragmentation_in_percent > 80.0) 
 
PRINT 'Number of indexes to rebuild: ' + cast(@@ROWCOUNT as nvarchar(20)) 
 
PRINT 'Estimating fragmentation: End. ' + convert(nvarchar, getdate(), 121) 
 
SELECT @numpages = sum(ps.used_page_count) 
FROM 
    @work_to_do AS fi 
    INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id 
    INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id 
 
DECLARE curIndexes CURSOR FOR SELECT * FROM @work_to_do 
OPEN curIndexes 
WHILE (1=1) 
BEGIN 
    FETCH NEXT FROM curIndexes 
    INTO @objectid, @indexid, @density, @fragmentation, @numrows; 
    IF @@FETCH_STATUS < 0 BREAK; 
 
    SELECT  
        @objectname = QUOTENAME(o.name) 
        , @schemaname = QUOTENAME(s.name) 
    FROM  
        sys.objects AS o 
        INNER JOIN sys.schemas as s ON s.schema_id = o.schema_id 
    WHERE  
        o.object_id = @objectid; 
 
    SELECT  
        @indexname = QUOTENAME(name) 
        , @fillfactorset = CASE fill_factor WHEN 0 THEN 0 ELSE 1 END 
    FROM  
        sys.indexes 
    WHERE 
        object_id = @objectid AND index_id = @indexid; 
 
    IF ((@density BETWEEN 75.0 AND 85.0) AND @fillfactorset = 1) OR (@fragmentation < 30.0) 
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REORGANIZE'; 
    ELSE IF @numrows >= 5000 AND @fillfactorset = 0 
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD WITH (FILLFACTOR = 90)'; 
    ELSE 
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD'; 
    PRINT convert(nvarchar, getdate(), 121) + N' Executing: ' + @command; 
    EXEC (@command); 
    PRINT convert(nvarchar, getdate(), 121) + N' Done.'; 
END 
CLOSE curIndexes; 
DEALLOCATE curIndexes; 
 
 
IF EXISTS (SELECT * FROM @work_to_do) 
BEGIN 
    PRINT 'Estimated number of pages in fragmented indexes: ' + cast(@numpages as nvarchar(20)) 
    SELECT @numpages = @numpages - sum(ps.used_page_count) 
    FROM 
        @work_to_do AS fi 
        INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id 
        INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id 
 
    PRINT 'Estimated number of pages freed: ' + cast(@numpages as nvarchar(20)) 
END 
PRINT 'Updating all statistics.' + convert(nvarchar, getdate(), 121)  
EXEC sp_updatestats 
PRINT 'Done updating statistics.' + convert(nvarchar, getdate(), 121)  
"

$version = "2.0.2"
Import-Module poshwsus
Import-Module pswindowsupdate
Connect-PSWSUSServer -WsusServer localhost -Port 8530
Get-WsusServer -Name localhost -PortNumber 8530


$date1 = $(Get-Date).AddDays(-180)
$date2 = $(Get-Date).AddDays(-30)

# Cleanup Database

Write-Host "Cleaning up database ..." -ForegroundColor Green
Get-PSWSUSUpdate -ToCreationDate $date1 | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -IncludeText "Security Intelligence Update" -ToCreationDate $date2 | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -IncludeText "Edge-" -ToCreationDate $date2 | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-WsusServer | Invoke-WsusServerCleanup -CleanupObsoleteUpdates -CleanupUnneededContentFiles -CompressUpdates -DeclineExpiredUpdates -DeclineSupersededUpdates
CleanUpDatabase $Server $Database $sql
Write-Host "Shrinking Database file ..." -ForegroundColor Green
ShrinkDatabaseFile
Write-Host "Shrinking Database Log file ..." -ForegroundColor Green
ShrinkDatabaseLogFile
