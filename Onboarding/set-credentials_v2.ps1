$data = Get-Content -Raw -Path "C:\mr_managed_it\scripts\credentials.json" | ConvertFrom-Json

foreach($credential in $data.credentials) {

$hostname = $credential.hostname
$username = $credential.username
$password = $credential.password

New-StoredCredential -Target $hostname -UserName $username -Password $password -Persist LocalMachine

}

Remove-Item -Path "C:\mr_managed_it\scripts\credentials.json" -Force