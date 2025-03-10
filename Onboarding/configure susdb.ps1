# Usage: aufrufen ohne Parameter
# dieses Script konfiguriert die WID auf einem frisch installierten WSUS-Server.
# Aufrufen auf WSUS-Server
# Rückgabe: keine

$ConnectionString = 'server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true;'

$SQLConnection= New-Object System.Data.SQLClient.SQLConnection($ConnectionString)
$SQLConnection.Open()
$SQLCommand = $SQLConnection.CreateCommand()
$SQLCommand.CommandText = 'USE SUSDB; select MaxXMLPerRequest from tbConfigurationC'
$SqlDataReader = $SQLCommand.ExecuteReader()
$SQLDataResult = New-Object System.Data.DataTable
$SQLDataResult.Load($SqlDataReader)
$SQLConnection.Close()
$SQLDataResult

#5242880


$ConnectionString = 'server=\\.\pipe\MICROSOFT##WID\tsql\query;database=SUSDB;trusted_connection=true;'

$SQLConnection= New-Object System.Data.SQLClient.SQLConnection($ConnectionString)
$SQLConnection.Open()
$SQLCommand = $SQLConnection.CreateCommand()
$SQLCommand.CommandText = 'USE SUSDB; UPDATE tbConfigurationC SET MaxXMLPerRequest = 0'
$SqlDataReader = $SQLCommand.ExecuteReader()
$SQLDataResult = New-Object System.Data.DataTable
$SQLDataResult.Load($SqlDataReader)
$SQLConnection.Close()
$SQLDataResult

#5242880
# Quelle: https://www.ajtek.ca/wsus/how-do-i-connect-to-the-windows-internal-database-wid/