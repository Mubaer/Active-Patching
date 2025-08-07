[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer()

$updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

$update = $wsus.SearchUpdates('KB5064489')

$update | fl

# https://learn.microsoft.com/en-us/archive/msdn-technet-forums/03e19134-ffbd-4d34-abbb-7111fa4eed52