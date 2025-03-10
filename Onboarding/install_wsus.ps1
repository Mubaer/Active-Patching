param (
[Parameter(Mandatory=$true)][String]$CacheMode
)

if ($CacheMode -notmatch "local" -and $CacheMode -notmatch "remote"){
Write-host "Usage: Please add 'local' or 'remote' to tell the WSUS-Server where to store the files"
Exit 1
}

# Prepare OS and Disks
$disk_already_in_use = 0
$disknumber = ''

$DVD_Drive = Get-WmiObject win32_volume -filter 'DriveType = "5"'

if($DVD_Drive.DriveLetter -eq "W:"){

    $DVD_Drive.DriveLetter = "X:"
    $DVD_Drive.Put()
}


$disknumber =  $(Get-Disk | Where-Object {$_.IsOffline -eq $True}).number 

if($disknumber){

Get-Disk -Number $disknumber | Set-Disk -IsOffline $False
Get-Disk -Number $disknumber | Initialize-Disk -PartitionStyle GPT

$disks = Get-Volume

foreach ($disk in $disks){

    if($disk.Driveletter -eq "W"){

        Write-Host "Achtung! Der Buchstabe W ist schon vergeben!"
        $disk_already_in_use = 1
        Write-Host -ForegroundColor Red "Keine leere Partition W:\ gefunden! WSUS-Installation wird abgebrochen."
        Exit 1
    }
}
}else{
Write-Host -ForegroundColor Red "Keine Partition gefunden, die zur Verfügung steht. Bitte eine leere Partition anlegen."
Exit 1
}

If($disknumber -and $disk_already_in_use -ne "1"){


New-Partition -DiskNumber $disknumber -DriveLetter W -UseMaximumSize
$Format = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "WSUS"


}else{

    Write-Host -ForegroundColor Red "Keine leere Partition W:\ gefunden! WSUS-Installation wird abgebrochen."
    Exit 1
}

if($Format){

# Install WSUS-prerequisits
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
register-psrepository -Default
Install-PackageProvider -Name nuget -MinimumVersion 2.8.5.201 -Force
Install-Module -Name PoshWSUS -force
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
Install-Module PSWindowsUpdate -force -SkipPublisherCheck -AllowClobber
Install-Module -Name CredentialManager -force -SkipPublisherCheck
Install-WindowsFeature -Name RSAT-AD-Tools, RSAT-AD-Powershell, GPMC -IncludeAllSubFeature

# Credentials for Scheduled Tasks

while($result -ne "True"){

    $credentials = Get-Credential -Message "Bitte den Namen und das Kennwort des MR-Users in der Form Domain\Username eingeben"
     $username = $credentials.username
     $password = $credentials.GetNetworkCredential().password
    
     # Get current domain using logged-on user's credentials
     $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
     $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)
    
    if ($domain.name -eq $null)
    {
     write-host "Anmeldung mit den angegebenen Daten fehlgeschlagen. Bitte überprüfen. Installation kann icht fortgesetzt werden." -ForegroundColor Red
     $result = "false"
    }
    else
    {
     write-host "Anmeldung an die Active Directory Domain "$domain.name "erfolgreich. Instalation wird fortgesetzt." -ForegroundColor Green
     $result = "true"
    }
    
    }
$title = "Bitte beantworten. Danke."
$message = "Gibt es Assets, die nicht Mitglied einer Domäne sind?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "   Ja   ", "   Ja   "
$no = New-Object System.Management.Automation.Host.ChoiceDescription "   Nein   ", "   Nein   "
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$aretherembs=$host.ui.promptforchoice($title, $message, $options, 1)

$title = "Bitte beantworten. Danke."
$message = "Gibt es Assets, die Mitglied einer ANDEREN Domäne sind?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "   Ja   ", "   Ja   "
$no = New-Object System.Management.Automation.Host.ChoiceDescription "   Nein   ", "   Nein   "
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$aretherenonads=$host.ui.promptforchoice($title, $message, $options, 1)

    
New-Item -ItemType Directory -Path "C:\mr_managed_it"
New-Item -ItemType Directory -Path "C:\mr_managed_it\Logs"
New-Item -ItemType Directory -Path "C:\mr_managed_it\Scripts"
New-Item -ItemType Directory -Path "C:\mr_managed_it\Temp"

