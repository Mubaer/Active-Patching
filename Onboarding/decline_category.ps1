# Usage: one or two parameters
# First parameter is mandatory. Must be from the list of Categories (search terms) in MITO
# Second parameter ist optional. If present, script will decline matching patches from current month only
# If absent, all Patches matching the category will be declined
# Return: nothing


Param(
    [string]$Category,
    [string]$month
)

Import-Module poshwsus

Connect-PSWSUSServer -WsusServer localhost -Port 8530

$date = Get-Date -Format "MM/01/yyyy"

if ($Category -eq "Alle"){
Get-PSWSUSUpdate -FromCreationDate $date | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate #-WhatIf
exit 0
}

if($month){

Get-PSWSUSUpdate -FromCreationDate $date | Where-Object {$_.Title -match $Category} | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate #-WhatIf
}
else
{
Get-PSWSUSUpdate -Update $Category | Where-Object {$_.IsDeclined -match 'False'} | Deny-PSWSUSUpdate #-WhatIf
}


