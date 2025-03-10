# Usage: Script erwartet einen Parameter. Dieser muss in der Form KB<Nummer> vorliegen
# Beispiel: KB1234567
# Ausgabewert: keiner. 
# Falls das Script korrekt arbeitet, wird ein Patch auf dem WSUS-Server, der damit bearbeitet wird, zur Installation
# für die Groups MR_Server und MR_Server_SQL freigegeben

Param(
    [string]$KBNumber
)


Import-Module poshwsus

Connect-PSWSUSServer -WsusServer localhost -Port 8530

$GroupsAll = Get-PSWSUSGroup -Name 'MR_Server', 'MR_Server_SQL'

Get-PSWSUSUpdate -Update $KBNumber | Where-Object {$_.IsDeclined -match 'False'} | Approve-PSWSUSUpdate  -Group $GroupsAll -Action Install