Add-MpPreference -ExclusionPath "C:\mr_managed_it"

$TempDir = "C:\mr_managed_it\Temp"
$URL = "https://download.microsoft.com/download/F/3/C/F3C64941-22A0-47E9-BC9B-1A19B4CA3E88/ENU/x86/SQLSysClrTypes.msi"
Start-BitsTransfer $URL $TempDir -RetryInterval 60 -RetryTimeout 180 -ErrorVariable err
msiexec -i $tempDir\SQLSysClrTypes.msi /qn

$URL = "https://download.microsoft.com/download/7/2/A/72ADC67E-586E-423F-A7AC-81DEC2691ACA/ReportViewer.msi"
Start-BitsTransfer $URL $TempDir -RetryInterval 60 -RetryTimeout 180 -ErrorVariable err
msiexec -i $tempDir\ReportViewer.msi /qn

$URL = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.6.4/npp.8.6.4.Installer.x64.exe"
Start-BitsTransfer $URL $TempDir -RetryInterval 60 -RetryTimeout 180 -ErrorVariable err
$installcmd = "$TempDir\npp.8.6.4.Installer.x64.exe /S"
Invoke-Expression $installcmd


# Install WSUS (WSUS Services, Management tools)
$WSUS_INSTALL = Install-WindowsFeature -Name UpdateServices -IncludeManagementTools

$WSUS_Install

if ($WSUS_INSTALL.Success -eq "True" -and $WSUS_INSTALL.ExitCode -eq "Success"){

# Run WSUS Post-Configuration
Set-Location "C:\Program Files\Update Services\Tools"

.\wsusutil.exe postinstall CONTENT_DIR="W:\WSUS_Updates"

# Get WSUS Server Object
$wsus = Get-WSUSServer
 
# Connect to WSUS server configuration
$wsusConfig = $wsus.GetConfiguration()

# Set to download updates from Microsoft Updates
Set-WsusServerSynchronization –SyncFromMU

# Set CacheMode
if ($CacheMode -match "remote"){
    $wsusconfig.HostBinariesOnMicrosoftUpdate = $true
}else{
    $wsusconfig.HostBinariesOnMicrosoftUpdate = $false
}

# Set Update Languages to German and English and save configuration settings
$wsusConfig.AllUpdateLanguagesEnabled = $false
$language = New-Object -Type System.Collections.Specialized.StringCollection
$language.Add("en")
$language.Add("de")
$wsusConfig.SetEnabledUpdateLanguages($language)

# auto skip OOBE sceens
$wsusConfig.OobeInitialized = $true

# automatically assign new assets to the MR Server groups
$wsusConfig.TargetingMode = "Client"

# set correct Endpoint
$wsusConfig.MUUrl = "https://sws.update.microsoft.com"
$wsusConfig.RedirectorChangeNumber = 4002

# save our custom settings
$wsusConfig.Save()

iisreset
Restart-Service *Wsus* -v

# Get WSUS Subscription and perform initial synchronization to get latest categories
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
write-host 'Beginning initial WSUS Sync to get available Products etc' -ForegroundColor Magenta
write-host 'Will take some time to complete. Go grab a coffee ...'
While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
}
write-host ' '
Write-Host "Sync is done." -ForegroundColor Green

