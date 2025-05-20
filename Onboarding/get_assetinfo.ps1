######################################################
# Script zur Ermittlung der Voraussetzungen fuer     #
# das Onboarden eines kompletten Asset-Satzes eines  #
# Kunden. Alle Windows-Server werden ermittelt.      #
# Peter Ziegler 05/2022                              #
######################################################


####################################
#                                  #
# Wurde eine Kunden-KT übergeben?  #
#                                  #
####################################

param (
[Parameter(Mandatory=$true)][String]$KT,
[Parameter(Mandatory=$true)][String]$KN,
[Parameter(Mandatory=$false)][String]$icssatellite
)

function Get-InstalledSoftware {
    <#
	.SYNOPSIS
		Retrieves a list of all software installed on a Windows computer.
	.EXAMPLE
		PS> Get-InstalledSoftware
		
		This example retrieves all software installed on the local computer.
	.PARAMETER ComputerName
		If querying a remote computer, use the computer name here.
	
	.PARAMETER Name
		The software title you'd like to limit the query to.
	
	.PARAMETER Guid
		The software GUID you'e like to limit the query to
	#>
    [CmdletBinding()]
    param (
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME,
		
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
		
        [Parameter()]
        [guid]$Guid
    )
    process {
        try {
            $scriptBlock = {
                $args[0].GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value }
				
                $UninstallKeys = @(
                    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                )
                New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS | Out-Null
                $UninstallKeys += Get-ChildItem HKU: | Where-Object{ $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | ForEach-Object {
                    "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                }
                if (-not $UninstallKeys) {
                    Write-Warning -Message 'No software registry keys found'
                } else {
                    ForEach ($UninstallKey in $UninstallKeys) {
                        $friendlyNames = @{
                            'DisplayName'    = 'Name'
                            'DisplayVersion' = 'Version'
                        }
                        Write-Verbose -Message "Checking uninstall key [$($UninstallKey)]"
                        if ($Name) {
                            $WhereBlock = { $_.GetValue('DisplayName') -like "$Name*" }
                        } elseif ($GUID) {
                            $WhereBlock = { $_.PsChildName -eq $Guid.Guid }
                        } else {
                            $WhereBlock = { $_.GetValue('DisplayName') }
                        }
                        $SwKeys = Get-ChildItem -Path $UninstallKey -ErrorAction SilentlyContinue | Where-Object $WhereBlock
                        if (-not $SwKeys) {
                            Write-Verbose -Message "No software keys in uninstall key $UninstallKey"
                        } else {
                            foreach ($SwKey in $SwKeys) {
                                $output = @{ }
                                foreach ($ValName in $SwKey.GetValueNames()) {
                                    if ($ValName -ne 'Version') {
                                        $output.InstallLocation = ''
                                        if ($ValName -eq 'InstallLocation' -and 
                                            ($SwKey.GetValue($ValName)) -and 
                                            (@('C:', 'C:\Windows', 'C:\Windows\System32', 'C:\Windows\SysWOW64') -notcontains $SwKey.GetValue($ValName).TrimEnd('\'))) {
                                            $output.InstallLocation = $SwKey.GetValue($ValName).TrimEnd('\')
                                        }
                                        [string]$ValData = $SwKey.GetValue($ValName)
                                        if ($friendlyNames[$ValName]) {
                                            $output[$friendlyNames[$ValName]] = $ValData.Trim() ## Some registry values have trailing spaces.
                                        } else {
                                            $output[$ValName] = $ValData.Trim() ## Some registry values trailing spaces
                                        }
                                    }
                                }
                                $output.GUID = ''
                                if ($SwKey.PSChildName -match '\b[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}\b') {
                                    $output.GUID = $SwKey.PSChildName
                                }
                                New-Object -TypeName PSObject -Prop $output
                            }
                        }
                    }
                }
            }
			
            if ($ComputerName -eq $env:COMPUTERNAME) {
                & $scriptBlock $PSBoundParameters
            } else {
                Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $PSBoundParameters
            }
        } catch {
            Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}



function Upload_json {

[CmdletBinding()]
    param (
		
        [Parameter()]
        [string]$assetinfo_file
    )


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$upload_uri = "https://io.managed-it.de/io.php"
$upload_token = "Super geheimer Token"
$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"
$OutputFileName = (Get-Item -Path $assetinfo_file).Name
$SubmitFile = [System.IO.File]::ReadAllText($assetinfo_file)

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

    Invoke-RestMethod -Uri $upload_uri -Method 'POST' -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $body

}

function Upload_secureshare {

[CmdletBinding()]
    param (
		
        [Parameter()]
        [string]$mFileNameToUpload,
		
        [Parameter()]
        [bool]$mEnabledLogging
    )

###########################################################
# Uploadscript für Dateien nach Segulink (share.mr-daten.de)
# inkl. Validierung über Filehash (SHA256)
# 2022-05-09 Stefan Dietzel (s.dietzel@mr-daten.de): Initiale Version
# 2022-11-03 Stefan Dietzel (s.dietzel@mr-daten.de): harden against login CSRF using "historic" browsers
# boldly used by Peter Ziegler for usage in Managed IT preflight check script
###########################################################

# globale Variablen
$mUsername = 'managed-it-onboarding@mr-daten.de'
$mPassword = 'supergeheimes Kennwort'
$mDataRoomName = 'Managed IT - Onboarding_Upload'
$mFileNameToUpload = $mFileNameToUpload
$mDownloadDirectory = 'C:\MR\'
$mForceUpload = $true

$mHost = 'share.mr-daten.de'
$mApiUrl = 'segubox/v1'

$mVerboseOutput = $false
$mDebugOutput = $false
$mCleanupOnFailure = $true
$mLocalCleanupAfterUpload = $true

$mLocalFilePath = $mDownloadDirectory + $mFileNameToUpload
$mApiUri = 'https://' + $mHost + '/' + $mApiUrl

# Segulink login
$mCnonce = ''
for($i=0; $i -lt 16; $i++) {
    (48..57) + (65..70) | Get-Random -Count 1 | ForEach-Object {$mCnonce += [char]$_}
}

$mHeaders = @{'Accept'='application/json';'Content-Type'='application/json'}
$mLoginRequestData = @{'cnonce'=$mCnonce}
$mResponsePreLogin = Invoke-WebRequest -UseBasicParsing -Uri ($mApiUri + '/nonce') -Method Post -Headers $mHeaders -Body ($mLoginRequestData | ConvertTo-Json) -Verbose:$mVerboseOutput

if($mResponsePreLogin.StatusCode -ne 200) {
    Write-Host "Something went wrong during pre-login process..." -ForegroundColor Red
}
else {
    $mNonce = $mResponsePreLogin.Content | ConvertFrom-Json

    $mPayload = @{'username'=$mUsername; 'password'=$mPassword}
    $mPayload.Add('cnonce',$mNonce.cnonce)
    $mPayload.Add('nonce',$mNonce.nonce)

    # changed on 2022-09-16 to harden against login CSRF using "historic" browsers
    $mHeaders.Add( 'x-login-nonce', $mNonce.nonce )

    $mResponseLogin = Invoke-WebRequest -UseBasicParsing -Uri ($mApiUri + '/login') -Method Post -Headers $mHeaders -Body ($mPayload | ConvertTo-Json) -Verbose:$mVerboseOutput

    if($mResponseLogin.StatusCode -ne 200) {
        Write-Host 'Something went wrong during login process...' -ForegroundColor Red
    }
    else {
        Write-Host 'Successfully logged in as' $mUsername '.' -ForegroundColor Green
        $mSessionId = ($mResponseLogin.Content | ConvertFrom-Json).id
        $mToken = ($mResponseLogin.Content | ConvertFrom-Json).client.token
        $mRequestHeaders = @{'Authorization'='Bearer ' + $mToken;'Content-Type'='application/json'}

        # get content of room
        $mResponseRoomContent = Invoke-WebRequest -UseBasicParsing -Uri ($mApiUri + '/api/drive/webdav/rooms/' + $mDataRoomName + '/') -Headers $mRequestHeaders -Verbose:$mVerboseOutput

        if($mResponseRoomContent.StatusCode -ne 200) {
            Write-Host 'Something went wrong during request room content...' -ForegroundColor Red
        }
        else {
            Write-Host 'Requested Dataroom found.' -ForegroundColor Green
            if($mDebugOutput) {
                $mResponseRoomContent.Content | ConvertFrom-Json | ConvertTo-Json
            }
            $mItems = ($mResponseRoomContent.Content | ConvertFrom-Json).Children
            $mItem = $mItems | Where-Object{$_.name -eq $mFileNameToUpload}

            $mFileHashLocal = (Get-FileHash -Path $mLocalFilePath -Algorithm SHA256).Hash.ToLower()

            if($mForceUpload -or $null -eq $mItem -or $mFileHashLocal -ne $mItem.digest.Split(':')[1].Trim()) {
                Write-Host 'File does not exist or Hash value is not equal or Upload is enforced. Upload File...' -ForegroundColor Green

                # upload file
                $mByteContent = [System.IO.File]::ReadAllBytes($mLocalFilePath)
                $mJob = (New-Guid).Guid
                $mName = (New-Guid).Guid
                $mUrlParam = '?job=' + $mJob + '&name=' + $mName + '&last=true&size=' + $mByteContent.Count.ToString()
                $mResponseUpload = Invoke-WebRequest -UseBasicParsing -Uri ($mApiUri + '/api/drive' + $mUrlParam) -Method Put -Headers $mRequestHeaders -Body $mByteContent -Verbose:$mVerboseOutput
        
                if($mResponseUpload.StatusCode -ne 200) {
                    Write-Host 'Something went wrong during file upload...' -ForegroundColor Red
                    if($mCleanupOnFailure) {
                        Write-Host 'Cleanup temporary file:' $mLocalFilePath
                        Remove-Item -Path $mLocalFilePath -Force -Verbose:$mVerboseOutput
                    }
                    if ($mEnabledLogging) {
                        Stop-Transcript
                    }
                    return
                }
                else {
                    # commit upload
                    $mCommitData = @{
                        'job'=$mJob;
                        'last'=$true;
                        'items'=@(
                            @{
                                'name'=$mFileNameToUpload.Split('\')[-1];
                                'path'='/';
                                'token'=$mName
                            }
                        )
                    }
                    if($mDebugOutput) {
                        $mCommitData | ConvertTo-Json
                    }

                    $mResponseCommit = Invoke-WebRequest -UseBasicParsing -Uri ($mApiUri + '/api/drive/webdav/rooms/' + $mDataRoomName + '/?cmd=commit') -Method Post -Headers $mRequestHeaders -Body ($mCommitData | ConvertTo-Json)
                    
                    if($mResponseRoomContent.StatusCode -ne 200) {
                        Write-Host 'Something went wrong during commit upload...' -ForegroundColor Red
                        if($mCleanupOnFailure) {
                            Write-Host 'Cleanup temporary file:' $mLocalFilePath
                            Remove-Item -Path $mLocalFilePath -Force -Verbose:$mVerboseOutput
                        }


                        
                        if ($mEnabledLogging) {
                            Stop-Transcript
                        }
                        return
                    }
                    else {
                        if($mFileHashLocal -eq ($mResponseCommit.Content | ConvertFrom-Json).digest.Split(':')[1].Trim()) {
                        Write-Host 'File hash of uploaded file is equal!' -ForegroundColor Green
                        }
                        else {
                            Write-Host 'File hash of uploaded file does not match!' -ForegroundColor Red
                            if($mCleanupOnFailure) {
                                Write-Host 'Cleanup temporary file:' $mLocalFilePath
                                Remove-Item -Path $mLocalFilePath -Force -Verbose:$mVerboseOutput
                            }
                            if ($mEnabledLogging) {
                                Stop-Transcript
                            }
                            return
                        }
                    }
                }
            }
            else {
                Write-Host 'Hash value of local and remote file is equal. No Upload neccessary.' -ForegroundColor Green
            }

            # Segulink logout
            $mPayload = @{'session'=$mSessionId}
            $mResponseLogout = Invoke-WebRequest -UseBasicParsing -Uri ($mApiUri + '/logout') -Method Post -Headers $mRequestHeaders -Body ($mPayload | ConvertTo-Json) -Verbose:$mVerboseOutput
            if($mResponseLogout.StatusCode -ne 200) {
                Write-Host 'Something went wrong during logout...' -ForegroundColor Red
            }
            else {
                Write-Host 'Sucessfully logged out.' -ForegroundColor Green
                if($mLocalCleanupAfterUpload) {
                    Write-Host 'Delete local file after upload.' -ForegroundColor Green
                    Remove-Item -Path $mLocalFilePath -Force -Verbose:$mVerboseOutput
                }
                if ($mEnabledLogging) {
                    Stop-Transcript
                }
                return
            }
        }
    }
    if($mCleanupOnFailure) {
        Write-Host 'Cleanup temporary file:' $mLocalFilePath
        Remove-Item -Path $mLocalFilePath -Force -Verbose:$mVerboseOutput
    }
    if ($mEnabledLogging) {
        Stop-Transcript
    }
    exit 1
}
if($mCleanupOnFailure) {
    Write-Host 'Cleanup temporary file:' $mLocalFilePath
    Remove-Item -Path $mLocalFilePath -Force -Verbose:$mVerboseOutput
}
if ($mEnabledLogging) {
	Stop-Transcript
}

}

# end function upload_html


$mEnabledLogging = $true

$Header = "<style>"
$Header = $Header + "TABLE{border-width: 1px;border-style: solid;border-color: lightgrey;border-collapse: collapse;}"
$Header = $Header + "TH{border-width: 1px;padding: 1px;border-style: solid;border-color: lightgrey;background-color:mediumaquamarine;Text-Align:Left;font-family: Calibri;font-size: 12pt}"
$Header = $Header + "TD{border-width: 1px;padding-right: 30px;border-style: solid;border-color: lightgrey;font-family: Calibri;font-size: 11pt}"
$Header = $Header + "</style>"

$scriptdir = "C:\MR"

Clear-Host
Write-Host "Erzeuge Working directory ..."

New-Item -ItemType directory -Path $scriptdir -ErrorAction SilentlyContinue
Set-Location $scriptdir

if ($mEnabledLogging) {
	$ErrorActionPreference = "SilentlyContinue"
	Stop-Transcript | out-null
	$ErrorActionPreference = "Continue"
    $transscriptfile = $KT + '_get_assetinfo.log'
	Start-Transcript -Path $scriptdir\$transscriptfile
    }




$patchlevel = @{
    Jan2022 = "J_2012R2","J_2016","J_2019","J_2022"
    Feb2022 = "F_2012R2","F_2016","F_2019","20348.288"
    Mar2022 = "9600.20303","M_2016","17763.2686","20348.587"
    Apr2022 = "9600.20337","14393.5066","17763.2803","20348.643"
    Mai2022 = "9600.20371","14393.5125","17763.2928","20348.707"
    MaiOOB2022 = "","14393.5127","17763.2931","20348.709"
    Juni2022 = "9600.20402","14393.5192","17763.3046","20348.768"
    Juli2022 = "9600.20478","14393.5246","17763.3165","20348.825"
    August2022 = "9600.20520","14393.5291","17763.3287","20348.887"
    September2022 = "9600.20571","14393.5356","17763.3406","20348.1006"
    Oktober2022 = "9600.20625","14393.5427","17763.3532","20348.1129"
    OktoberOOB2022 = "","14393.5429","17763.3534","20348.1131"
    November2022 = "9600.20671","14393.5501","17763.3650","20348.1249"
    NovemberOOB2022 = "","14393.5502","17763.3653","20348.1251"
    Dezember2022 = "9600.20721","14393.5582","17763.3770","20348.1366"
    Januar2023 = "9600.20778","14393.5648","17763.3887","20348.1487"
    Februar2023 = "9600.20821","14393.5717","17763.4010","20348.1547"
    Maerz2023 = "9600.20878","14393.5786","17763.4131","20348.1607"
    April2023 = "9600.20919","14393.5850","17763.4252","20348.1668"
    Mai2023 = "9600.20969","14393.5921","17763.4377","20348.1311"
    Juni2023 = "9600.21013","14393.5989","17763.4499","20348.1787"
    JuniOOB2023 = "","14393.5996","",""
    Juli2023 = "9600.21075","14393.6085","17763.4645","20348.1850"
    August2023 = "9600.21503","14393.6167","17763.4737","20348.1906"
    September2023 = "9600.21563","14393.6252","17763.4851","20348.1970"
    Oktober2023 = "9600.21620","14393.6351","17763.4974","20348.2031"
    November2023 = "","14393.6452","17763.5122","20348.2113"
    Dezember2023 = "","14393.65291","17763.5206","20348.2159"
    Januar2024 = "","14393.6614","17763.5329","20348.2227"
    Februar2024 = "","14393.6709","17763.5458","20348.2322"
    Maerz2024 = "","14393.6796","17763.5576","20348.2340"
    MaerzOOB2024 = "","14393.6799","17763.5579","20348.2342"
    April2024 = "","14393.6897","17763.5696","20348.2402"
    Mai2024 = "","14393.6981","17763.5820","20348.2461"
    MaiOOB2024 = "","","17763.5830",""
    Juni2024 = "","14393.7070","17763.5936","20348.2527"
    Juni2024OOB = "","","","20348.2529"
    Juli2024 = "","14393.7159","17763.6054","20348.2582"
    August2024 = "","14393.7259","17763.6189","20348.2655"
    September2024 = "","14393.7336","17763.6293","20348.2700"
    Oktober2024 = "","14393.7428","17763.6414","20348.2655"
    November2024 = "","14393.7515","17763.6532","20348.2849"
    Dezember2024 = "","14393.7606","17763.6659","20348.2966"
    Januar2025 = "","14393.7699","17763.6775","20348.3091"
    Februar2025 = "","14393.7785","17763.6893","20348.3207"
    Maerz2025 = "","14393.7876","17763.7009","20348.3328"
    April2025 = "","14393.7973","17763.7249","20348.3566"
    Mai2025 = "","14393.8064","17763.7312","20348.3692","26100.4061"
}

    
$asset = [PSCustomObject]@{
    Status             = ''
    Hostname           = ''
    UUID               = ''
    Domainname         = ''
    Productname        = ''
    Buildnumber        = ''
    CUPatchLevel       = ''
    Locale             = ''
    FreeSpace          = ''
    SystemDrive        = ''
    CPU                = ''
    RAM                = ''
    Roles              = @{}
    Patches            = @{}
    WSUSServer         = ''
    WSUSConfig         = ''
    WSUSOptions        = ''
    NoAutoUpdate       = ''
    DotNet             = ''
    IsSQL              = ''
    SQLRunning         = ''
    IsDC               = ''
    IsHV               = ''
    timeInt            = ''
    timeExt            = ''
    AV                 = ''
    Firewall           = ''
    DefenderVersion    = ''
    DefenderEnabled    = ''
    DefenderRunning    = ''
    ExecutionPolicy    = ''
    WinRM              = ''
    ICSPorts           = ''
    PSVersion          = ''
    Cluster            = ''
    ClusterType        = ''
}

$num_onboarders = 0
$num_dcs = 0
$num_sql = 0
$num_hvs = 0

Write-Host "Erzeuge Liste der Assets ..."

$onboarders = (get-adcomputer -Filter {  OperatingSystem -Like '*Windows Server*' } ).Name
#$onboarder = @('mrm-stg-dc1')

$outfile = $KT + "_" + (Get-ADDomain).name + ".html"

$num_onboarders = ($onboarders | Measure-Object).Count
$defenderservice = ""
$defender = "1"

Write-Host "Iteriere durch alle Assets ..."

foreach($onboarder in $onboarders){
if (Resolve-dnsname -name $onboarder){
if(Test-Connection $onboarder -ea SilentlyContinue){

$rs = $Null
# Treffer
Write-host "Alive: " $onboarder -ForegroundColor Green

$asset.Status              = "Online"
$asset.Hostname            = $onboarder
$asset.UUID                = $null
$asset.Domainname          = $null
$asset.CUPatchLevel        = $null
$asset.Buildnumber         = $null
$asset.Productname         = $null
$asset.Locale              = $null
$asset.SystemDrive         = $null
$asset.FreeSpace           = $null
$asset.CPU                 = $null
$asset.RAM                 = $null
$asset.Roles               = $null
$asset.patches             = $null
$asset.wsusserver          = $null
$asset.WSUSConfig          = $null
$asset.WSUSOptions         = $null
$asset.NoAutoUpdate        = $null
$asset.dotnet              = $null
$asset.IsSQL               = $null
$asset.SQLRunning          = $null
$asset.isDC                = $null
$asset.isHV                = $null
$asset.timeInt             = $null
$asset.timeExt             = $null
$asset.AV                  = $null
$asset.Firewall            = $null
$asset.DefenderVersion     = $null
$asset.DefenderEnabled     = $null
$asset.DefenderRunning     = $null
$asset.ExecutionPolicy     = $null
$asset.WinRM               = $null
$asset.ICSPorts            = $null
$asset.PSVersion           = $null
$asset.Cluster             = $null
$asset.ClusterType         = $null

Write-Host "Nehme Verbindung mit Asset " $onboarder " auf"

# Get WinRM Service status

$asset.WinRM = (get-service -Name winrm -ComputerName $onboarder).Status

if($asset.WinRM -eq "Running"){

$asset.WinRM = "<font color = green>Running</font color>"

}else{

$asset.WinRM = ''
$asset.Status = "<font color = red><strong>No WINRM</strong></font color>"

}

$rs = New-PSSession -ComputerName  $onboarder #-ErrorAction SilentlyContinue

if($rs){
Write-Host "Verbindung hergestellt ..."

$asset.UUID                = (Invoke-Command -Session $rs -ScriptBlock {(get-wmiobject Win32_ComputerSystemProduct  | Select-Object -ExpandProperty UUID)})
$asset.Domainname          = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\tcpip\Parameters" -name Domain)}).Domain
$asset.Buildnumber         = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name UBR)}).UBR
$asset.CUPatchLevel        = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name CurrentBuildNumber)}).CurrentBuildNumber
$asset.Productname         = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name ProductName)}).ProductName
$asset.Locale              =  Invoke-Command -Session $rs -ScriptBlock {Get-WinSystemLocale} | Select-Object LCID, Name, Displayname
$asset.SystemDrive         = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name SystemRoot)}).SystemRoot
$asset.FreeSpace           =  Invoke-Command -Session $rs -ScriptBlock {param($drivespace) [math]::Round((Get-Volume $drivespace).SizeRemaining / 1024 / 1024 / 1024,2)} -ArgumentList $($asset.SystemDrive).Substring(0,1)
$asset.CPU                 =  Invoke-Command -Session $rs -ScriptBlock {(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors}
$asset.RAM                 =  Invoke-Command -Session $rs -ScriptBlock {Get-WMIObject -Class Win32_Computersystem -ErrorAction SilentlyContinue} | Select-Object TotalPhysicalMemory
$asset.Roles               =  Invoke-Command -Session $rs -ScriptBlock {Get-WindowsFeature | Where-Object{ $_.Installed }} | Select-Object name,DisplayName, FeatureType, Parent
$asset.patches             =  Invoke-Command -Session $rs -ScriptBlock {Get-HotFix} | Select-Object HotFixID, Description
$asset.wsusserver          = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -name WUServer)}).WUServer
$asset.WSUSConfig          = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -name UseWUServer)}).UseWUServer
$asset.WSUSOptions         = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -name AUOptions)}).AUOptions
$asset.NoAutoUpdate        = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -name NoAutoUpdate)}).NoAutoUpdate
$asset.DotNet              = (Invoke-Command -Session $rs -ScriptBlock {(Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -name Version)}).Version
$asset.IsSQL               =  Invoke-Command -Session $rs -ScriptBlock {Get-Service} | Select-Object Name, Displayname, Status
$asset.SQLRunning          =  Invoke-Command -Session $rs -ScriptBlock {Get-process -Name sqlservr -ea SilentlyContinue} | Select-Object ProcessName
$asset.IsDC                =  Invoke-Command -Session $rs -ScriptBlock {Get-WmiObject -Query "select * from Win32_OperatingSystem"} | Select-Object producttype
$asset.isHV                =  Invoke-Command -Session $rs -ScriptBlock {Get-WindowsFeature -Name Hyper-V}
$asset.timeInt             =  Invoke-Command -Session $rs -ScriptBlock {w32tm /query /status}
$asset.timeExt             =  Invoke-Command -Session $rs -ScriptBlock {w32tm /stripchart /computer:time.windows.com /samples:1 /dataonly}
$asset.AV                  =  Get-InstalledSoftware -ComputerName $onboarder -Name "Sophos"
if(-not $asset.AV){
$asset.AV                  =  Get-InstalledSoftware -ComputerName $onboarder -Name "Forti"
}
$asset.Firewall            =  Invoke-Command -Session $rs -ScriptBlock {$FWprofiles = $(Get-NetFirewallSetting  -PolicyStore ActiveStore);$FWActiveProfile = $FWprofiles.ActiveProfile;$(Get-NetFirewallProfile -Profile $FWActiveProfile -PolicyStore ActiveStore).Enabled}
$defenderservice           =  (Invoke-Command -Session $rs -ScriptBlock {(Get-Service windefend).Status}).Value
if ($defenderservice -ne "Stopped"){
$defender                  =  Invoke-Command -Session $rs -ScriptBlock { if ( Get-Command  "Get-MpComputerStatus"){Get-MpComputerStatus -ErrorAction SilentlyContinue}}
$asset.DefenderVersion     =  $defender.AMProductVersion
$asset.DefenderEnabled     =  $defender.AMServiceEnabled
$asset.DefenderRunning     =  $defender.AMRunningMode
}else{
$asset.DefenderVersion     =  "Installed"
$asset.DefenderEnabled     =  "Disabled"
$asset.DefenderRunning     =  "Not running"
}
$asset.ExecutionPolicy     = (Invoke-Command -Session $rs -ScriptBlock {Get-ExecutionPolicy}).Value
$asset.PSVersion           = (Invoke-Command -Session $rs -ScriptBlock {$PSVersionTable}).PSVersion
$asset.Cluster             = (Invoke-Command -Session $rs -ScriptBlock {(Get-WMIObject -Class MSCluster_ResourceGroup -Namespace root\mscluster -ErrorAction SilentlyContinue)})

