$ErrorActionPreference = "SilentlyContinue"


$trigger = @(
    $(New-ScheduledTaskTrigger -At  4AM -weekly -Daysofweek Monday),
    $(New-ScheduledTaskTrigger -At 10AM -weekly -Daysofweek Tuesday),
    $(New-ScheduledTaskTrigger -At  8PM -weekly -Daysofweek Wednesday),
    $(New-ScheduledTaskTrigger -At  8PM -weekly -Daysofweek Thursday),
    $(New-ScheduledTaskTrigger -At  4PM -weekly -Daysofweek Friday),
    $(New-ScheduledTaskTrigger -At  8PM -weekly -Daysofweek Saturday),
    $(New-ScheduledTaskTrigger -At 10AM -weekly -Daysofweek Sunday)
)
Set-ScheduledTask -TaskName "MR Active Patching" -Trigger $trigger -User mradmin -Password "dfsdgfdgjdfg"


Unregister-ScheduledTask -TaskName "MR Active Patching MBs" -Confirm:$false
Unregister-ScheduledTask -TaskName "MR Active Patching NON-AD" -Confirm:$false
Unregister-ScheduledTask -TaskName "MR Active Patching Sunday" -Confirm:$false


Set-Location "C:\mr_managed_it\scripts"

Remove-Item "pswu-update_mbs.ps1"
Remove-Item "pswu-update_nonad.ps1"
Remove-Item "aduser.txt"