# Configure the Platforms that we want WSUS to receive updates
write-host 'Setting WSUS Products'
Get-WsusProduct | where-Object {
    $_.Product.Title -in (
    'Windows Server 2016',
    'Windows Server 2016 and later Servicing Drivers',
    'Windows Server 2019',
    'Windows Server 2019 and later, Servicing Drivers',
    'Windows Server 2019 and later, Upgrade & Servicing Drivers',
    'Exchange Server 2016',
    'Exchange Server 2019',
    'Microsoft SQL Server 2012',
    'Microsoft SQL Server 2014',
    'Microsoft SQL Server 2016',
    'Microsoft SQL Server 2017',
    'Microsoft SQL Server 2019',
    'Microsoft SQL Server 2022',
    'Microsoft SQL Server Management Studio v17',
    'Microsoft SQL Server Management Studio v18',
    'Microsoft SQL Server Management Studio v19',
    'SQL Server Feature Pack',
    'Microsoft Edge',
    'Windows - Server, version 21H2 and later, Servicing Drivers',
    'Windows - Server, version 21H2 and later, Upgrade & Servicing Drivers',
    'Windows - Server, version 24H2 and later, Upgrade & Servicing Drivers',
    'Microsoft Server operating system-21H2',
    'Microsoft Server Operating system-22H2',
    'Microsoft Server Operating system-23H2',
    'Microsoft Server Operating system-24H2',
    'Windows Subsystem for Linux',
    'Microsoft Defender Antivirus',
    'Microsoft Defender for Endpoint'
    )
} | Set-WsusProduct

Get-WsusProduct | where-Object {$_.Product.Title -match "Windows"} | Set-WsusProduct -Disable

Start-Sleep -Seconds 60
# Because of a bug in the Set-WSUSProduct cmdlet we have to do this step twice
# Configure the Platforms that we want WSUS to receive updates
write-host 'Setting WSUS Products'
Get-WsusProduct | where-Object {
    $_.Product.Title -in (
    'Windows Server 2016',
    'Windows Server 2016 and later Servicing Drivers',
    'Windows Server 2019',
    'Windows Server 2019 and later, Servicing Drivers',
    'Windows Server 2019 and later, Upgrade & Servicing Drivers',
    'Exchange Server 2016',
    'Exchange Server 2019',
    'Microsoft SQL Server 2012',
    'Microsoft SQL Server 2014',
    'Microsoft SQL Server 2016',
    'Microsoft SQL Server 2017',
    'Microsoft SQL Server 2019',
    'Microsoft SQL Server 2022',
    'Microsoft SQL Server Management Studio v17',
    'Microsoft SQL Server Management Studio v18',
    'Microsoft SQL Server Management Studio v19',
    'SQL Server Feature Pack',
    'Microsoft Edge',
    'Windows - Server, version 21H2 and later, Servicing Drivers',
    'Windows - Server, version 21H2 and later, Upgrade & Servicing Drivers',
    'Windows - Server, version 24H2 and later, Upgrade & Servicing Drivers',
    'Microsoft Server operating system-21H2',
    'Microsoft Server Operating system-22H2',
    'Microsoft Server Operating system-23H2',
    'Microsoft Server Operating system-24H2',
    'Windows Subsystem for Linux',
    'Microsoft Defender Antivirus',
    'Microsoft Defender for Endpoint'
    )
} | Set-WsusProduct

# Configure the Classifications
write-host 'Setting WSUS Classifications'
Get-WsusClassification | Where-Object {
    $_.Classification.Title -in (
    'Critical Updates',
    'Definition Updates',
    'Feature Packs',
    'Security Updates',
    'Service Packs',
    'Update-Rollups',
    'Updates')
} | Set-WsusClassification

# Create Server Target group
$wsus.CreateComputerTargetGroup("MR_Server")
$wsus.CreateComputerTargetGroup("MR_Server_SQL")
$wsus.CreateComputerTargetGroup("MR_Server_DC")
$wsus.CreateComputerTargetGroup("MR_Server_HV")
$wsus.CreateComputerTargetGroup("MR_Server_EX")
$wsus.CreateComputerTargetGroup("MR_Server_RDS")
$wsus.CreateComputerTargetGroup("MR_Server_CA")
$wsus.CreateComputerTargetGroup("MR_Server_PR")
$wsus.CreateComputerTargetGroup("MR_Server_File")
$wsus.CreateComputerTargetGroup("MR_System")
# Configure Synchronizations
write-host 'Enabling WSUS Automatic Synchronisation'
$subscription.SynchronizeAutomatically=$true
 
