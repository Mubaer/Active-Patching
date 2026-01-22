REM Achtung, vorher müssen auf Servern, die die Deinstallation nicht über N-Central sauber machen
REM die Dateien uninst000.dat in die entsprechenden Verzeichnisse kopiert werden
REM
REM RHA muss kopiert werden nach "C:\Program Files (x86)\MspPlatform\RequestHandlerAgent"
REM FCSA muss kopiert werden nach "C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent"

REM Die Software der Probe wird VORHER über N-Central deinstalliert.

if exist "C:\Program Files (x86)\MspPlatform\RequestHandlerAgent\unins000.exe" "C:\Program Files (x86)\MspPlatform\RequestHandlerAgent\unins000.exe" /SILENT
if exist "C:\Program Files (x86)\MspPlatform\PME\unins000.exe" "C:\Program Files (x86)\MspPlatform\PME\unins000.exe" /SILENT
if exist "C:\Program Files (x86)\SolarWinds MSP\Ecosystem Agent\unins000.exe" "C:\Program Files (x86)\SolarWinds MSP\Ecosystem Agent\unins000.exe" /SILENT
if exist "C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent\unins000.exe" "C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent\unins000.exe" /SILENT
MsiExec.exe /X{3E869620-B65D-49C0-9FD1-702790098D6B} /qn



REM Danach folgende Verzeichnisse entfernen:
REM C:\ProgramDATA\MSPEcosystem
REM C:\ProgramDATA\MspPlatform
REM C:\ProgramDATA\N-able Technologies
REM C:\ProgramDATA\SolarWinds MSP

# Andere Methode (remove N-Central Windows Agent deinstalliert auch alle andere Software)


$computernames = $get-wsuscomputer).FullDomainName

$softwareName = "Icinga 2"

foreach ($computername in $computernames){
$computername
$software = Get-WmiObject Win32_Product -ComputerName $computername | Where-Object { $_.Name -eq $softwareName }

if ($software) {
    $software.Uninstall()
} else {
    Write-Host "$softwareName is not installed on $computername"
}

$ErrorActionPreference = "Silentlycontinue"

Remove-Item "\\$computername\c$\mr_managed_it" -Recurse -Force
Remove-Item "\\$computername\c$\mrdaten" -Recurse -Force
Remove-Item "\\$computername\c$\ProgramData\Icinga2" -Recurse -Force
Remove-Item "\\$computername\c$\Program Files\Icinga2" -Recurse -Force
Remove-Item "\\$computername\c$\Program Files\WindowsPowershell\Modules\icinga-powershell-framework" -Recurse -Force
Remove-Item "\\$computername\c$\Program Files\WindowsPowershell\Modules\icinga-powershell-plugins" -Recurse -Force

}

# oder (andere Möglichkeit)

$computername = "RemoteComputerName"
$softwareName = "SoftwareName"

$uninstallString = Invoke-Command -ComputerName $computername -ScriptBlock {
    $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    Get-ItemProperty $uninstallKey | Where-Object { $_.DisplayName -eq $using:softwareName } | Select-Object -ExpandProperty UninstallString
}

if ($uninstallString) {
    Invoke-Command -ComputerName $computername -ScriptBlock {
        Start-Process -FilePath $using:uninstallString -ArgumentList "/quiet" -Wait
    }
} else {
    Write-Host "$softwareName is not installed on $computername"
}