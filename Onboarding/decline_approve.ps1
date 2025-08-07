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

$version = "2.0.2" # cleanup database ausgelagert

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

# Step 0 Reset all approvements and declines
#Write-Host "Reset all approvals ..."
#Get-PSWSUSUpdate -ApprovedState Declined | Approve-PSWSUSUpdate -Group $GroupsSystem -Action NotApproved
#Get-WsusUpdate -Approval Approved | ForEach-Object { $_.Update.GetUpdateApprovals() | ForEach-Object Delete }

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

Write-Host "Declining old patches ..." -ForegroundColor Green
Get-PSWSUSUpdate -ToCreationDate $date1 | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -IncludeText "Security Intelligence Update" -ToCreationDate $date2 | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate
Get-PSWSUSUpdate -IncludeText "Edge-" -ToCreationDate $date2 | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate


# Reset WSUS for local cache configurations

#$wsus = (get-wsusserver).GetConfiguration()
#if( $wsus.HostBinariesOnMicrosoftUpdate -like "False"){

#   & "C:\Program Files\Update Services\Tools\WSUSutil.exe" reset

#}


}else{

write-host "Fehler! Mind. einer der Dateien C:\mr_managed_it\Scripts\kb_decline_approve.csv oder category_decline_approve.csv wurde nicht gefunden. Es werden keine Veraenderungen an den WSUS-Freigaben vorgenommen." -ForegroundColor Red

}





Stop-Transcript