if($asset.Cluster){
$asset.ClusterType         = (Invoke-Command -Session $rs -ScriptBlock {(Get-ClusterStorageSpacesDirect -ErrorAction SilentlyContinue)})
}
$asset.PSVersion           = [string]$asset.PSVersion.Major + "." + [string]$asset.PSVersion.Minor

Remove-PSSession $rs

Write-Host "Verbindung getrennt ..."
#Check for open Ports on Icinga satellite

if($icssatellite){

$port80   = Test-NetConnection $icssatellite -Port 80
$port443  = Test-NetConnection $icssatellite -Port 443
$port5665 = Test-NetConnection $icssatellite -Port 5665
}
if($port80.TcpTestSucceeded){
$asset.ICSPorts = "<font color = green>Port80</font color><br>"
}else{
$asset.ICSPorts = "<strong><font color = red>Port80</font color></strong><br>"
}

if($port443.TcpTestSucceeded){
$asset.ICSPorts = $asset.ICSPorts + "<font color = green>Port443</font color><br>"
}else{
$asset.ICSPorts = $asset.ICSPorts + "<strong><font color = red>Port443</font color></strong><br>"
}

if($port5665.TcpTestSucceeded){
$asset.ICSPorts = $asset.ICSPorts + "<font color = green>Port5665</font color>"
}else{
$asset.ICSPorts = $asset.ICSPorts + "<strong><font color = red>Port5665</font color></strong>"
}

# Finished Checking open Ports on Icinga-Satellit

$asset.Locale = $asset.Locale.DisplayName

#$asset.CPU = $asset.CPU.CsProcessors.numberoflogicalprocessors

$asset.RAM = [Math]::ceiling($asset.RAM.TotalPhysicalMemory/ 1GB)

if (-not $asset.Buildnumber){

$asset.Status = "<font color = red><strong>No WINRM</strong></font color>"

}

if ($asset.IsSQL -match "PostgreSQL Server"){

$asset.IsSQL = "PostgreSQL Server"

}

if ($asset.IsSQL -match "MSSQLServer"){

$asset.IsSQL = "MSSQL Server"
$num_sql ++

}

if ($asset.IsSQL -match "MSSQL\$"){

$asset.IsSQL = "MSSQL Server Express"

}


if($asset.IsSQL -notmatch "SQL"){

$asset.IsSQL = $null

}


if ($asset.SQLRunning  ){

$asset.SQLRunning   = "Running"

}else{

$asset.SQLRunning   = $null

}

if ($asset.IsHV[0].InstallState -match "Installed" ){

$asset.IsHV   = "HV"
$num_hvs ++

}else{

$asset.IsHV   = $null

}

if ($asset.IsDC -match "2"){

$asset.IsDC = "DC"
$num_dcs ++

}else{

$asset.IsDC = $null

}

$asset.av = $asset.av | Select-Object name


if($asset.CUPatchLevel){

Switch ($asset.AV)
{
   {$_ -match 'Sophos'}   {$asset.AV = "Sophos"; break}
   {$_ -match 'Fortinet'} {$asset.AV = "Fortinet"; break}
   {$_ -match 'FortiClient'} {$asset.AV = "Fortinet"; break}
   default                {$asset.AV ="unknown"}
}
}else{

$asset.AV = $null

}


if ($asset.Firewall.Value){
    $asset.Firewall = "<strong><font color = red>Enabled</font color></strong>"
}else{
    $asset.Firewall = "<font color = green>Disabled</font color>"
    
}

if (-not $Defender){

$asset.DefenderEnabled = "Not installed "
$asset.DefenderRunning = "Not installed"
$asset.DefenderVersion = "Not installed"

}

if (-not $asset.NoAutoUpdate -and $asset.Status -notlike "<font color = red><strong>No WINRM</strong></font color>"){

$asset.NoAutoUpdate = "0 (Default)"

}

if (-not $asset.WSUSConfig -and $asset.Status -notlike "<font color = red><strong>No WINRM</strong></font color>"){

$asset.WSUSConfig = "==Empty=="

}

if (-not $asset.WSUSOptions -and $asset.Status -notlike "<font color = red><strong>No WINRM</strong></font color>"){

$asset.WSUSOptions = "==Empty=="

}

if (-not $asset.WSUSServer -and $asset.Status -notlike "<font color = red><strong>No WINRM</strong></font color>"){

$asset.WSUSServer = "==Empty=="

}


$asset.timeInt = $asset.timeInt[4]
$asset.timeExt = $asset.timeExt[3]

if(-not $asset.Cluster){

$asset.Cluster = "Nein"
}else{
    $asset.Cluster = "Ja"
    if($asset.ClusterType){
    $asset.ClusterType = "S2D"    
    }else{
    $asset.ClusterType = "Enterprise"}
}
# Bisschen aufraeumen
if($asset.Buildnumber){
$asset.Buildnumber = $asset.CUPatchLevel + "." + $asset.Buildnumber
}else{
$asset.Buildnumber = $null
}

$asset.CUPatchLevel = $patchlevel.GetEnumerator().Where({$_.Value -contains $asset.Buildnumber}).Name

#Einige Infos werden als Hashtable zurückgegeben. Da müssen wir aufräumen

$asset.CPU.PSObject.Properties.Remove('pscomputername')
$asset.CPU.PSObject.Properties.Remove('runspaceid')
$asset.CPU.PSObject.Properties.Remove('psshowcomputername')

$asset.FreeSpace.PSObject.Properties.Remove('pscomputername')
$asset.FreeSpace.PSObject.Properties.Remove('runspaceid')
$asset.FreeSpace.PSObject.Properties.Remove('psshowcomputername')

