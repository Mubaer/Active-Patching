$wsus = Get-WSUSServer

$wsus.CreateComputerTargetGroup("MR_Server_DHCP")
$wsus.CreateComputerTargetGroup("MR_Server_DNS")
