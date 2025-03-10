Uninstall-WindowsFeature updateservices, windows-internal-database

Get-ScheduledTask -TaskName "MR Active*" | Unregister-ScheduledTask -Confirm:$false
Get-ScheduledTask -TaskName "MR PostflightCheck" | Unregister-ScheduledTask -Confirm:$false
Get-ScheduledTask -TaskName "WSUS_Cleanup" | Unregister-ScheduledTask -Confirm:$false
Get-ScheduledTask -TaskName "MR FlightCheck" | Unregister-ScheduledTask -Confirm:$false
Get-ScheduledTask -TaskName "MR Set Credentials" | Unregister-ScheduledTask -Confirm:$false

Remove-Item -Recurse "C:\mr_managed_it\"
Remove-Item -Recurse "C:\Windows\WID\"
Remove-Item -Recurse "W:\WSUS_Updates"

Remove-Item -Recurse "HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\NonWorkSchedule\"
Remove-Item -Recurse "HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling\WorkSchedule\"