$asset.timeInt.PSObject.Properties.Remove('pscomputername')
$asset.timeInt.PSObject.Properties.Remove('runspaceid')
$asset.timeInt.PSObject.Properties.Remove('psshowcomputername')

$asset.timeExt.PSObject.Properties.Remove('pscomputername')
$asset.timeExt.PSObject.Properties.Remove('runspaceid')
$asset.timeExt.PSObject.Properties.Remove('psshowcomputername')

$asset.UUID.PSObject.Properties.Remove('pscomputername')
$asset.UUID.PSObject.Properties.Remove('runspaceid')
$asset.UUID.PSObject.Properties.Remove('psshowcomputername')
}else{
$asset.Status ="<font color = red><strong>No WINRM</strong></font color>"}
}else{

# Anscheinend unerreichbar
Write-host "Dead:  " $onboarder -ForegroundColor Red

$asset.Status              = "Offline"
$asset.Hostname            = $onboarder
$asset.UUID                = $null
$asset.Domainname          = $null
$asset.CUPatchLevel        = $null
$asset.Buildnumber         = $null
$asset.Productname         = $null
$asset.Locale              = $null
$asset.SystemDrive         = $null
$asset.FreeSpace           = $null
$asset.CPU                 = $null
$asset.RAM                 = $null
$asset.Roles               = $null
$asset.patches             = $null
$asset.wsusserver          = $null
$asset.WSUSConfig          = $null
$asset.WSUSOptions         = $null
$asset.NoAutoUpdate        = $null
$asset.dotnet              = $null
$asset.IsSQL               = $null
$asset.SQLRunning          = $null
$asset.isDC                = $null
$asset.isHV                = $null
$asset.timeInt             = $null
$asset.timeExt             = $null
$asset.AV                  = $null
$asset.Firewall            = $null
$asset.DefenderVersion     = $null
$asset.DefenderEnabled     = $null
$asset.DefenderRunning     = $null
$asset.ExecutionPolicy     = $null
$asset.WinRM               = $null
$asset.ICSPorts            = $null
$asset.PSVersion           = $null
$asset.Cluster             = $null
$asset.ClusterType         = $null

     }
     }else{
$asset.Status              = "No DNS"
$asset.Hostname            = $onboarder
$asset.UUID                = $null
$asset.Domainname          = $null
$asset.CUPatchLevel        = $null
$asset.Buildnumber         = $null
$asset.Productname         = $null
$asset.Locale              = $null
$asset.SystemDrive         = $null
$asset.FreeSpace           = $null
$asset.CPU                 = $null
$asset.RAM                 = $null
$asset.Roles               = $null
$asset.patches             = $null
$asset.wsusserver          = $null
$asset.WSUSConfig          = $null
$asset.WSUSOptions         = $null
$asset.NoAutoUpdate        = $null
$asset.dotnet              = $null
$asset.IsSQL               = $null
$asset.SQLRunning          = $null
$asset.isDC                = $null
$asset.isHV                = $null
$asset.timeInt             = $null
$asset.timeExt             = $null
$asset.AV                  = $null
$asset.Firewall            = $null
$asset.DefenderVersion     = $null
$asset.DefenderEnabled     = $null
$asset.DefenderRunning     = $null
$asset.ExecutionPolicy     = $null
$asset.WinRM               = $null
$asset.ICSPorts            = $null
$asset.PSVersion           = $null
$asset.Cluster             = $null
$asset.ClusterType         = $null
     
     }

