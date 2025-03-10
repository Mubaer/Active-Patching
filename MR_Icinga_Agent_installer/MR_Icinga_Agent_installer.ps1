if ( -not $selfservice_api) {
    Write-Host "================================"
    Write-Host "Icinga Agent Installation Script"
    Write-Host "  (c) MR-Daten -- Charly Kupke"
    Write-Host "================================"
    Write-Host "================================"
    Write-Host "Please enter informations below after prompt"
    $satellite_ip = Read-Host -Prompt 'Input Satellite IP'
    $satellite_hostname = Read-Host -Prompt 'Input Satellite Hostname (DNS)'
    $selfservice_api = Read-Host -Prompt 'Input Selfservice API Key'
    $crt_removal =  Read-Host -Prompt 'Remove Certificates? (true for yes, false for no)'
    $UserInput = 1
}

if ( -not $selfservice_api -or -not $satellite_ip -or -not $satellite_hostname) {
    Write-Host "ERROR:"
    Write-Host "Please enter all informations"
    Write-Host "Try again by executing this script again"
    Pause
    Exit
}

$MR_Online_URL = "https://download.mon.managed-it.de/"
$MR_Satellite = "http://" + $satellite_ip + "/"
$MR_Self_Service_API = $selfservice_api
$MR_Satellite_Hostname = $satellite_hostname
$MR_remove_certificate = $crt_removal

#$MR_Icinga_Plugin_URL = "https://github.com/Icinga/icinga-powershell-plugins/archive/refs/tags/v1.7.0.zip"
$MR_Icinga_Plugin_URL = "https://github.com/Icinga/icinga-powershell-plugins/archive/refs/tags/v1.8.0.zip"
#$MR_Icinga_Framework_ZIP = "ps-framework_v1.4.1.zip"
$MR_Icinga_Framework_ZIP = "icinga-powershell-framework-1.8.0.zip"

Write-Host "#### Checking Connection to Icinga Satellite ####"
$CheckPort80 = Test-NetConnection -Port 80 -ComputerName $satellite_ip -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
$CheckPort5665 = Test-NetConnection -Port 5665 -ComputerName $satellite_ip -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
$CheckDNS = Test-NetConnection -Port 443 -ComputerName $satellite_hostname -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

if (!$CheckPort80.TcpTestSucceeded)
{
    Write-Host "Satellite IP via Port 80 not accessable"
    If ( -not $UserInput) 
    {
        $Result = 1005
        Exit 1005
    }
    Else 
    {
        Pause
        Break
    }
}
if (!$CheckPort5665.TcpTestSucceeded)
{
    Write-Host "Satellite IP via Port 5665 not accessable"
    If ( -not $UserInput) 
    {
        $Result = 1005
        Exit 1005
    }
    Else 
    {
        Pause
        Break
    }
}
if (!$CheckDNS.TcpTestSucceeded)
{
    Write-Host "### INFO ### Satellite DNS Name not set"
}

Write-Host "#### Setting Execution Policy to unrestricted ####"
$MR_Exec_Policy = Get-ExecutionPolicy
Set-ExecutionPolicy Unrestricted
 
<# disabled for now

### Check if there is a existing icinga installation
Write-Host "#### Check if there is a existing icinga installation ####"
$IcingaServiceCheck = Get-Service -Name icinga2 -ErrorAction SilentlyContinue

if ($IcingaServiceCheck.Length -gt 0)
{
    Write-Host "#### Stopping Icinga Service ####"
    Stop-Service -Name icinga2 -Force
    Start-Sleep -s 5
    $IcingaProgramInstallation = Get-WmiObject -Class Win32_Product | Where-Object{$_.Name -eq "Icinga 2"}
    if ($IcingaProgramInstallation.Length -gt 0)
    {
        Start-Sleep -s 5
        Write-Host "#### Uninstalling Icinga ####"
        $IcingaProgramInstallation.Uninstall()
    }
}

$IcingaProgramData = $env:ProgramData+"\Icinga2"

If(Test-Path $IcingaProgramData)
{
    Start-Sleep -s 5
    Write-Host "#### Removing Icinga Config Folder ####"
    Remove-Item $IcingaProgramData -Recurse
}
#>


$IcingaCertFolder = $env:ProgramData+"\Icinga2\var\lib\icinga2\certs"
if($MR_remove_certificate -eq 'true')
{
    Stop-Service -Name icinga2 -Force
    Write-Host "#### Removing Existing Icinga Certificates ####"
    If(Test-Path $IcingaCertFolder)
    {
        Remove-Item $IcingaCertFolder -Recurse
    }
}

