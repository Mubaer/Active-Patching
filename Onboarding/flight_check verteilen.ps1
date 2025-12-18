$vms = Get-Content -Path "C:\temp\vms.txt"

foreach($vm in $vms){
$vm
$sf = "C:\MR Flightcheck.xml"
$df = "\\$vm\C" + "$"
Copy-Item -path $sf -destination $df -force

$sf = "C:\MR_Managed_it\flight_check.ps1"
$df = "\\$vm\C" + "$" + "\mr_managed_it\"
New-Item -Path $df -ItemType directory -Force
Copy-Item -path $sf -destination $df -Force

Invoke-Command -ComputerName $vm -ScriptBlock {Register-ScheduledTask -Xml (get-content "C:\MR Flightcheck.xml" | Out-String) -TaskName "MR Flightcheck"
Remove-Item "C:\MR Flightcheck.xml"
}
}