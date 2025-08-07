Param(
    [Parameter(Mandatory)] [string]$username,
    [Parameter(Mandatory)] [string]$password
) 

$tasks = Get-ScheduledTask | ? {$_.TaskName -like  "MR *"}

foreach ($task in $tasks) {

$task | Set-ScheduledTask -User $username -Password $password

}