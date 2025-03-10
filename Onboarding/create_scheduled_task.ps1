# Usage. Aufrufen ohne Parameter
# Das Script C:\MyScript.ps1 muss existieren
# Dieses Script erzeugt einen Scheduled Task auf einem Windows-System
# Rückgabe: keine

$Action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NonInteractive -NoLogo -NoProfile -File "C:\MyScript.ps1"'
$Trigger = New-ScheduledTaskTrigger -Once -At 3am
$Settings = New-ScheduledTaskSettingsSet
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings
Register-ScheduledTask -TaskName 'My PowerShell Script' -InputObject $Task -User 'mrm.stg\administrator' -Password 'supergeheim'
