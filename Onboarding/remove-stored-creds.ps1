# Setzen von Creds, die der MR Managed IT gehören:
New-StoredCredential -Target 'Test12' -UserName 'TestUsername' -Password 'TestPassword' -Comment 'ManagedByMR' -Persist LocalMachine

# Löschen aller Creds, die der MR Managed IT gehören:
$creds = Get-StoredCredential -AsCredentialObject
foreach ($cred in $creds){
    if($cred.Comment -like "ManagedByMR"){
        Remove-StoredCredential -Target $cred.TargetName
        }
    }
