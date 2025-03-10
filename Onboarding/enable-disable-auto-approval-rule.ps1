# Usage: aufrufen auf WSUS-Server ohen Parameter
# Mit diesem Script lässt sich die Auto-Approval-Rule "MR Service" enablen oder disablen. Siehe Zeile 15
# Rückgabe: keine

$wsus = Get-WSUSServer

$rules = $wsus.GetInstallApprovalRules()

ForEach ($rule in $rules) {

if ($rule.Name -match "MR Service"){

$rule.Name

$rule.Enabled = $false
$rule.save()
}

}