# Set synchronization scheduled for midnight each night
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 0)
$subscription.NumberOfSynchronizationsPerDay=1
$subscription.Save()

# create automatic update rule
$ApprovalRule = $wsus.CreateInstallApprovalRule('MR Service Auto Approval Updates')

$UC = $ApprovalRule.GetUpdateClassifications()
$C  = $wsus.GetUpdateClassifications() | Where-Object -Property Title -eq 'Updates'
$UC.Add($C)
$D = $wsus.GetUpdateClassifications() | Where-Object -Property Title -eq 'Sicherheitsupdates'
$UC.Add($D)
$ApprovalRule.SetUpdateClassifications($UC)

$Type = 'Microsoft.UpdateServices.Administration.' + 'ComputerTargetGroupCollection'
$TargetGroups = New-Object $Type
$TargetGroups.Add(($wsus.GetComputerTargetGroups() | Where-Object -Property Name -eq "MR_Server"))
$ApprovalRule.SetComputerTargetGroups($TargetGroups)

# Set the Rule to false, we do not want to mess up our environment
$ApprovalRule.Enabled = $false

# now it is time to save the settings
$ApprovalRule.Save()

# Configure the operating system to only download patches from MS during nighttime and weekends

Write-Host "Setting BITS-Values ..."
Get-ChildItem -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS'

New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling' -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule' -ErrorAction SilentlyContinue

New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling' -PropertyType 'DWord' -Name 'EnableBandwidthLimits' -Value 1 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling' -PropertyType 'DWord' -Name 'IgnoreBandwidthLimitsOnLan' -Value 1 -ErrorAction SilentlyContinue

New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'StartDay' -Value 1 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'EndDay' -Value 5 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'StartHour' -Value 6 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'EndHour' -Value 12 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'HighBandwidthLimit' -Value "0x0000000a" -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'HighBandwidthType' -Value 1 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'NormalBandwidthLimit' -Value "0x0000000a" -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'NormalBandwidthType' -Value 1 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'LowBandwidthLimit' -Value "0x0000000a" -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule' -PropertyType 'DWord' -Name 'LowBandwidthType' -Value 1 -ErrorAction SilentlyContinue

New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule' -PropertyType 'DWord' -Name 'HighBandwidthLimit' -Value 0 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule' -PropertyType 'DWord' -Name 'HighBandwidthType' -Value 3 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule' -PropertyType 'DWord' -Name 'NormalBandwidthLimit' -Value 0 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule' -PropertyType 'DWord' -Name 'NormalBandwidthType' -Value 3 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule' -PropertyType 'DWord' -Name 'LowBandwidthLimit' -Value 0 -ErrorAction SilentlyContinue
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule' -PropertyType 'DWord' -Name 'LowBandwidthType' -Value 3 -ErrorAction SilentlyContinue
Write-Host "Done."

# Configure SUSDB to respond with unlimited XML-Size answers
Write-Host "Configuring Database ..."
$ConnectionString = 'server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true;'
$SQLConnection= New-Object System.Data.SQLClient.SQLConnection($ConnectionString)
$SQLConnection.Open()
$SQLCommand = $SQLConnection.CreateCommand()
$SQLCommand.CommandText = 'USE SUSDB; UPDATE tbConfigurationC SET MaxXMLPerRequest = 0'
$SqlDataReader = $SQLCommand.ExecuteReader()
$SQLDataResult = New-Object System.Data.DataTable
$SQLDataResult.Load($SqlDataReader)
$SQLConnection.Close()
$SQLDataResult
Write-Host "Done."
Write-Host "Checking Database values ..."
$ConnectionString = 'server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true;'
$SQLConnection= New-Object System.Data.SQLClient.SQLConnection($ConnectionString)
$SQLConnection.Open()
$SQLCommand = $SQLConnection.CreateCommand()
$SQLCommand.CommandText = 'USE SUSDB; SELECT * From tbConfigurationC'
$SqlDataReader = $SQLCommand.ExecuteReader()
$SQLDataResult = New-Object System.Data.DataTable
$SQLDataResult.Load($SqlDataReader)
$SQLConnection.Close()
Write-Host "Der Datenbankwert tbConfigurationC.MaxXMLPerRequest wurde auf folgenden Wert gesetzt"
Write-Host $SQLDataResult.maxxmlperrequest

