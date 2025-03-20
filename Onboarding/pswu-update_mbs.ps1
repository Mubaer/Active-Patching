Import-Module pswindowsupdate
$version = "2.2.0" # 
$Transscript_path = "C:\mr_managed_it\Logs\active_patching_mbs." + (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss") + ".txt"
Get-WsusServer -Name localhost -PortNumber 8530

$VMs = Get-Content -Path "C:\mr_managed_it\Scripts\mbs_hosts.txt"

# Get-Date liefert den Tag der Woche im DE-Format, dh. Montag ist 1
# der ScheduledInstallDay ist aber im US-Format, dh. Sonntag ist 1
$today = (Get-Date).DayOfWeek.value__  + 1
"Version: " + $version | Out-File $Transscript_path -Append
"Day code: " + $today | Out-File $Transscript_path -Append

ForEach ($VM in $VMs){
$EP                      = ""
$Reboot                  = ""
$AUOptions               = ""
$ManagedByMR             = ""
$ScheduledInstallDay     = ""

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
get-Item wsman:\localhost\client\TrustedHosts | Select-Object Name, Value 
$EP                      = Invoke-Command -ComputerName $FDN {Get-ExecutionPolicy} -Credential $credential
$Reboot                  = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' -Name AlwaysAutoRebootAtScheduledTime -ErrorAction SilentlyContinue | Select-Object AlwaysAutoRebootAtScheduledTime} -Credential $credential
$AUOptions               = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' -Name AUOptions -ErrorAction SilentlyContinue | Select-Object AUOptions} -Credential $credential
$ManagedByMR             = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\'    -Name ManagedByMR -ErrorAction SilentlyContinue | Select-Object ManagedByMR} -Credential $credential
$ScheduledInstallDay     = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'  -Name ScheduledInstallDay -ErrorAction SilentlyContinue | Select-Object ScheduledInstallDay} -Credential $credential

}

if($ManagedByMR.ManagedByMR -eq "1" -and $ScheduledInstallDay.ScheduledInstallDay -eq $today){

Invoke-Command -ComputerName $FDN -ScriptBlock {Set-ExecutionPolicy RemoteSigned -force} -Credential $credential

"Installing Updates ..." | Out-File $Transscript_path -Append

Invoke-Command -ComputerName $FDN -ScriptBlock {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    Register-psrepository -Default -ErrorAction SilentlyContinue
    Install-PackageProvider -Name nuget -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -AllowClobber
    } -Credential $credential -Verbose

if($Reboot.AlwaysAutoRebootAtScheduledTime -eq "0" -and $AUOptions.AUOptions -eq "2"){

$FDN + "No Reboot" | Out-File $Transscript_path -Append
Invoke-Command -ComputerName $FDN -ScriptBlock {Param($user, $Password)
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "Install-WindowsUpdate -AcceptAll -IgnoreReboot"
    $trigger = New-ScheduledTaskTrigger -Once -At $(Get-Date)
    Unregister-ScheduledTask -TaskName "PSWindowsUpdate" -Confirm:$false
    Register-ScheduledTask -Action $action -Trigger $trigger -User $user -Password $Password -TaskName "PSWindowsUpdate" -Description "PSWindowsUpdate"
    write-host "Starting"
    Start-ScheduledTask -TaskName "PSWindowsUpdate" } -Credential $credential -Verbose -ArgumentList $user, $Password

}else{

$FDN + " Reboot" | Out-File $Transscript_path -Append
Invoke-Command -ComputerName $FDN -ScriptBlock {Param($user, $Password)
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "Install-WindowsUpdate -AcceptAll -AutoReboot"
    $trigger = New-ScheduledTaskTrigger -Once -At $(Get-Date)
    Unregister-ScheduledTask -TaskName "PSWindowsUpdate" -Confirm:$false
    Register-ScheduledTask -Action $action -Trigger $trigger -User $user -Password $Password -TaskName "PSWindowsUpdate" -Description "PSWindowsUpdate"
    write-host "Starting"
    Start-ScheduledTask -TaskName "PSWindowsUpdate" } -Credential $credential -Verbose -ArgumentList $user, $Password
}
Invoke-Command -ComputerName $FDN {param($EP) Set-ExecutionPolicy $EP} -ArgumentList $EP -Credential $credential
}else{
"Nothing to do" | Out-File $Transscript_path -Append
}

}