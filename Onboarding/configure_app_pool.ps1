# Usage: aufrufen ohne Parameter auf WSUS-Server
# Das script konfiguriert den IIS AppPool auf einem frisch installierten WSUS-Server
# Rückgabe: keine

$pool = Get-IISAppPool -name wsuspool

Start-IISCommitDelay
(Get-IISAppPool -Name WSUSPool).queuelength = 15000
(Get-IISAppPool -Name WSUSPool).cpu.limit = 50000
(Get-IISAppPool -Name WSUSPool).Recycling.periodicrestart.privatememory = 0
Stop-IISCommitDelay


$pool.Recycle()