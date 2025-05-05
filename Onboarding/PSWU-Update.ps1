Import-Module pswindowsupdate
$version = "2.2.5" # added TargetGroups Check for special customer
$Transscript_path = "C:\mr_managed_it\Logs\active_patching." + (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss") + ".txt"
"Script version: " + $version | Out-File $Transscript_path -Append
Get-WsusServer -Name localhost -PortNumber 8530

#$VMs = get-wsuscomputer -NameIncludes "hpim" | Select-Object fulldomainname
$MBs = Get-Content -Path "C:\mr_managed_it\Scripts\mbs_hosts.txt"
$NONADs = Get-Content -Path "C:\mr_managed_it\Scripts\nonad_hosts.txt"
$TargetGroups = "MR_Server", "MR_Server_SQL", "MR_Server_HV", "MR_Server_DC", "MR_Server_RDS", "MR_Server_CA", "MR_Server_EX", "MR_Server_File", "MR_Server_PR"
$ArrayList = $(Get-WsusComputer -ComputerTargetGroups $TargetGroups).FullDomainName
"List of vms: " + $ArrayList | Out-File $Transscript_path -Append

# Wenn einzelne Server ausgenommen werden sollen, einfach in die Zeile 15 nicht auskommentieren und was sinnvolles reinschreiben. Evtl. die Zeile 15 mehrfach verwenden.
[System.Collections.ArrayList]$VMS = $ArrayList
#$vms.Remove("mrm-stg-22pswu1.mrm.stg")
"Removing assets from list ..."  | Out-File $Transscript_path -Append

# Get-Date liefert den Tag der Woche im DE-Format, dh. Montag ist 1
# der ScheduledInstallDay ist aber im US-Format, dh. Sonntag ist 1
$today = (Get-Date).DayOfWeek.value__  + 1
"Day code: " + $today | Out-File $Transscript_path -Append

ForEach ($VM in $VMs){
$EP                      = ""
$Reboot                  = ""
$AUOptions               = ""
$ManagedByMR             = ""
$ScheduledInstallDay     = ""

if ($MBs -match $VM -or $NONADs -match $VM){

"Asset " + $VM + " in exclusion list" | Out-File $Transscript_path -Append}else{
"Asset name: " + $vm | Out-File $Transscript_path -Append

if (Test-Connection $VM -Count 1 -quiet){

$FDN                     = $VM
$EP                      = Invoke-Command -ComputerName $FDN {Get-ExecutionPolicy}
$Reboot                  = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' -Name AlwaysAutoRebootAtScheduledTime -ErrorAction SilentlyContinue | Select-Object AlwaysAutoRebootAtScheduledTime}
$AUOptions               = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' -Name AUOptions -ErrorAction SilentlyContinue | Select-Object AUOptions}
$ManagedByMR             = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\'    -Name ManagedByMR -ErrorAction SilentlyContinue | Select-Object ManagedByMR}
$ScheduledInstallDay     = Invoke-Command -ComputerName $FDN {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'  -Name ScheduledInstallDay -ErrorAction SilentlyContinue | Select-Object ScheduledInstallDay}

if($ManagedByMR.ManagedByMR -eq "1" -and $ScheduledInstallDay.ScheduledInstallDay -eq $today){

Set-Item wsman:\localhost\client\TrustedHosts -Value $FDN -Force -Concatenate
get-Item wsman:\localhost\client\TrustedHosts
Invoke-Command -ComputerName $FDN -ScriptBlock {Set-ExecutionPolicy RemoteSigned -force}

$Sourcepath = "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate"
$Destpath   = "\\$FDN\C" + "$" + "\Program Files\WindowsPowerShell\Modules"
"Copying files ..." | Out-File $Transscript_path -Append
New-Item -Path $DestPath -ItemType directory -ErrorAction SilentlyContinue
Copy-Item -Recurse -Path $SourcePath -destination $DestPath -ErrorAction SilentlyContinue
"Done ..." | Out-File $Transscript_path -Append

Invoke-Command -ComputerName $FDN -ScriptBlock {Import-Module PSWindowsUpdate; Enable-WURemoting -Confirm:$false; Get-WUList}

"Installing Updates ..." | Out-File $Transscript_path -Append

if($Reboot.AlwaysAutoRebootAtScheduledTime -eq "0" -and $AUOptions.AUOptions -eq "2"){
$FDN + " No Reboot" | Out-File $Transscript_path -Append
Invoke-WUJob -ComputerName $FDN -Script { Install-WindowsUpdate -AcceptAll -IgnoreReboot } -Confirm:$false -verbose -RunNow
}else{
$FDN + " Reboot" | Out-File $Transscript_path -Append
Invoke-WUJob -ComputerName $FDN -Script { Install-WindowsUpdate -AcceptAll -AutoReboot } -Confirm:$false -verbose -RunNow
}
"Updates will be installed offline. Moving on." | Out-File $Transscript_path -Append
Invoke-Command -ComputerName $FDN {param($EP) Set-ExecutionPolicy $EP} -ArgumentList $EP
}else{
"Nothing to do" | Out-File $Transscript_path -Append
}

}else{
"Not reachable" | Out-File $Transscript_path -Append
}
}
}