# Configure IIS App-Pool WSUS-Pool to serve multiple clients
Write-Host "Configuring IIS-AppPool ..."
$pool = Get-IISAppPool -name wsuspool
Start-IISCommitDelay
(Get-IISAppPool -Name WSUSPool).queuelength = 15000
(Get-IISAppPool -Name WSUSPool).cpu.limit = 50000
(Get-IISAppPool -Name WSUSPool).Recycling.periodicrestart.privatememory = 0
Stop-IISCommitDelay
$pool.Recycle()
Write-Host "Done."

# Create Scheduled Tasks for Active Patching and WSUS-Cleanup

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\PSWU-Update.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday, Thursday, Saturday -At 8pm
Register-ScheduledTask -Action $action -Trigger $trigger -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "MR Active Patching" -Description "MR Active Patching"

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\PSWU-Update.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 10am
Register-ScheduledTask -Action $action -Trigger $trigger -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "MR Active Patching Sunday" -Description "PSWindowsUpdate Sonntag"

if($aretherembs -eq 0){
$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\PSWU-Update_mbs.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday, Thursday, Saturday -At 8pm
Register-ScheduledTask -Action $action -Trigger $trigger -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "MR Active Patching MBS" -Description "MR Active Patching MBS"

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\PSWU-Update_mbs.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 10am
Register-ScheduledTask -Action $action -Trigger $trigger -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "MR Active Patching MBS Sunday" -Description "MR Active Patching MBS Sonntag"

Disable-ScheduledTask -TaskName "MR Active Patching MBS"
Disable-ScheduledTask -TaskName "MR Active Patching MBS Sunday"
}

if($aretherenonads -eq 0){
$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\PSWU-Update_nonad.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday, Thursday, Saturday -At 8pm
Register-ScheduledTask -Action $action -Trigger $trigger -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "MR Active Patching Non-AD" -Description "MR Active Patching Non-AD"

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\PSWU-Update_nonad.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 10am
Register-ScheduledTask -Action $action -Trigger $trigger -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "MR Active Patching Non-AD Sunday" -Description "MR Active Patching Non-AD Sonntag"

Disable-ScheduledTask -TaskName "MR Active Patching Non-AD"
Disable-ScheduledTask -TaskName "MR Active Patching Non-AD Sundays"
}

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\wsus_cleanup2.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 10pm
Register-ScheduledTask -Action $action -Trigger $trigger -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "WSUS Cleanup" -Description "WSUS Cleanup"

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "C:\mr_managed_it\Scripts\set-credentials_v2.ps1"
Register-ScheduledTask -Action $action -User $credentials.UserName -Password $credentials.GetNetworkCredential().Password -TaskName "MR Set Credentials" -Description "set credentials for non ad members"

Disable-ScheduledTask -TaskName "MR Active Patching"
Disable-ScheduledTask -TaskName "MR Active Patching Sunday"

# Kick off a synchronization
$subscription.StartSynchronization()

# Monitor Progress of Synchronisation
 
write-host 'Starting WSUS Sync, will take some time' -ForegroundColor Magenta
Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
    Write-Progress -PercentComplete (
    $subscription.GetSynchronizationProgress().ProcessedItems*100/($subscription.GetSynchronizationProgress().TotalItems)
    ) -Activity "WSUS Sync Progress"
}
Write-Host "Sync is done." -ForegroundColor Green

}

}else
{
Write-Host -ForegroundColor Red "Die Partition W: konnte nicht partitioniert werden. Die Installation wird abgebrochen!"
}