# Aufrufen auf WSUS-Server
# Führt einen CLeanup durch, alte Updates werden declined und anschließend gelöscht.
# Regelmäßig ausführen, einmal pro Monat 1.Freitag?
# Parameter: keine
# Rückgabe: Ergebnis des Bereinigungsvorgangs.

# Diese Variante braucht sqlcmd.exe

Import-Module pswindowsupdate
Import-Module poshwsus
$date = $(Get-Date).AddDays(-365)

Connect-PSWSUSServer -WsusServer localhost -Port 8530
Get-WsusServer -Name localhost -PortNumber 8530
Get-PSWSUSUpdate -ToCreationDate $date | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate

Get-WsusServer | Invoke-WsusServerCleanup –CleanupObsoleteUpdates -CleanupUnneededContentFiles -CompressUpdates -DeclineExpiredUpdates -DeclineSupersededUpdates


Set-Location "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"
.\SQLCMD.EXE -S np:\\.\pipe\MICROSOFT##WID\tsql\query -i "C:\Scripts\WSUSDBMaintenance.sql"

