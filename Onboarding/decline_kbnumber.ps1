# Usage: Script erwartet genau eine Parameter. Dieser Parameter muss die Form KB<Nummer> haben
# Beispiel: KB1234567
# Rückgabe: keine

Param(
    [string]$KBNumber
)


Import-Module poshwsus

Connect-PSWSUSServer -WsusServer localhost -Port 8530

Get-PSWSUSUpdate -Update $KBNumber | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate





