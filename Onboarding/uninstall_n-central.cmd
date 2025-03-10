REM Achtung, vorher müssen auf Servern, die die Deinstallation nicht über N-Central sauber machen
REM die Dateien uninst000.dat in die entsprechenden Verzeichnisse kopiert werden
REM
REM RHA muss kopiert werden nach "C:\Program Files (x86)\MspPlatform\RequestHandlerAgent"
REM FCSA muss kopiert werden nach "C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent"

REM Die Software der Probe wird VORHER über N-Central deinstalliert.

if exist "C:\Program Files (x86)\MspPlatform\RequestHandlerAgent\unins000.exe" "C:\Program Files (x86)\MspPlatform\RequestHandlerAgent\unins000.exe" /SILENT
if exist "C:\Program Files (x86)\MspPlatform\PME\unins000.exe" "C:\Program Files (x86)\MspPlatform\PME\unins000.exe" /SILENT
if exist "C:\Program Files (x86)\SolarWinds MSP\Ecosystem Agent\unins000.exe" "C:\Program Files (x86)\SolarWinds MSP\Ecosystem Agent\unins000.exe" /SILENT
if exist "C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent\unins000.exe" "C:\Program Files (x86)\MspPlatform\FileCacheServiceAgent\unins000.exe" /SILENT
MsiExec.exe /X{3E869620-B65D-49C0-9FD1-702790098D6B} /qn

REM