$asset.Hostname = $asset.Hostname.ToLower()
$assetinfo_file = $scriptdir + "\" + $KT + "_" + $($asset.Hostname) + "_03_" + $(get-date -format yyy-MM-dd_hh-mm-ss) + ".nctl"

$asset | ConvertTo-json | Out-File $assetinfo_file

<#if($asset.Status -like "Online"){

try{
Upload_json -assetinfo_file $assetinfo_file
Write-Host "Lade Asset-Datei nach MitoIO hoch ..."
Remove-Item $assetinfo_file
}catch{
Write-Host "Fehler beim Upload nach Mito" -ForegroundColor Red
}



}
#>


if($asset.FreeSpace -and $asset.FreeSpace -le 20){

$asset.FreeSpace = "<strong><font color = red>" + $asset.FreeSpace + "</font color></strong>"

}

if($asset.FreeSpace -and $asset.FreeSpace -gt 20){

$asset.FreeSpace = "<font color = green>" + $asset.FreeSpace + "</font color>"

}

if($asset.Productname -match "2012" -or $asset.Productname -match "2008"){
$asset.Productname =  "<strong><font color = red>" + $asset.Productname + "</font color></strong>"
}

if($asset.CPU -lt 4 -and $asset.Status -like "Online"){
    $asset.CPU = "<strong><font color = red>" + $asset.CPU + "</font color></strong>"
    }
    
if($asset.RAM -lt 4 -and $asset.Status -like "Online"){
    $asset.RAM = "<strong><font color = red>" + $asset.RAM + "</font color></strong>"
    }
Write-Host "Speichere Daten in HTML-File ..."

$asset | ConvertTo-Json | ConvertFrom-Json | ConvertTo-Html >> $scriptdir\$outfile -Head $Header

}

# Aufhübschen der Ergebnis-Webseite

Write-Host "Aufhuebschen der HTML-Seite ..."

