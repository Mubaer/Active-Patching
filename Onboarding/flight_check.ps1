function Get-ActivationStatus {
    [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
            [string]$DNSHostName = $Env:COMPUTERNAME
        )
        process {
            try {
                $wpa = Get-WmiObject SoftwareLicensingProduct -ComputerName $DNSHostName `
                -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'" `
                -Property LicenseStatus -ErrorAction Stop
            } catch {
                $status = New-Object ComponentModel.Win32Exception ($_.Exception.ErrorCode)
                $wpa = $null    
            }
            $out = New-Object psobject -Property @{
                ComputerName = $DNSHostName;
                Status = [string]::Empty;
            }
            if ($wpa) {
                :outer foreach($item in $wpa) {
                    switch ($item.LicenseStatus) {
                        0 {$out.Status = "Unlicensed"}
                        1 {$out.Status = "Licensed"; break outer}
                        2 {$out.Status = "Out-Of-Box Grace Period"; break outer}
                        3 {$out.Status = "Out-Of-Tolerance Grace Period"; break outer}
                        4 {$out.Status = "Non-Genuine Grace Period"; break outer}
                        5 {$out.Status = "Notification"; break outer}
                        6 {$out.Status = "Extended Grace"; break outer}
                        default {$out.Status = "Unknown value"}
                    }
                }
            } else {$out.Status = $status.Message}
            $out
        }
    
    }
