Import-Module pswindowsupdate
$version = "2.2.0" # 
$Transscript_path = "C:\mr_managed_it\Logs\preparing_modules." + (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss") + ".txt"
Get-WsusServer -Name localhost -PortNumber 8530

$option = Read-Host "(1) Standalone or (2) sek. AD"

if ($option -eq 1){

$VMs = Get-Content -Path "C:\mr_managed_it\Scripts\mbs_hosts.txt"
"Version: " + $version | Out-File $Transscript_path -Append

ForEach ($VM in $VMs){
$EP                      = ""
$ManagedByMR             = ""

"Asset name: " + $vm | Out-File $Transscript_path -Append


$s_creds = Get-StoredCredential -Target $VM
$creds = Get-StoredCredential -Target $VM -AsCredentialObject
$securePassword = $s_creds.Password
$Password = $creds.Password
$user = $s_creds.UserName 
if ($s_creds){$credential = New-Object System.Management.Automation.PsCredential($user,$securePassword)}

if ((Test-Connection $VM -Count 1) -and $creds){

$FDN                     = [string]$VM
Set-Item wsman:\localhost\client\TrustedHosts -Value $FDN -Force -Concatenate
$EP                      = Invoke-Command -ComputerName $FDN {Get-ExecutionPolicy} -Credential $credential
$ManagedByMR             = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\'    -Name ManagedByMR -ErrorAction SilentlyContinue | Select-Object ManagedByMR} -Credential $credential

}

if($ManagedByMR.ManagedByMR -eq "1"){

Invoke-Command -ComputerName $FDN -ScriptBlock {Set-ExecutionPolicy RemoteSigned -force} -Credential $credential

"Preparing Modules ..." | Out-File $Transscript_path -Append

Invoke-Command -ComputerName $FDN -ScriptBlock {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Register-psrepository -Default -ErrorAction SilentlyContinue
    Install-PackageProvider -Name nuget -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -AllowClobber
    } -Credential $credential -Verbose
    }

}

Invoke-Command -ComputerName $FDN {param($EP) Set-ExecutionPolicy $EP} -ArgumentList $EP -Credential $credential


}elseif ($option -eq 2){

"Version: " + $version | Out-File $Transscript_path -Append
$VMs = Get-Content -Path "C:\mr_managed_it\Scripts\nonad_hosts.txt"

ForEach ($VM in $VMs){
$EP                      = ""
$ManagedByMR             = ""

"Asset name: " + $vm | Out-File $Transscript_path -Append

$domainuser = Get-Content -Path "C:\mr_managed_it\Scripts\aduser.txt"
$s_creds = Get-StoredCredential -Target $domainuser
$creds = Get-StoredCredential -Target $domainuser -AsCredentialObject
$securePassword = $s_creds.Password
$Password = $creds.Password
$user = $s_creds.UserName 
if ($s_creds){$credential = New-Object System.Management.Automation.PsCredential($user,$securePassword)}



if ((Test-Connection $VM -Count 1) -and $creds){

$FDN                     = [string]$VM
Set-Item wsman:\localhost\client\TrustedHosts -Value $FDN -Force -Concatenate
$EP                      = Invoke-Command -ComputerName $FDN {Get-ExecutionPolicy} -Credential $credential
$ManagedByMR             = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\'    -Name ManagedByMR -ErrorAction SilentlyContinue | Select-Object ManagedByMR} -Credential $credential

}

if($ManagedByMR.ManagedByMR -eq "1"){

Invoke-Command -ComputerName $FDN -ScriptBlock {Set-ExecutionPolicy RemoteSigned -force} -Credential $credential

"Preparing Modules ..." | Out-File $Transscript_path -Append

Invoke-Command -ComputerName $FDN -ScriptBlock {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Register-psrepository -Default -ErrorAction SilentlyContinue
    Install-PackageProvider -Name nuget -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -AllowClobber
    } -Credential $credential -Verbose
    }

}

Invoke-Command -ComputerName $FDN {param($EP) Set-ExecutionPolicy $EP} -ArgumentList $EP -Credential $credential



}else{Write-host "Weder 1 noch 2 gewählt. Ende."}