Write-Host "#### Removing Icinga Framework PS Module Config ####"
$IcingaFrameWorkModuleConfig = $env:ProgramFiles+"\WindowsPowerShell\Modules\icinga-powershell-framework\config\config.json"
If(Test-Path $IcingaFrameWorkModuleConfig)
{
    Remove-Item $IcingaFrameWorkModuleConfig
}
Start-Sleep -s 2


[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11";
$ProgressPreference = "SilentlyContinue";

### Dot NET Framwork Check

Write-Host "#### Checking for Dot.NET Framework ####"
If ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\1033' -Name 'release').release -lt  393295) 
{
    $Result = 1001
    Write-Host "####  ####"
    Write-Host "Dot NET Framework too old, please Update"
    Write-Host "####  ####"
    Set-ExecutionPolicy $MR_Exec_Policy
    If ( -not $UserInput) {

        Exit 1001
    }
    Else {
        Pause
        Break
    }
    
}


Write-Host "#### Downloading Icinga Powershell Kickstart script ####"
$global:IcingaFrameworkKickstartSource = $MR_Satellite + 'downloads/icinga-powershell-kickstart.ps1';
$Script = (Invoke-WebRequest -UseBasicParsing -Uri $global:IcingaFrameworkKickstartSource).Content;
$Script += "`r`n`r`n Start-IcingaFrameworkWizard -RepositoryUrl 'http://"+$satellite_ip+"/downloads/"+$MR_Icinga_Framework_ZIP+"' -ModuleDirectory 'C:\Program Files\WindowsPowerShell\Modules' -AllowUpdate 1 -SkipWizard ;";
#$Script += "`r`n`r`n Start-IcingaFrameworkWizard -RepositoryUrl 'http://"+$satellite_ip+"/downloads/icinga-powershell-framework-1.8.0.zip' -ModuleDirectory 'C:\Program Files\WindowsPowerShell\Modules' -AllowUpdate 1 -SkipWizard ;";

Start-Sleep -s 5
try {
    Write-Host "#### Execute Icinga Powershell Kickstart script  ####"
    Invoke-Command -ScriptBlock ([Scriptblock]::Create($Script));
    } catch {
        Set-ExecutionPolicy $MR_Exec_Policy
        $Result = 1002
        Write-Host "####  ####"
        Write-Host "Can't download Icinga Powershell Kickstart Script"
        Write-Host "####  ####"
        If ( -not $UserInput) {
            Exit 1002
        }
        Else {
            Pause
            Break
        }
    }
Start-Sleep -s 5
try {
    Write-Host "#### Start using Icinga Framework ####"
    Use-Icinga -DebugMode;
    } catch {
        Set-ExecutionPolicy $MR_Exec_Policy
        $Result = 1003
        Write-Host "####  ####"
        Write-Host "Can't load Icinga Powershell module"
        Write-Host "####  ####"
        If ( -not $UserInput) {
            Exit 1003
        }
        Else {
            Pause
            Break
        }
    }
$MR_Director_URL = $MR_Satellite + 'director/'
$MR_Package_Source = $MR_Satellite + 'downloads/agent/'
$MR_Endpoint_Connection = '[' + $satellite_ip + ']:5665'
Start-Sleep -s 5
try {
    Write-Host "#### Start installing Icinga Agent Wizard ####"
    Start-IcingaAgentInstallWizard -DirectorUrl $MR_Director_URL -PackageSource $MR_Package_Source -SelfServiceAPIKey $MR_Self_Service_API -AgentVersion 'release' -Endpoints $MR_Satellite_Hostname -CAEndpoint $satellite_ip -EndpointConnections $MR_Endpoint_Connection -ConvertEndpointIPConfig 0 -UseDirectorSelfService 1 -OverrideDirectorVars 0 -LowerCase 1 -InstallFrameworkPlugins 1 -PluginsUrl $MR_Icinga_Plugin_URL -Reconfigure -RunInstaller;
    } catch {
        Set-ExecutionPolicy $MR_Exec_Policy
        $Result = 1004
        Write-Host "####  ####"
        Write-Host "Icinga Agent Installation failed"
        Write-Host "####  ####"
        If ( -not $UserInput) {
            Exit 1004
        }
        Else {
            Pause
            Break
        }
    }

# Set-IcingaAcl -Directory 'C:\ProgramData\icinga2\etc'

Set-ExecutionPolicy $MR_Exec_Policy
Write-Host "####  ####"
Write-Host "####  ####"
Write-Host "#### Icinga Agent Installation successfull ####"
If ( -not $UserInput) {
    $Result = 0
    Exit 0
}

