# falls sich der Updatedienst nicht beenden lässt:

$ServicePID = (get-wmiobject win32_service | where-object {$_.state -eq 'stop pending'}).ProcessId
taskkill /pid $ServicePID /f

# Access denied für Server ohne AD und anderer User als Administrator

https://serverfault.com/questions/337905/enabling-powershell-remoting-access-is-denied

reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
Enable-PSRemoting

# Get a single Update
Get-WsusUpdate -UpdateId c9773266-ccbe-41ba-961f-adcb84202029 -RevisionNumber 201

# get all Computers
Get-WsusComputer | select Full*, IP*, OSD*, Lasts*, LastReportedS*, RequestedTargetGroupName | ft


#Falls Invoke-Command nicht über HTTP durchgeführt werden kann, weil kein SPN existiert.
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Client /v spn_prefix /t REG_SZ /d "WSMAN" /f


# Report an den WSUS erzwingen

$updateSession = new-object -com "Microsoft.Update.Session"
$updates=$updateSession.CreateupdateSearcher().Search($criteria).Updates
wuauclt /reportnow

#Das Problem haben wir in letzter Zeit auch immer mal wieder (Server 2022)
#Bei uns hat es geholfen, im IIS Manager den Application Pool 'WsusPool' zu recyclen.


<#

The default Background Intelligent Transfer Service (BITS) mode for WSUS is background priority mode. As written on Docs,

Unless the job is time critical or the user is actively waiting, you should always use a background priority. However, there are times when you may want to switch from background priority to foreground priority.

 

Set foreground priority mode for BITS, from an administrative PowerShell prompt on the WSUS server:

$Configuration=(Get-WSUSServer).GetConfiguration()
$Configuration.BitsDownloadPriorityForeground=$True
$Configuration.Save()
Set background priority mode for BITS, from an administrative PowerShell prompt on the WSUS server:

$Configuration=(Get-WSUSServer).GetConfiguration()
$Configuration.BitsDownloadPriorityForeground=$False
$Configuration.Save()
Why Would I Need To Use Foreground Priority Mode?
If the WSUS server is behind a firewall or a proxy server and the proxy server environment does not support the HTTP 1.1 range request function, it may have trouble downloading files from Microsoft in background priority mode. If you cannot modify the proxy server to allow the HTTP 1.1 range request function, configure BITS to work in foreground mode.

#>