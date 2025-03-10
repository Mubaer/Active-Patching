# $hostname ist der per DNS auflösbare name des Assets, das gepatcht werden soll, er muss dem Namen in MITO entsprechen
# $username ist der lokale Username, der von der MR verwendet wird. Das kann z.B. der Benutzer mr-support oder mradmin sein oder auch Administrator
# $password ist das lokal auf dem Asset gültige Passwort des Users.
# Die Anführungszeichen müssen jeweils mit im Script stehen, die spitzen Klammern dürfen nicht drin stehen
# für jedes Asset muss ein eigenes Pärchen von Anweisungen eingetragen werden

Param(
    [Parameter(Mandatory)] [string]$hostname,
    [Parameter(Mandatory)] [string]$username,
    [Parameter(Mandatory)] [string]$password
)


Remove-StoredCredential -Target $hostname
New-StoredCredential -Target $hostname -UserName $username -Password $password -Persist LocalMachine


