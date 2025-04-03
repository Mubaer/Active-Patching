$vms = Get-WsusComputer
foreach ($vm in $vms){
Invoke-Command -ComputerName $vm.FullDomainName -ScriptBlock {
$task = Get-ScheduledTask -TaskName "MR FlightCheck"
$newPrincipal = New-ScheduledTaskPrincipal -UserId "ZIEHM\ADM_MR" -LogonType ServiceAccount -RunLevel Highest
$task.Principal = $newPrincipal
Set-ScheduledTask -InputObject $task
Get-ScheduledTask -TaskName "MR FlightCheck" | Set-ScheduledTask -User "Ziehm\ADM_MR" -Password "Supergeheimes Kennwort"
}
}