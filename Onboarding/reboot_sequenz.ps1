Import-Module pswindowsupdate

$reboothosts = Get-Content C:\mr_managed_it\scripts\reboot_hosts.txt

foreach ($reboothost in $reboothosts){

$WUSettings = Get-WUSettings -ComputerName $reboothost
$Rebootstatus = Get-WURebootStatus -ComputerName  $reboothost -Silent
$JobStatus = (Get-ScheduledTask -CimSession $reboothost | Where-Object TaskName -eq PSWindowsUpdate ).State

$reboothost
$Rebootstatus
$WUSettings.AlwaysAutoRebootAtScheduledTime


if ($WUSettings.AlwaysAutoRebootAtScheduledTime -eq "0" `
    -and $Rebootstatus -like "True" `
    -and $JobStatus -ne "Running" )
    {
    Write-Host "Rebooting " $reboothost " ..."
    Restart-Computer -ComputerName $reboothost -Wait -For PowerShell -Delay 2 -Force -Timeout 900
    Write-Host "Fertig"
    }

}