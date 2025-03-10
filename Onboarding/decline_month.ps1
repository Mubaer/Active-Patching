# Usage: aufrufen auf WSUS-Server ohne Parameter
# Dieses Script lehnt alle updates ab, die vom 1. des aufrufenden Monats bis zum Datum des Aufrufes durch
# den WSUS-Server von MS gesynct wurden
# Rückgabe: keine

all monthly updates

Import-Module poshwsus

Connect-PSWSUSServer -WsusServer localhost -Port 8530

$date = Get-Date -Format "MM/01/yyyy"
Get-PSWSUSUpdate -FromCreationDate $date -ApprovedState LatestRevisionApproved | Deny-PSWSUSUpdate
