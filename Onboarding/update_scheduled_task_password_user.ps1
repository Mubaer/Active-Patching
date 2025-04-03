$vms = Get-WsusComputer
foreach ($vm in $vms){
Invoke-Command -ComputerName $vm.FullDomainName -ScriptBlock {
Get-ScheduledTask -TaskName "MR FlightCheck" | Set-ScheduledTask -User "Ziehm\ADM_MR" -Password "Supergeheimes Kennwort"
}
}