$removecontent1 = '</table></body></html><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml"><head><style>TABLE{border-width: 1px;border-style: solid;border-color: lightgrey;border-collapse: collapse;}TH{border-width: 1px;padding: 1px;border-style: solid;border-color: lightgrey;background-color:mediumaquamarine;Text-Align:Left;font-family: Calibri;font-size: 12pt}TD{border-width: 1px;padding-right: 30px;border-style: solid;border-color: lightgrey;font-family: Calibri;font-size: 11pt}</style></head><body><table><colgroup><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/></colgroup><tr><th>Status</th><th>Hostname</th><th>UUID</th><th>Domainname</th><th>Productname</th><th>Buildnumber</th><th>CUPatchLevel</th><th>Locale</th><th>FreeSpace</th><th>SystemDrive</th><th>CPU</th><th>RAM</th><th>Roles</th><th>Patches</th><th>WSUSServer</th><th>WSUSConfig</th><th>WSUSOptions</th><th>NoAutoUpdate</th><th>DotNet</th><th>IsSQL</th><th>SQLRunning</th><th>IsDC</th><th>IsHV</th><th>timeInt</th><th>timeExt</th><th>AV</th><th>Firewall</th><th>DefenderVersion</th><th>DefenderEnabled</th><th>DefenderRunning</th><th>ExecutionPolicy</th><th>WinRM</th><th>ICSPorts</th><th>PSVersion</th><th>Cluster</th><th>ClusterType</th></tr>'
$removecontent2  = '<th>Roles</th><th>Patches</th>'
$removecontent3  ="<td></td><td>System.Object\[\]</td>"
$removecontent4  ="<td>System.Object\[\]</td>"
$removecontent5  = '<td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>'
$removecontent6  = "Offline"
$removecontent7  = "Online"
$removecontent8  = "Error"
$removecontent9  = "&gt;"
$removecontent10 = "&lt;"
$removecontent11 = "0x80072746"
$removecontent12  = "Fehler"
$removecontent13  = "TABLE{border-width: 1px;border-style: solid;border-color: lightgrey;border-collapse: collapse;}"
$removecontent14  = "TH{border-width: 1px;padding: 1px;border-style: solid;border-color: lightgrey;background-color:mediumaquamarine;Text-Align:Left;font-family: Calibri;font-size: 12pt}"
$removecontent15  = "TD{border-width: 1px;padding-right: 30px;border-style: solid;border-color: lightgrey;font-family: Calibri;font-size: 11pt}"
$removecontent16  = "<body>"
$removecontent17 =  "No DNS"
$insertcontent1  = "
</table><br /><br /><br />
<table><tr><td>Anzahl Assets</td><td>num_assets</td></tr>
<tr><td>Anzahl DCs</td><td>num_dcs</td></tr>
<tr><td>Anzahl SQL</td><td>num_sql</td></tr>
<tr><td>Anzahl HVs</td><td> num_hvs</td></tr>
</table>
"

$insertcontent2 ="<table>" + "<h1>Patchmanagement: Preflightcheck fuer Kunde " + $KN + "</h1><p Style = `"font-family: 'Quicksand', sans-serif; font-weight: 500; font-size: 14px;`"> (Kundennummer: " + $KT + ")<br /> Erzeugt am: " + $(get-date -Format "dd.MM.yyyy hh:mm:ss")

$content = Get-Content $scriptdir\$outfile -Raw
$content -replace "`r`n", "" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent1, " " | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent2, " " | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent3, " " | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent4, " " | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent5, "<td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent6, "<strong><font color=red>Offline</font color></strong>" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent7, "<strong><font color=green>Online</font color></strong>" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent8, "<strong><font color=red>Error</font color></strong>" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent9, ">" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent10, "<" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent11, "Timesource unreachable" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent12, "<strong><font color=red>Error</font color></strong>" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent13, "TABLE{border-width: 1px;border-style: solid;border-color: #707070;border-collapse: collapse;}tr:nth-child(even){background: #fcfcfc;}tr:nth-child(odd){background: #E0E0E0;}" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent14, "BODY{margin-left: 30px;margin-right: 30px;}H1{font-family: 'Quicksand', sans-serif; font-weight: 700; font-size: 24px;}P{font-family: 'Quicksand', sans-serif; font-weight: 300; font-size: 14px;}TH{background: #003366; color: #fff; max-width: 400px; padding: 5px 10px;  opacity: 0.5; font-family: 'Quicksand', sans-serif; font-weight: 500; font-size: 14px;}" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent15, "TD{border-width: 1px;padding-left: 10px; padding-right: 30px;border-style: solid;border-color: lightgrey;font-family: 'Quicksand', sans-serif; font-weight: 300; font-size: 14px;}" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent16, "<link href='https://fonts.googleapis.com/css?family=Quicksand:300,500,700' rel='stylesheet'><body>" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace $removecontent17, "<strong><font color=red>No DNS</font color></strong>" | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace "</table>", $insertcontent1 | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace "<body>", $insertcontent2 | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace "num_assets", $num_onboarders | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace "num_dcs", $num_dcs | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace "num_sql", $num_sql | Set-Content $scriptdir\$outfile
$content = Get-Content $scriptdir\$outfile -Raw
$content -replace "num_hvs", $num_hvs | Set-Content $scriptdir\$outfile

# Upload der Ergebnisdatei und der Logdatei nach https://share.mr-daten.de

Upload_secureshare -mFileNameToUpload $outfile -mEnabledLogging $true
Upload_secureshare -mFileNameToUpload $transscriptfile -mEnabledLogging $false
