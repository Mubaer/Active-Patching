[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer()

$updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

$update = $wsus.SearchUpdates('KB5064489')

$update | fl