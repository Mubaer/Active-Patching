# Usage: aufrufen auf WSUS-Server ohne Parameter
# approve en gros fuer alle Kunden
# auf WSUS-Server ausfuehren
# 1 mal woechentlich Donnerstag
# Rueckgabe: keine

# Wollen wir nur alle Freigaben zurueckziehen ("revoke") oder wollen wir ZUSAETZLICH auch
# freigeben ("approve")

param (
    [Parameter(Mandatory=$true)][string]$modus
    )

if($modus -notlike "approve" -and $modus -notlike "revoke"){

# Ansible hat keinen Parameter mitgegeben
# wir steigen aus

break


}
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

$version = "1.6.3" # WSUSutil.exe reset for local cache configurations

Start-Transcript -Path "C:\mr_managed_it\Logs\decline_approve.txt" #-Append

Write-Host $version

Write-Host "Going into " $modus "-Mode"

Get-Service -name 'WsusService' | Stop-Service
Get-Service -name 'MSSQL$MICROSOFT##WID' | Stop-Service

Get-Service -name 'MSSQL$MICROSOFT##WID' | Start-Service
Get-Service -name 'WsusService' | Start-Service
iisreset.exe

Start-Sleep -Seconds 60


if ((Test-Path "C:\mr_managed_it\scripts\kb_decline_approve.csv") -and (Test-Path "C:\mr_managed_it\scripts\category_decline_approve.csv") ){

Write-Host "Both decline-files found. Continuing ..."

Import-Module poshwsus
Import-Module pswindowsupdate
Connect-PSWSUSServer -WsusServer localhost -Port 8530
Get-WsusServer -Name localhost -PortNumber 8530


$date1 = $(Get-Date).AddDays(-180)
$date2 = $(Get-Date).AddDays(-30)
$GroupsAll    = Get-PSWSUSGroup -Name 'MR_Server', 'MR_Server_SQL', 'MR_Server_HV', 'MR_Server_DC', 'MR_Server_RDS', 'MR_Server_CA', 'MR_Server_EX', 'MR_Server_File', 'MR_Server_PR'
$GroupsSQL    = Get-PSWSUSGroup -Name 'MR_Server_SQL'
$GroupsSystem = Get-PSWSUSGroup -Name 'MR_System'

<# Find special Customer
$CustomerID = $(Get-WsusServer).GetConfiguration().ServerId
if($CustomerID.Guid -like "e3477b62-a4b6-47e0-b434-831d91d16d83"){
$ApprovalDate = (Get-Date -Day 1).Date.AddMonths(-1).AddMilliseconds(-1).Date.AddMonths(1)
}else{
$ApprovalDate = Get-Date
}
#>

# Step 0 Reset all approvements and declines
Write-Host "Reset all approvals ..."
Get-PSWSUSUpdate -ApprovedState Declined | Approve-PSWSUSUpdate -Group $GroupsSystem -Action NotApproved
Get-WsusUpdate -Approval Approved | ForEach-Object { $_.Update.GetUpdateApprovals() | ForEach-Object Delete }

# If Modus = Approve machen wir weiter mit einer neuen Approve-Aktion, ansonsten belassen wir es beim Revoke

if($modus -like "approve"){


# Step 1 decline unwanted patches
Write-Host "Decline unwanted patches ..."
Get-PSWSUSUpdate -Update "ARM64"                          | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -Update "Itanium"                        | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -Update "Preview of"                     | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -Update "x86-based Systems"              | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -Update "x86 based Editions"             | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -Update "Edge-Dev"                       | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -Update "Edge-Beta"                      | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -Update "Edge-Extended"                  | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate

# Step 2 approve wanted categories
Write-Host "Approve all wanted Categories ..."
Get-PSWSUSUpdate -Update "Edge-Stable"                    | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate -Group $GroupsAll -Action Install
Get-PSWSUSUpdate -Update "Microsoft Edge-WebView2"        | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate -Group $GroupsAll -Action Install
Get-PSWSUSUpdate -Update "Windows Malicious"              | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate -Group $GroupsAll -Action Install
Get-PSWSUSUpdate -Update "Windows Subsystem"              | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate -Group $GroupsAll -Action Install
Get-PSWSUSUpdate -Update "Defender"                       | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate -Group $GroupsAll -Action Install

# Step 3 decline unwanted categories
Write-Host "Decline all unwanted Categories ..."
$CSVData = Import-CSV -Path "C:\mr_managed_it\scripts\category_decline_approve.csv" | Group-Object -Property Category | Sort-Object -Property Name

ForEach($PSItem in $CSVData) {
        $PSItem
        $Category = $PSItem.Name
        $Month = $($PSItem.Group).Month
        "Aktuelle Kategory: " + $Category
        "Aktueller Monat: " + $Month
        
        $MonthStart= [datetime]::ParseExact($Month,'yyyy-MM-dd',$null) #Beginn des Monats kommt von MITO/Ansible
        $MonthEnd = $MonthStart.AddMonths(1).AddDays(-1) #Ende des Monats wird berechnet

if($Month){
        foreach($Group in ($PSItem.Group).Month) {

        write-host $Category "wird fuer " $Month " gesperrt."
        
        Get-PSWSUSUpdate -FromCreationDate $MonthStart -ToCreationDate $MonthEnd | Where-Object {$_.Title -match $Category} | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate #-WhatIf
        }
        }else{
        write-host $Category " wird declined."
        Get-PSWSUSUpdate -Update $Category | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate #-WhatIf
        
        }

        }

# Step 4 approve current month
Write-Host "Approve current month ..."

$include_categories = "Server 2016|Server 2019|Server, version|Server operating system-21H2|Server operating system-22H2|Server operating system-23H2|Server operating system-24H2"
$exclude_categories = "Exchange|Azure|SQL|Sharepoint|Skype" 

$Categories  = Get-PSWSUSCategory|Where-Object{$_.title -match $include_categories -and $_.title -notmatch $exclude_categories}


$Categories | Format-Table -AutoSize

Get-PSWSUSUpdate -Category $Categories | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate  -Group $GroupsAll -Action Install

$include_categories = "SQL"
$exclude_categories = "Exchange|Azure|Sharepoint|Skype" 

$Categories  = Get-PSWSUSCategory | Where-Object{$_.title -match $include_categories -and $_.title -notmatch $exclude_categories}


$Categories | Format-Table -AutoSize

Get-PSWSUSUpdate -Category $Categories | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate  -Group $GroupsSQL -Action Install

# Step 5 decline unwanted kbs
# Step 6 unapprove unwanted kbs for specific groups
Write-Host "Decline unwanted KBs and unapprove unwanted KBs from specific groups ..."
$CSVData = Import-CSV -Path "C:\mr_managed_it\scripts\kb_decline_approve.csv" | Group-Object -Property KB-Number  | Sort-Object -Property Name


ForEach($PSItem in $CSVData) {
        $PSItem
        $KBNumber = $PSItem.Name
        $Groups = $($PSItem.Group).Group
        "Aktuelle KB-Nummer: " + $KBNumber
        "Aktuelle Groups dafuer: " + $Groups


if($Groups){
        foreach($Group in ($PSItem.Group).Group) {

        write-host $KBNumber " wird fuer " $Group " aufgehoben."
        
        $WSUSGroup = Get-PSWSUSGroup -name $Group
        
        Get-PSWSUSUpdate -Update  $KBNumber | Approve-PSWSUSUpdate -Group $WSUSGroup -Action NotApproved
        }
        }else{
        write-host $KBNumber " wird declined."
        Get-PSWSUSUpdate -Update  $KBNumber | Deny-PSWSUSUpdate
        
        }

        }

}


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

# Reset WSUS for local cache configurations

$wsus = (get-wsusserver).GetConfiguration()
if( $wsus.HostBinariesOnMicrosoftUpdate -like "False"){

   & "C:\Program Files\Update Services\Tools\WSUSutil.exe" reset

}


}else{

write-host "Fehler! Mind. einer der Dateien C:\mr_managed_it\Scripts\kb_decline_approve.csv oder category_decline_approve.csv wurde nicht gefunden. Es werden keine Veraenderungen an den WSUS-Freigaben vorgenommen." -ForegroundColor Red

}





Stop-Transcript