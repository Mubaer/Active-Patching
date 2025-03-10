Import-Module pswindowsupdate
Get-WsusServer -Name localhost -PortNumber 8530


$WSUSComputers = Get-WsusComputer #-NameIncludes wu2



ForEach ($WSUSComputer in $WSUSComputers){

$FDN = $WSUSComputer.FullDomainName

Get-WUSettings -ComputerName  $FDN | Select-Object Computername, AUOptions, AlwaysAutoRebootAtScheduledTime, ScheduledInstallDay, NoAutoUpdate
}