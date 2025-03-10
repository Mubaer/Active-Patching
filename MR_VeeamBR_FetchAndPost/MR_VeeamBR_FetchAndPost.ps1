#### DEV Variables
<#
$device_id = "000000002"
$upload_token = "DEQ1xUIP0H0CPGwd8cLP1lkkCh4Uql10yf5e0NI053OCdV"
$upload_uri = "https://io.managed-it.de/io.php"
$MR_Upload_URL = $upload_uri
$MR_Upload_Token = $upload_token
$NC_Device_ID = $device_id

#>

#=== Add a temporary value from User to session ($Env:PSModulePath) ======
#https://docs.microsoft.com/powershell/scripting/developer/module/modifying-the-psmodulepath-installation-path?view=powershell-7
$path = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
$env:PSModulePath +="$([System.IO.Path]::PathSeparator)$path"
$MyModulePath = "C:\Program Files\Veeam\Backup and Replication\Console\"
$env:PSModulePath = $env:PSModulePath + "$([System.IO.Path]::PathSeparator)$MyModulePath"
#=========================================================================
try {
    $veeamPSModule = Get-Module -ListAvailable | ?{$_.Name -match "Veeam.Backup.Powershell"}
    Import-Module $veeamPSModule.Path -DisableNameChecking
} catch {
    Write-Host "Import Module failed, trying hardlink"
    try {
        import-module "C:\Program Files\Veeam\Backup and Replication\Console\Veeam.Backup.PowerShell.dll"
    }catch{
    Write-Host "Failed to import, exiting now"
    exit
    }
}
$WorkPath = $env:SystemDrive + "\MRDaten"

If(!(Test-Path $WorkPath))
{
    ## Create Dir if not exists
    New-Item -ItemType Directory -Force -Path $WorkPath
}

cd $WorkPath



# Get myself
$OutputContent = "### Veeam - Self Information ###"
$OutputContent += Get-VBRLocalhost | Out-String
$OutputContent += "`n"

# Get Hosts connected to VBR
$OutputContent += "### Veeam - Connected Hosts ###"
$OutputContent += Get-VBRServer | Out-String
$OutputContent += "`n"

# Get connected backup repos
$Repos1 = Get-VBRBackupRepository

Foreach ($i in $Repos1)
{
    $OutputContent += "### Veeam - Connected Repository ###"
    $OutputContent += $i | Format-List | Out-String
    try {
        $OutputContent += [PSCustomObject]@{
            'Size' = $i.GetContainer().CachedTotalSpace.InBytes / 1GB
            'FreeSpace' = $i.GetContainer().CachedFreeSpace.InBytes / 1GB
        } | Format-List | Out-String
    }catch{
        $OutputContent += "==== Failed to get Size and FreeSpace ===="
    }
    $OutputContent += "`n"
}
$OutputContent += "`n"
# Get external repos
$Repos2 = Get-VBRExternalRepository
Foreach ($i in $Repos2)
{
    $OutputContent += "### Veeam - External Repository ###"
    $OutputContent += $i | Format-List | Out-String
    try {
        $OutputContent += [PSCustomObject]@{
            'Size' = $i.GetContainer().CachedTotalSpace.InBytes / 1GB
            'FreeSpace' = $i.GetContainer().CachedFreeSpace.InBytes / 1GB
        } | Format-List | Out-String
    }catch{
        $OutputContent += "==== Failed to get Size and FreeSpace ===="
    }
    $OutputContent += "`n"
}
$OutputContent += "`n"
# Get Scale Out repos
$Repos3 = Get-VBRBackupRepository -ScaleOut
Foreach ($i in $Repos2)
{
    $OutputContent += "### Veeam - External Repository ###"
    $OutputContent += $i | Format-List | Out-String
    try {
        $OutputContent += [PSCustomObject]@{
            'Size' = $i.GetContainer().CachedTotalSpace.InBytes / 1GB
            'FreeSpace' = $i.GetContainer().CachedFreeSpace.InBytes / 1GB
        } | Format-List | Out-String
    }catch{
        $OutputContent += "==== Failed to get Size and FreeSpace ===="
    }
    $OutputContent += "`n"
}
$OutputContent += "`n"
# Get Jobs & VMs

$Jobs = Get-VBRJob
Foreach ($i in $Jobs)
{
    $OutputContent += "### Veeam - Jobs and VMs - Job ###"
    $OutputContent += $i | Format-List | Out-String
    $Placeholder = [string] $i.Id
    $OutputContent += "### Veeam - Jobs and VMs - VMs ###"
    $OutputContent += Get-VBRJobObject -Job $Placeholder | Format-List | Out-String
    #Write-Host "### Veeam - Jobs and VMs - Schedule ###"
    #Get-VBRJobScheduleOptions -Job $Placeholder
    $OutputContent += "### Veeam - Jobs and VMs - History ###"
    $OutputContent += Get-VBRBackupSession | Where {$_.JobId -eq $Placeholder} | Sort EndTimeUTC -Descending | Select -First 5 | Format-List | Out-String
    $OutputContent += "`n"
}



#### PREPARE UPLOAD

$now = Get-Date -Format "yyyy-MM-dd_hh-mm-ss"

#$device_id = "000000002"
#$upload_token = "DEQ1xUIP0H0CPGwd8cLP1lkkCh4Uql10yf5e0NI053OCdV"
#$upload_uri = "https://io.managed-it.de/io.php"

$upload_uri= $MR_Upload_URL
$upload_token = $MR_Upload_Token 
$device_id = $NC_Device_ID
$script_id = "02"

$OutputPath = $WorkPath + "\"
$FileName = $device_id + "_" + $script_id + "_" + $now + ".nctl"
$OutputFile = $OutputPath + $FileName

$OutputContent | Out-File -FilePath $OutputFile

### Upload Delay
$sleeptimer = Get-Random -Minimum 30 -Maximum 120
Start-Sleep -s $sleeptimer

#### UPLOAD
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"
$OutputFileName = (Get-Item -Path $OutputFile).Name
$SubmitFile = [System.IO.File]::ReadAllText($OutputFile)

 $body = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"token`"",
    "Content-Type: text/plain$LF",
    $upload_token,
    "--$boundary",
    "Content-Disposition: form-data; name=`"iotyp`"",
    "Content-Type: text/plain$LF",
    "fileupload",
    "--$boundary",
    "Content-Disposition: form-data; name=`"upload_file`"; filename=`"$OutputFileName`"",
    "Content-Type: application/octet-stream$LF",
    $SubmitFile,
    "--$boundary--$LF"
) -join $LF
try {
    Invoke-RestMethod -Uri $upload_uri -Method 'POST' -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $body -Verbose
    #Invoke-RestMethod -Uri 'https://mito.mr-daten.lan/functions/n-central/io.php' -Method 'POST' -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $body -Verbose
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    $Result = 1001
    Exit 1001
}
Exit 0