function Get-InstalledSoftware {
        <#
        .SYNOPSIS
            Retrieves a list of all software installed on a Windows computer.
        .EXAMPLE
            PS> Get-InstalledSoftware
            
            This example retrieves all software installed on the local computer.
        .PARAMETER ComputerName
            If querying a remote computer, use the computer name here.
        
        .PARAMETER Name
            The software title you'd like to limit the query to.
        
        .PARAMETER Guid
            The software GUID you'e like to limit the query to
        #>
        [CmdletBinding()]
        param (
            
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$ComputerName = $env:COMPUTERNAME,
            
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$Name,
            
            [Parameter()]
            [guid]$Guid
        )
        process {
            try {
                $scriptBlock = {
                    $args[0].GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value }
                    
                    $UninstallKeys = @(
                        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                    )
                    #New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
                    #$UninstallKeys += Get-ChildItem HKU: | Where-Object{ $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | ForEach-Object {
                    #    "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                    #}

                    if (-not $UninstallKeys) {
                        Write-Warning -Message 'No software registry keys found'
                    } else {
                        ForEach ($UninstallKey in $UninstallKeys) {
                            $friendlyNames = @{
                                'DisplayName'    = 'Name'
                                'DisplayVersion' = 'Version'
                            }
                            Write-Verbose -Message "Checking uninstall key [$($UninstallKey)]"
                            if ($Name) {
                                $WhereBlock = { $_.GetValue('DisplayName') -like "$Name*" }
                            } elseif ($GUID) {
                                $WhereBlock = { $_.PsChildName -eq $Guid.Guid }
                            } else {
                                $WhereBlock = { $_.GetValue('DisplayName') }
                            }
                            $SwKeys = Get-ChildItem -Path $UninstallKey -ErrorAction SilentlyContinue | Where-Object $WhereBlock
                            if (-not $SwKeys) {
                                Write-Verbose -Message "No software keys in uninstall key $UninstallKey"
                            } else {
                                foreach ($SwKey in $SwKeys) {
                                    $output = @{ }
                                    foreach ($ValName in $SwKey.GetValueNames()) {
                                        if ($ValName -ne 'Version') {
                                            $output.InstallLocation = ''
                                            if ($ValName -eq 'InstallLocation' -and 
                                                ($SwKey.GetValue($ValName)) -and 
                                                (@('C:', 'C:\Windows', 'C:\Windows\System32', 'C:\Windows\SysWOW64') -notcontains $SwKey.GetValue($ValName).TrimEnd('\'))) {
                                                $output.InstallLocation = $SwKey.GetValue($ValName).TrimEnd('\')
                                            }
                                            [string]$ValData = $SwKey.GetValue($ValName)
                                            if ($friendlyNames[$ValName]) {
                                                $output[$friendlyNames[$ValName]] = $ValData.Trim() ## Some registry values have trailing spaces.
                                            } else {
                                                $output[$ValName] = $ValData.Trim() ## Some registry values trailing spaces
                                            }
                                        }
                                    }
                                    $output.GUID = ''
                                    if ($SwKey.PSChildName -match '\b[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\b') {
                                        $output.GUID = $SwKey.PSChildName
                                    }
                                    New-Object -TypeName PSObject -Prop $output
                                }
                            }
                        }
                    }
                }
                
                if ($ComputerName -eq $env:COMPUTERNAME) {
                    & $scriptBlock $PSBoundParameters
                } else {
                    Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $PSBoundParameters
                }
            } catch {
                Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
            }
        }
    
    }
function Test-PendingReboot {
        If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") -eq $true) { return $true }
        If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting") -eq $true) { return $true }
        If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") -eq $true) { return $true }
        If ((Test-Path -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts") -eq $true) { return $true }
        try { 
            $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
            $status = $util.DetermineIfRebootPending()
            if (($null -ne $status) -and $status.RebootPending) {
                return $true
            }
        }
        catch { }
    
        return $false
    }

Clear-Host

$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$check_version = "2.2.4" #usebasicparsing

# Part 1
# System health parameters
$CPUS = ""
$RAM = ""
$diskrel = ""
$diskgb = ""
$time = ""
$licensed = ""
$buildnumber = ""
$dotnet = ""
$EP = ""
$trp = ""
$Sophos = ""
$Forti = ""
$Sentinel = ""
$Defender = ""
$AVInstalled = ""
$firewall = ""
$AP_ruleexists = ""
$IC_ruleexists = ""

# CPUs in Cores
$CPUS = $(Get-WmiObject -Class Win32_processor | Measure-Object).count * $(Get-WmiObject -Class Win32_processor | Select-Object NumberOfLogicalProcessors)[0].NumberOfLogicalProcessors
    
# RAM in GB
$memory = [int64](Get-WmiObject Win32_PhysicalMemory  | Measure-Object -Property Capacity -Sum).Sum
$RAM = ($memory / 1024 / 1024 / 1024)
    
    
# Diskfree in %
$disk = $(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID like 'C:'")
$diskrel = [Math]::Round($disk.Freespace / $disk.Size * 100)
    
# Diskfree in GB
$diskgb = [Math]::Round($disk.Freespace / 1GB)

# Zeitabweichung
$time = ((($(w32tm /query /status)[4]) -split " ")[1]).trimend('s')

# Windows activated?
$licensed = $(Get-ActivationStatus).Status
if($licensed -like "Licensed"){
$licensed = $true}
    
#Buildnumber
$version     = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name CurrentBuildNumber).CurrentBuildNumber
$patchlevel  = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name UBR).UBR
$buildnumber = $version + "." + $patchlevel

#.net version
$dotnet = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -name Version).Version

# Execution Policy
$ep = Get-ExecutionPolicy

#Reboot required?
$trp = Test-PendingReboot
    
#AV installed?
$Sophos   = Get-InstalledSoftware -Name "Sophos Endpoint Agent"
$Forti    = Get-InstalledSoftware -Name "FortiClient"
$Sentinel    = Get-InstalledSoftware -Name "Sentinel Agent"
if(Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue ){
$Defender = $(Get-MpComputerStatus -ErrorAction SilentlyContinue).AntivirusEnabled
}    
if($Sophos -or $Forti -or $Sentinel -or ($Defender -eq "Running")){
    
$AVInstalled = $True
    
}else {
    $AVInstalled = $false
}


#Firewall active?
$FWprofiles = $(Get-NetFirewallSetting  -PolicyStore ActiveStore)
$FWActiveProfiles = $($FWprofiles.ActiveProfile).ToString()
$FWActiveProfile = $FWActiveProfiles.Split(", ")
if($FWActiveProfile[0]){
$FW_Do = $(Get-NetFirewallProfile -Profile $FWActiveProfile[0] -PolicyStore ActiveStore).Enabled
}
if($FWActiveProfile[2]){
$FW_Pu = $(Get-NetFirewallProfile -Profile $FWActiveProfile[2] -PolicyStore ActiveStore).Enabled
}
if($FWActiveProfile[4]){
$FW_Pr = $(Get-NetFirewallProfile -Profile $FWActiveProfile[4] -PolicyStore ActiveStore).Enabled
}
if($FW_Do -or $FW_Pu -or $FW_Pr){
$firewall = "True"
}else{
$firewall = "False"
}

#Firewall exceptions applied?
$AP_ruleexists = $(Get-NetFirewallRule -DisplayName "Enable PSUpdate" -ea SilentlyContinue).Enabled
$IC_ruleexists = $(Get-NetFirewallRule -DisplayName "Icinga Agent Inbound" -ea SilentlyContinue).Enabled

if(-not $AP_ruleexists){
$AP_ruleexists = "False"
}

if(-not $IC_ruleexists){
$IC_ruleexists = "False"
}

# Part 2
# Connectivity parameters

$wmi = ""
$port80 = ""
$port135 = ""
$port445 = ""
$port5665 = ""
$port5985 = ""
$port8530 = ""
$port_ap = 0
$portresult = ""
$wsus = ""
$wsus80 = ""
$wsus8530 = ""
$response80 = ""
$response8530 = ""

# check wmi ports open

$wmi = Get-NetFirewallRule -Name "WMI-WINMGMT-In-TCP" -ea SilentlyContinue

if ($wmi.Enabled -like "True"){
$wmi = "True"
}else{
$wmi = "False"
}

# Check misc ports open

$port80   = $(tnc -Port 80   -ComputerName 127.0.0.1 -ErrorAction SilentlyContinue).TcpTestSucceeded
$port135  = $(tnc -Port 135  -ComputerName 127.0.0.1 -ErrorAction SilentlyContinue).TcpTestSucceeded
$port445  = $(tnc -Port 445  -ComputerName 127.0.0.1 -ErrorAction SilentlyContinue).TcpTestSucceeded
$port5665 = $(tnc -Port 5665 -ComputerName 127.0.0.1 -ErrorAction SilentlyContinue).TcpTestSucceeded
$port5985 = $(tnc -Port 5985 -ComputerName 127.0.0.1 -ErrorAction SilentlyContinue).TcpTestSucceeded
$port8530 = $(tnc -Port 8530 -ComputerName 127.0.0.1 -ErrorAction SilentlyContinue).TcpTestSucceeded

# Check Active Patching Ports

For ($port = 49664; $port -lt 49670; $port++){

$portresult = $(tnc -port $port -ComputerName 127.0.0.1 -ErrorAction SilentlyContinue).TcpTestSucceeded

if ($portresult){
$port_ap += 1
}

}

if ($port_ap -gt 2){
$port_ap = "True"
}else{
$port_ap = "False"}

# Check WSUS connect

$wsus = (Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -name WUServer).WUServer
$response8530 = Invoke-WebRequest -Uri $wsus -Method Head -DisableKeepAlive -UseBasicParsing
if ($response8530.StatusCode -eq 200) {
$wsus8530 = "True"}else{
$Wsus8530 = "False"
}

$wsus = ($wsus) -split (":",3)
$wsus80 = $wsus[0] + ":" + $wsus[1]
$response80 = Invoke-WebRequest -Uri $wsus80 -Method Head -DisableKeepAlive -UseBasicParsing
if ($response80.StatusCode -eq 200) {
$wsus80 = "True"}else{
$Wsus80 = "False"
}


# Part 3
# User settings

$isadmin = ""

# Check if MR user has admin privileges

$isadmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Part 4
# System Settings
$websites = 0
$update_websites = @(
'http://download.windowsupdate.com'
'https://download.microsoft.com'
'http://go.microsoft.com'
)

foreach ($uri in $update_websites){
$response = ""
$response = Invoke-WebRequest -Uri $uri -Method Head -DisableKeepAlive -UseBasicParsing
if ($response.StatusCode -eq 200) {
    $websites += 1
}
}

if ($websites -eq 3){

$websites = "True"

}

# Check installed roles
$roles = @()
$allroles = ""
$roles = $(Get-WindowsFeature | Where-Object{ $_.Installed }  | Select-Object name )

foreach ($role in $roles){

$allroles += $role.Name
$allroles += ", "

}
$allroles = ($allroles).TrimEnd(", ")

# Check DNS A-Record
$dnsname = ""
$dnsname = Resolve-DnsName -Name $env:COMPUTERNAME | Where-Object {$_.Type -like "A"} | Select-Object name, type, IPAddress

$HostIP = (
    Get-NetIPConfiguration |
    Where-Object {
        $_.IPv4DefaultGateway -ne $null -and
        $_.NetAdapter.Status -ne "Disconnected"
    }
).IPv4Address.IPAddress

if ($dnsname.IPAddress -eq $HostIP){

$dnsrecord = "True"}else{
$dnsrecord = "False"
}

# Get all running services

$services = $(get-service | Where-Object {$_.status -like "Running"}).Name

foreach ($service in $services){
$running_services += $service + ", "

}

$running_services = ($running_services).TrimEnd(", ")

# Check AP scheduled Tasks

$tasks = Get-ScheduledTask -TaskName "MR Active Patching*"

if($tasks){
$ap_taskready = "True"
$ap_taskresult = "True"
}else{
$ap_taskready = "N/A"
$ap_taskresult = "N/A"
}
foreach($task in $tasks){

$ap_taskinfo = $task | Get-ScheduledTaskInfo
if ($task.state -notlike "Ready"){
$ap_taskready = "False"
}
if( $ap_taskinfo.LastTaskResult -ne 0){
$ap_taskresult = "False"
}
}

# Check WSUS Cleanup task

$task = Get-ScheduledTask -TaskName "WSUS Cleanup" -ErrorAction SilentlyContinue
if($task){
$wc_taskready = "True"
$wc_taskresult = "True"
$wc_taskinfo = $task | Get-ScheduledTaskInfo
if ($task.state -notlike "Ready"){
$wc_taskready = "False"
}
if( $wc_taskinfo.LastTaskResult -ne 0){
$wc_taskresult = "False"
}
}else{
$wc_taskready = "N/A"
$wc_taskresult = "N/A"
}

# Check for all files and folders

$dnd = "C:\mr_managed_it\mr_do_not_delete_file.txt"
$rs =  "C:\mr_managed_it\regsettings.reg"

$fileExists = [System.IO.File]::Exists($dnd)
if($fileExists){
$dnd = "True"}else{
$dnd = "False"}


$fileExists = [System.IO.File]::Exists($rs)
if($fileExists){
$rs = "True"}else{
$rs = "False"}

$psm = Get-ChildItem -Path 'C:\Program Files\WindowsPowerShell\Modules\*' -Recurse | Where-Object {$_.FullName -match "PSWindowsUpdate.psm1"}

if ($psm){
$psm = "True"}else{
$psm= "False"}

$pswu       = "N/A"
$pswu_mbs   = "N/A"
$pswu_nonad = "N/A"
$da         = "N/A"
$pswu       = (Get-content -Path "C:\mr_managed_it\scripts\PSWU-Update.ps1" | Where-Object { $_.Contains("version =")}).Substring(12,5)
$pswu_mbs   = (Get-content -Path "C:\mr_managed_it\scripts\PSWU-Update_mbs.ps1" | Where-Object { $_.Contains("version =")}).Substring(12,5)
$pswu_nonad = (Get-content -Path "C:\mr_managed_it\scripts\PSWU-Update_nonad.ps1" | Where-Object { $_.Contains("version =")}).Substring(12,5)
$da         = (Get-content -Path "C:\mr_managed_it\scripts\decline_approve.ps1" | Where-Object { $_.Contains("version =")}).Substring(12,5)

# Check for Icinga certs

$iccert1 = "C:\ProgramData\icinga2\var\lib\icinga2\certs\ca.crt"
$iccert2 = "C:\ProgramData\icinga2\var\lib\icinga2\certs\trusted-parent.crt"
$iccert3 = "C:\ProgramData\icinga2\var\lib\icinga2\certs\" + $env:COMPUTERNAME + "." + $env:USERDNSDOMAIN +".crt"
$iccert4 = "C:\ProgramData\icinga2\var\lib\icinga2\certs\" + $env:COMPUTERNAME + "." + $env:USERDNSDOMAIN +".key"

if([System.IO.File]::Exists($iccert1) -and [System.IO.File]::Exists($iccert2) -and [System.IO.File]::Exists($iccert3) -and [System.IO.File]::Exists($iccert4)){
$iccerts = "True"}else{
$iccerts = "False"}

# WSUS endpoint
$server = Get-WsusServer
$config = $server.GetConfiguration()
$wsus_endpoint = $config.MUUrl

if($wsus_endpoint -like ""){
$wsus_endpoint = "N/A"
}

# WSUS last sync
$server = Get-WsusServer
$sub = $server.GetSubscription()
$lastSyncInfo = $($sub.GetLastSynchronizationInfo()).Result
$lastSyncErrors = $($sub.GetLastSynchronizationInfo()).Error
$lastSyncStart = $($($sub.GetLastSynchronizationInfo()).StartTime).ToString("yyyy-MM-dd HH:mm:ss")
$nextSyncStart = $($($sub.GetNextSynchronizationTime())).ToString("yyyy-MM-dd HH:mm:ss")

if ($server){
if($lastSyncErrors -match "NotApplicable"){
$lastSyncErrors = "No errors"
}else{
$lastSyncErrors = "ERRORS"}
}else{
$lastSyncErrors = "N/A"
$lastSyncInfo = "N/A"
$lastSyncStart = "N/A"
$nextSyncStart = "N/A"
}
# WSUS last approve

$approve_start = Get-Content -Path "C:\mr_managed_it\Logs\decline_approve.txt" | Where-Object { $_ -match "Startzeit" -or $_ -match "Start time"}
$approve_end = Get-Content -Path "C:\mr_managed_it\Logs\decline_approve.txt"  | Where-Object { $_ -match "Endzeit" -or $_ -match "End time"}

if ($approve_start -match "Startzeit" -or $approve_start -match "Start time"){
$approve_start = $($approve_start -split ": ")[1]
$approve_start = $approve_start.Insert(12, ":")
$approve_start = $approve_start.Insert(10, ":")
$approve_start = $approve_start.Insert(8, " ")
$approve_start = $approve_start.Insert(6, "-")
$approve_start = $approve_start.Insert(4, "-")
}else{
$approve_start = "N/A"}


if ($approve_end -match "Endzeit" -or $approve_end -match "End time"){
$approve_end = $($approve_end -split ": ")[1]
$approve_end = $approve_end.Insert(12, ":")
$approve_end = $approve_end.Insert(10, ":")
$approve_end = $approve_end.Insert(8, " ")
$approve_end = $approve_end.Insert(6, "-")
$approve_end = $approve_end.Insert(4, "-")

}else{
$approve_end = "N/A"}

# Check WSUS Download status
Import-Module PoshWSUS
Connect-PSWSUSServer -WsusServer localhost -Port 8530
$dls = Get-PSWSUSContentDownloadProgress
$dlsDB = $dls.DownloadedBytes
$dlsTBTD = $dls.TotalBytesToDownload

if ($dls -like $null){
    $dlsDB ="N/A"
    $dlsTBTD = "N/A"
}

# Check WSUS groups count
Import-Module pswindowsupdate
Connect-PSWSUSServer -WsusServer localhost -Port 8530
$GroupsAll = Get-PSWSUSGroup | Where-Object {$_.Name -match "MR_"}

if($GroupsAll){
$GroupsAll = ($GroupsAll).count
}else{
$GroupsAll = "N/A"
}

$wsman = Test-WSMan

if($wsman){
    $wsman = "True"
}else{
    $wsman = "False"
}

# Part 5
# Patch Settings

# Check Update UI access
$uiacccess = ""
$uiacccess = (Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -name SetDisableUXWUAccess).SetDisableUXWUAccess

if ($uiacccess -eq 1){
$uiacccess = "True"
}else{
$uiacccess = "False"}

# Check Registry settings
Remove-Item 'C:\mr_managed_it\regexport.reg' -ErrorAction SilentlyContinue
reg export 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' C:\mr_managed_it\regexport.reg
$regexport = Get-FileHash -Path "C:\mr_managed_it\regexport.reg"
$regsettings = Get-FileHash -Path "C:\mr_managed_it\regsettings.reg"

if($regexport.Hash -eq $regsettings.Hash){
$regsettings = "True"
}else{
$regsettings = "False"}

# What patch provider is the asset using
$patchprovider = Get-WUServiceManager | Where-Object {$_.name -like "Windows Server Update Service"}

# Part 7
# Icinga Settings

# check if asset can reach sattelite and Icinga in the web

$icsatellite = ((((Get-Content "C:\ProgramData\icinga2\etc\icinga2\zones.conf" | Select-String "host" ) -split "=")[1]).trimstart(' \"')).trimend('\";')
$icweb = "packages.icinga.com"
$ic80 = tnc -port 80 -ComputerName $icsatellite -ErrorAction SilentlyContinue
$ic443 = tnc -port 443 -ComputerName $icweb -ErrorAction SilentlyContinue


#######################################################################

# compile the result

$result  = "Hostname: " + ([System.Net.Dns]::GetHostByName($env:computerName)).HostName +  "`r`n"
$result += "Date-Time: " + $date             + "`r`n"
$result += "Check-Version: " + $check_version    + "`r`n"
$result += "Systemhealth CPUs: " + $CPUS        + "`r`n"
$result += "Systemhealth RAM: " + $RAM         + "`r`n"
$result += "Systemhealth Diskrelative: " + $diskrel    + "`r`n"
$result += "Systemhealth Diskabsolute: " + $diskgb    + "`r`n"
$result += "Systemhealth Time offset: " + $time    + "`r`n"
$result += "Systemhealth OS Activated: " + $Licensed    + "`r`n"
$result += "Systemhealth Buildnumber: " + $buildnumber + "`r`n"
$result += "Systemhealth .Net Version: " + $dotnet         + "`r`n"
$result += "Systemhealth Execution Policy: " + $ep         + "`r`n"
$result += "Systemhealth Reboot Pending: " + $trp         + "`r`n"
$result += "Systemhealth AntiVirus installed: " + $AVInstalled + "`r`n"
$result += "Systemhealth Firewall active: " + $firewall    + "`r`n"
$result += "Systemhealth AP Firewall rule: " + $AP_ruleexists    + "`r`n"
$result += "Systemhealth Icinga Firewall rule: " + $IC_ruleexists    + "`r`n"
$result += "Systemhealth WMI Firewall rule: " + $wmi    + "`r`n"
$result += "Connectivity Port 80 open: " + $port80    + "`r`n"
$result += "Connectivity Port 135 open: " + $port135    + "`r`n"
$result += "Connectivity Port 445 open: " + $port445    + "`r`n"
$result += "Connectivity Port 5665 open: " + $port5665    + "`r`n"
$result += "Connectivity Port 5985 open: " + $port5985    + "`r`n"
$result += "Connectivity Port 8530 open: " + $port8530    + "`r`n"
$result += "Connectivity Active Patching ports open: " + $port_ap    + "`r`n"
$result += "Connectivity Asset can reach WSUS 80: " + $wsus80     + "`r`n"
$result += "Connectivity Asset can reach WSUS 8530: " + $wsus8530   + "`r`n"
$result += "Usersettings MR user has admin privileges: " + $isadmin    + "`r`n"
$result += "Systemsettings MS websites reachable: " + $websites    + "`r`n"
$result += "Systemsettings Valid DNS A-record: " + $dnsrecord    + "`r`n"
$result += "Systemsettings Installed roles: " + $allroles    + "`r`n"
$result += "Systemsettings Running Services: " + $running_services    + "`r`n"
$result += "Systemsettings AP Scheduled Tasks ready: " + $ap_taskready    + "`r`n"
$result += "Systemsettings AP Scheduled Tasks results: " + $ap_taskresult    + "`r"
$result += "Systemsettings WC Scheduled Tasks ready: " + $wc_taskready    + "`r`n"
$result += "Systemsettings WC Scheduled Tasks results: " + $wc_taskresult    + "`r`n"
$result += "Systemsettings WSUS approve start: " + $approve_start    + "`r`n"
$result += "Systemsettings WSUS approve end: " + $approve_end    + "`r`n"
$result += "Systemsettings WSUS last sync Info: " + $lastSyncInfo    + "`r`n"
$result += "Systemsettings WSUS last sync Errors: " + $lastSyncErrors    + "`r`n"
$result += "Systemsettings WSUS last sync Start: " + $lastSyncStart    + "`r`n"
$result += "Systemsettings WSUS next sync Start: " + $nextSyncStart    + "`r`n"
$result += "Systemsettings WSUS Downloaded Bytes: " + $dlsDB    + "`r`n"
$result += "Systemsettings WSUS Bytes to download: " + $dlsTBTD    + "`r`n"
$result += "Systemsettings WSUS groups count: " + $GroupsAll  + "`r`n"
$result += "Systemsettings WSUS endpoint: " + $wsus_endpoint    + "`r`n"
$result += "Systemsettings File DoNotDelete exists: " + $dnd    + "`r`n"
$result += "Systemsettings File RegSettings exists: " + $rs    + "`r`n"
$result += "Systemsettings File PowerShell module exists: " + $psm    + "`r`n"
$result += "Systemsettings PSWU version: " + $pswu    + "`r`n"
$result += "Systemsettings PSWU_MBS version: " + $pswu_mbs    + "`r`n"
$result += "Systemsettings PSWU_NONAD version: " + $pswu_nonad    + "`r`n"
$result += "Systemsettings Decline_Approve version: " + $da    + "`r`n"
$result += "Systemsettings File Icinga Certs exist: " + $iccerts    + "`r`n"
$result += "Systemsettings Icinga satellite reachable: " + $ic80.TcpTestSucceeded    + "`r`n"
$result += "Systemsettings Icinga web repo reachable: " + $ic443.TcpTestSucceeded    + "`r`n"
$result += "Systemsettings PSRemote enabled: " + $wsman    + "`r`n"
$result += "Patchsettings Disabled UI access: " + $uiacccess    + "`r`n"
$result += "Patchsettings Valid Registry settings: " + $regsettings    + "`r`n"
$result += "Patchsettings Patchprovider WSUS active: " + $patchprovider.IsManaged + "`r`n"
$result += "Patchsettings Patchprovider WSUS default: " + $patchprovider.IsDefaultAUService + "`r`n"


$result | Out-File -FilePath "C:\mr_managed_it\fc_result.log"
