# So kann die Update-History abgefragt werden. das Cmdlet hat einen Bug, deshalb immer diese Parameter mitgeben

Get-WUHistory -MaxDate (Get-Date).AddDays(-30) -Last 100

# So können einfach die Settings der WSUS-Computer abgefragt werden und
# dann mit Mito verglichen werden

Get-WsusServer -Name localhost -PortNumber 8530

$WSUSComputers = Get-WsusComputer

ForEach ($WSUSComputer in $WSUSComputers){

Get-WUSettings -ComputerName $WSUSComputer.FullDomainName | Select-Object ComputerName, ScheduledInstallDay, AlwaysAutoRebootAtScheduledTime | Format-Table -HideTableHeaders

}
# lösche den verdammten Reg-Key
Get-WsusServer -Name localhost -PortNumber 8530

$vms = Get-WsusComputer # -NameIncludes dc02

foreach ($vm in $vms){

$vm.FullDomainName


Invoke-Command -ComputerName $vm.FullDomainName -ScriptBlock {Remove-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoRebootWithLoggedOnUsers }

}