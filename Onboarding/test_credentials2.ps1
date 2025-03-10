while($result -ne "True"){

    $credentials = Get-Credential #Read credentials
     $username = $credentials.username
     $password = $credentials.GetNetworkCredential().password
    
     # Get current domain using logged-on user's credentials
     $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
     $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)
    
    if ($domain.name -eq $null)
    {
     write-host "Anmeldung mit den angegebenen Daten fehlgeschlagen. Bitte überprüfen." -ForegroundColor Red
     $result = "false"
    }
    else
    {
     write-host "Anmeldung an "$domain.name "erfolgreich" -ForegroundColor Green
     $result = "true"
    }
    
    }