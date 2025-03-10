#####################################################
# Script zur Ermittlung der Voraussetzungen fuer    #
# das Onboarden eines kompletten Asset-Satzes eine  #
# Kunden. Alle Windows-Server werden ermittelt.     #
# Peter Ziegler 05/2022                             #
#####################################################


####################################
#                                  #
# Wurde eine Kunden-KT übergeben?  #
#                                  #
####################################

param (
[Parameter(Mandatory=$true)][String]$KT
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
                $UninstallKeys += Get-ChildItem HKU: | where { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | foreach {
                    "HKU:\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
                }
                if (-not $UninstallKeys) {
                    Write-Warning -Message 'No software registry keys found'
                } else {
                    foreach ($UninstallKey in $UninstallKeys) {
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
        [string]$outjson
    )

Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
    ServicePoint srvPoint, X509Certificate certificate,
    WebRequest request, int certificateProblem) {
        return true;
    }
}
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Set Tls versions
$allProtocols = [System.Net.SecurityProtocolType]'Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $allProtocols

#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$upload_uri = "https://mitoio.mr-daten.lan/io.php"
$upload_token = "DEQ1xUIP0H0CPGwd8cLP1lkkCh4Uql10yf5e0NI053OCdV"
$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"
$OutputFileName = (Get-Item -Path $outjson).Name
$SubmitFile = [System.IO.File]::ReadAllText($outjson)

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
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    #$Result = 1001
    #Exit 1001
}



}

$Header = "<style>"
$Header = $Header + "TABLE{border-width: 1px;border-style: solid;border-color: lightgrey;border-collapse: collapse;}"
$Header = $Header + "TH{border-width: 1px;padding: 1px;border-style: solid;border-color: lightgrey;background-color:mediumaquamarine;Text-Align:Left;font-family: Calibri;font-size: 12pt}"
$Header = $Header + "TD{border-width: 1px;padding-right: 30px;border-style: solid;border-color: lightgrey;font-family: Calibri;font-size: 11pt}"
$Header = $Header + "</style>"



$scriptdir = "C:\MR"

clear

New-Item -ItemType directory -Path $scriptdir -ErrorAction SilentlyContinue

cd $scriptdir

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
    Dezember2022 = "","14393.5582","17763.3770","20348.1366"
    Januar2023 = "","14393.5648","17763.3887","20348.1487"
    Februar2023 = "","14393.5717","17763.4010","20348.1547"
}


$executionpolicy = @{
    0 = "Unrestricted"
    1 = "RemoteSigned"
    2 = "AllSigned"
    3 = "Default","Restricted","Undefined"
    4 = "Bypass"
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
    ExecutionPolicy    = ''
}


$onboarder = $env:computername
$outfile = $scriptdir + "\" + $KT + "_" + $onboarder + "_03_" + (get-date -format yyyy-MM-dd-hh-mm-ss) + ".html"

$asset.Status              = "Alive"
$asset.Hostname            = $onboarder
$asset.UUID                = $null
$asset.Domainname          = $null
$asset.CUPatchLevel        = $null
$asset.Buildnumber         = $null
$asset.Productname         = $null
$asset.Locale              = $null
$asset.SystemDrive         = $null
$asset.FreeSpace           = $null
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
$asset.ExecutionPolicy     = $null

