# Einfach auf dem WSUS-Server aufrufen.
# Parameter: Keine
# Ausgabe: laufen noch irgendwelche Patch-Jobs, die nicht fertig sind

Import-Module pswindowsupdate
Get-WsusServer -Name localhost -PortNumber 8530


$WSUSComputers = Get-WsusComputer #-NameIncludes wu2



ForEach ($WSUSComputer in $WSUSComputers){

$FDN = $WSUSComputer.FullDomainName
$Sourcepath = "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate"
$Destpath   = "\\$FDN\C" + "$" + "\Program Files\WindowsPowerShell\Modules"
Write-Host "Wir kopieren ..."
New-Item -Path $DestPath -ItemType directory -ErrorAction SilentlyContinue
Copy-Item -Recurse -Path $SourcePath -destination $DestPath -ErrorAction SilentlyContinue


$i = 0
$result = ''
$FDN
$result = Invoke-Command -ComputerName $FDN -ScriptBlock {Import-Module PSWindowsUpdate; Get-WUHistory -MaxDate (Get-Date).AddDays(-30) -Last 100 | Select-Object Computername, Title, Date, Result}
while($result[$i]){
if($result[$i].result -match "InProgress") { write-host $result[$i].Title $result[$i].Date $result[$i].Result
}
$i++}
Get-WURebootStatus -ComputerName  $FDN -Silent 


}

