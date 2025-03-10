# Usage: aufrufen ohne Parameter
# Das Script erzeugt eine Regel auf dem bearbeiteten WSUS-Server.
# Rückgabe: keine

$WSUSServer   = Get-WsusServer
$ApprovalRule = $WSUSServer.CreateInstallApprovalRule('MR Service Auto Approval Updates')

$UC = $ApprovalRule.GetUpdateClassifications()
$C  = $WSUSServer.GetUpdateClassifications() | Where-Object -Property Title -eq 'Updates'
$UC.Add($C)
$D = $WSUSServer.GetUpdateClassifications() | Where-Object -Property Title -eq 'Sicherheitsupdates'
$UC.Add($D)
$ApprovalRule.SetUpdateClassifications($UC)

$Type = 'Microsoft.UpdateServices.Administration.' + 'ComputerTargetGroupCollection'
$TargetGroups = New-Object $Type
$TargetGroups.Add(($WSUSServer.GetComputerTargetGroups() | Where-Object -Property Name -match "MR Server"))
$ApprovalRule.SetComputerTargetGroups($TargetGroups)

$ApprovalRule.Enabled = $true
$ApprovalRule.Save()