$asset.UUID                = get-wmiobject Win32_ComputerSystemProduct  | Select-Object -ExpandProperty UUID
$asset.Domainname          = (Get-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\tcpip\Parameters" -name Domain).Domain
$asset.Buildnumber         = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name UBR).UBR
$asset.CUPatchLevel        = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name CurrentBuildNumber).CurrentBuildNumber
$asset.Productname         = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name ProductName).ProductName
$asset.Locale              = Get-WinSystemLocale | select LCID, Name, Displayname
$asset.SystemDrive         = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -name SystemRoot).SystemRoot
$asset.FreeSpace           = [math]::Round((Get-Volume $($asset.SystemDrive).Substring(0,1)).SizeRemaining / 1024 / 1024 / 1024,2) 
$asset.Roles               = Get-WindowsFeature | Where { $_.Installed } | select name,DisplayName, FeatureType, Parent
$asset.patches             = Get-HotFix | select HotFixID, Description
$asset.wsusserver          = (Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -name WUServer).WUServer
$asset.WSUSConfig          = (Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -name UseWUServer).UseWUServer
$asset.WSUSOptions         = (Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -name AUOptions).AUOptions
$asset.NoAutoUpdate        = (Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -name NoAutoUpdate).NoAutoUpdate
$asset.DotNet              = (Get-itemproperty -path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -name Version).Version
$asset.IsSQL               = Get-Service | select DisplayName
$asset.SQLRunning          = Get-process -Name sqlservr -ea SilentlyContinue | select ProcessName
$asset.IsDC                = Get-WmiObject -Query "select * from Win32_OperatingSystem" | select producttype
$asset.isHV                = Get-WindowsFeature -Name Hyper-V
$asset.timeInt             = w32tm /query /status
$asset.timeExt             = w32tm /stripchart /computer:time.windows.com /samples:1 /dataonly
$asset.AV                  = Get-InstalledSoftware -ComputerName $onboarder -Name "Sophos"
if(-not $asset.AV){
$asset.AV                  = Get-InstalledSoftware -ComputerName $onboarder -Name "Forti"
}
$asset.ExecutionPolicy     = $(Get-ExecutionPolicy)



if ($asset.IsSQL -match "PostgreSQL Server"){

$asset.IsSQL = "PostgreSQL Server"

}

if ($asset.IsSQL -match "SQL Server-"){

$asset.IsSQL = "MSSQL Server"

}




if($asset.IsSQL -notmatch "SQL Server"){

$asset.IsSQL = $null

}


if ($asset.SQLRunning  ){

$asset.SQLRunning   = "Running"

}else{

$asset.SQLRunning   = $null

}

if ($asset.IsHV[0].InstallState -match "Installed" ){

$asset.IsHV   = "HV"

}else{

$asset.IsHV   = $null

}

if ($asset.IsDC -match "2"){

$asset.IsDC = "DC"

}else{

$asset.IsDC = $null

}

$asset.av = $asset.av | select name


if($asset.CUPatchLevel){

Switch ($asset.AV)
{
   {$_ -match 'Sophos'}      {$asset.AV = "Sophos"; break}
   {$_ -match 'Fortinet'}    {$asset.AV = "Fortinet"; break}
   {$_ -match 'FortiClient'} {$asset.AV = "Fortinet"; break}
   default                   {$asset.AV ="unknown"}
}
}else{

$asset.AV = $null

}


if (-not $asset.NoAutoUpdate -and $asset.Status -notlike "Error"){

$asset.NoAutoUpdate = "0 (Default)"

}

if (-not $asset.WSUSConfig -and $asset.Status -notlike "Error"){

$asset.WSUSConfig = "==Empty=="

}

if (-not $asset.WSUSOptions -and $asset.Status -notlike "Error"){

$asset.WSUSOptions = "==Empty=="

}

if (-not $asset.WSUSServer -and $asset.Status -notlike "Error"){

$asset.WSUSServer = "==Empty=="

}


$asset.timeInt = $asset.timeInt[4]
$asset.timeExt = $asset.timeExt[3]

# Bisschen aufraeumen
if($asset.Buildnumber){
$asset.Buildnumber = $asset.CUPatchLevel + "." + $asset.Buildnumber
}else{
$asset.Buildnumber = $null
}

$asset.CUPatchLevel    = $patchlevel.GetEnumerator().Where({$_.Value -contains $asset.Buildnumber}).Name
$asset.ExecutionPolicy = $executionpolicy.GetEnumerator().Where({$_.Value -contains $asset.EXecutionPolicy}).value

#Einige Infos werden als Hashtable zurückgegeben. Da müssen wir aufräumen

