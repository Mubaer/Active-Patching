$wsus = Get-WSUSServer

$wsus.CreateComputerTargetGroup("MR_Server_DC")
$wsus.CreateComputerTargetGroup("MR_Server_HV")
$wsus.CreateComputerTargetGroup("MR_Server_EX")
$wsus.CreateComputerTargetGroup("MR_Server_RDS")
$wsus.CreateComputerTargetGroup("MR_Server_CA")
$wsus.CreateComputerTargetGroup("MR_Server_File")