#### DEV Variables
<#
$device_id = "000000002"
$upload_token = "DEQ1xUIP0H0CPGwd8cLP1lkkCh4Uql10yf5e0NI053OCdV"
$upload_uri = "https://io.managed-it.de/io.php"
$MR_Upload_URL = $upload_uri
$MR_Upload_Token = $upload_token
$NC_Device_ID = $device_id
$FileHash = 'B1EF28594F4AEC2788F28286F17FCE6C74840654F914F4983116B1168A46E30F'
$MR_DS_Scan = 1
$MR_Upload_Delay = 60
#>


$WorkPath = $env:SystemDrive + "\MRDaten"
$ExecFile = 'DocusnapScript.exe'
$CheckFile = $WorkPath+'\'+$ExecFile
$FileDL = 'https://download.mon.managed-it.de/docusnap/DocusnapScript.exe'
$TempPath = $WorkPath + '\temp_Docusnap'

$now = Get-Date -Format "yyyy-MM-dd_hh-mm-ss"
$upload_uri= $MR_Upload_URL
$upload_token = $MR_Upload_Token 
$device_id = $NC_Device_ID
$script_id = "03"
$FileName = $device_id + "_" + $script_id + "_" + $now + ".nctl"
$OutputFile = $WorkPath+'\'+$FileName

#### PREPARE TASK
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

If(!(Test-Path $WorkPath))
{
    ## Create Dir if not exists
    New-Item -ItemType Directory -Force -Path $WorkPath
}
If(!(Test-Path $CheckFile))
{
    ## Download File if not exists
    Invoke-WebRequest -Uri $FileDL -OutFile $CheckFile
}
ElseIf(!((Get-FileHash -Algorithm SHA256 $CheckFile).Hash -eq $FileHash))
{
    ## Re-Download if File Hash is wrong
    Invoke-WebRequest -Uri $FileDL -OutFile $CheckFile
}
if(!((Get-FileHash -Algorithm SHA256 $CheckFile).Hash -eq $FileHash))
{
    ## Exit if File Hash is still wrong
    $Result = 1002
    Exit 1002
}
If(Test-Path $TempPath)
{
    Remove-Item $TempPath -Recurse
    
}
New-Item -ItemType Directory -Force -Path $TempPath

$MR_Exec_Policy = Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned

cd $WorkPath

#### EXECUTION
 
.\DocusnapScript.exe -O $TempPath -W -Z $MR_DS_Scan| Out-Null

Set-ExecutionPolicy $MR_Exec_Policy

$DocusnapXML = $TempPath+'\'+(Get-ChildItem -Path $TempPath -Include *.xml -File -Recurse).Name

If (!($DocuSnapXML -eq $TempPath))
{
    Move-Item -Path $DocusnapXML -Destination $OutputFile
}
Else
{
    $Result = 1003
    Exit 1003
}

### Upload Delay
$sleeptimer = Get-Random -Minimum 30 -Maximum $MR_Upload_Delay
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