$asset.FreeSpace.PSObject.Properties.Remove('pscomputername')
$asset.FreeSpace.PSObject.Properties.Remove('runspaceid')
$asset.FreeSpace.PSObject.Properties.Remove('psshowcomputername')

$asset.timeInt.PSObject.Properties.Remove('pscomputername')
$asset.timeInt.PSObject.Properties.Remove('runspaceid')
$asset.timeInt.PSObject.Properties.Remove('psshowcomputername')

$asset.timeExt.PSObject.Properties.Remove('pscomputername')
$asset.timeExt.PSObject.Properties.Remove('runspaceid')
$asset.timeExt.PSObject.Properties.Remove('psshowcomputername')

$asset.Hostname = $asset.Hostname.ToLower()
$outjson = $scriptdir + "\" + $KT + "_" + $($asset.Hostname) + "_03_" + $(get-date -format yyy-MM-dd_hh-mm-ss) + ".nctl"
$asset | ConvertTo-json | Out-File $outjson

Upload_json -outjson $outjson

if($asset.FreeSpace -and $asset.FreeSpace -le 20){

$asset.FreeSpace = "<font color = red>" + $asset.FreeSpace + "</font color>"

}

if($asset.FreeSpace -and $asset.FreeSpace -gt 20){

$asset.FreeSpace = "<font color = green>" + $asset.FreeSpace + "</font color>"

}

$asset | ConvertTo-Json | ConvertFrom-Json | ConvertTo-Html >> $outfile -Head $Header


# Aufhübschen der Ergebnis-Webseite

$removecontent1 = '
</table>
</body></html>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<style>TABLE{border-width: 1px;border-style: solid;border-color: lightgrey;border-collapse: collapse;}TH{border-width: 1px;padding: 1px;border-style: solid;border-color: lightgrey;background-color:mediumaquamarine;Text-Align:Left;font-family: Calibri;font-size: 12pt}TD{border-width: 1px;padding-right: 30px;border-style: solid;border-color: lightgrey;font-family: Calibri;font-size: 11pt}</style>
</head><body>
<table>
<colgroup><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/><col/></colgroup>
<tr><th>Status</th><th>Hostname</th><th>Productname</th><th>Buildnumber</th><th>CUPatchLevel</th><th>Locale</th><th>FreeSpace</th><th>SystemDrive</th><th>Roles</th><th>Patches</th><th>WSUSServer</th><th>WSUSConfig</th><th>WSUSOptions</th><th>NoAutoUpdate</th><th>DotNet</th><th>IsSQL</th><th>SQLRunning</th><th>IsDC</th><th>IsHV</th><th>timeInt</th><th>timeExt</th><th>AV</th><th>ExecutionPolicy</th></tr>'

$removecontent2  = '<th>Roles</th><th>Patches</th>'
$removecontent3  ="<td></td><td>System.Object\[\]</td>"
$removecontent4  ="<td>System.Object\[\]</td>"
$removecontent5  = '<td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>'
$removecontent6  = "Dead"
$removecontent7  = "Alive"
$removecontent8  = "Error"
$removecontent9  = "&gt;"
$removecontent10 = "&lt;"
$removecontent11 = "0x80072746"
$removecontent12  = "Fehler"


$content = Get-Content $outfile -Raw
$content -replace $removecontent1, " " | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent2, " " | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent3, " " | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent4, " " | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent5, "<td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>" | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent6, "<font color=red>Dead</font color>" | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent7, "<font color=green>Alive</font color>" | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent8, "<font color=red>Error</font color>" | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent9, ">" | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent10, "<" | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent11, "Timesource unreachable" | Set-Content $outfile
$content = Get-Content $outfile -Raw
$content -replace $removecontent12, "<font color=red>Error</font color>" | Set-Content $outfile


# Nicht-AD-Server? lokal laufen lassen
# exe für Kunde, html für pre-onboarding-Übersicht
# für N-Central: regelmäßig lokal für einzelnes Asset laufen lassen. Kein html, nur json
