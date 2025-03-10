Clear-Host
$gpo_name = Read-host "Bitte den GPO-Namen eingeben (nicht zwingend exakt, aber zwingend eindeutig) "
$vms = Get-Content -Path "C:\mr_managed_it\temp\vms.txt"
$ous = @()
$ous_check = @()
$sub_ous = New-Object System.Collections.Generic.List[System.Object]
foreach ($vm in $vms){

$result = Invoke-Command -ScriptBlock {gpresult /r} -ComputerName $vm -ErrorAction SilentlyContinue

if ($result -match $gpo_name){

Write-host $vm "wendet die GPO an" -ForegroundColor Green

$delimiter = "."
$splitString = $vm.Split($delimiter)
$vm = $splitString[0]

$result = $(Get-ADComputer $vm -Properties DistinguishedName).DistinguishedName

# Aufbereitung für die Suche im AD: abschneiden des Hostnames
$pos = $result.IndexOf(",")
$rightPart = $result.Substring($pos+1)
$sub_ous_found = Get-ADOrganizationalUnit -SearchBase $rightpart -SearchScope Subtree -Filter * |  Select-Object DistinguishedName | Format-Table -HideTableHeaders
if($sub_ous_found.count -gt 5){
$sub_ous.Add($sub_ous_found)
}
# Aufbereitung für die Ausgabe
$delimiter = "\,DC="
$splitString = $result -Split $delimiter
$ou = $splitString[0]
$ou = $ou.Replace("CN=","")
$ou = $ou.Replace(",OU=","\")
$hostname = $ou.IndexOf("\")
$ou = $ou.Substring($hostname)
$ou
$ous = $ous + $ou + "`n"
$ou_name = $result.IndexOf(",")

$ou_check = $result.Remove($result.IndexOf("CN="), $ou_name +1)
$ous_check = $ous_check + $ou_check

}else{

        if($result -match "COMPUTER"){
        Write-Host $vm "wendet die Richtlinie nicht an" -ForegroundColor Yellow
        }else{
        Write-Host $vm "nicht erreichbar" -ForegroundColor Red
        }
      }
}


$ous = $ous | Select-Object -Unique
$ous_check = $ous_check | Select-Object -Unique
$gpo_name = Get-GPO -All | Where-Object {$_.DisplayName -match $gpo_name}
Get-GPOReport -Name $gpo_name.DisplayName -ReportType xml | Out-File -FilePath C:\mr_managed_it\temp\test.xml
$SOMPaths = Get-Content -Path "C:\mr_managed_it\temp\test.xml" | Select-String -pattern "<SOMPath>"
$SOMPaths = $SOMPaths -Replace "</SOMPATH>","" -Replace "<SOMPATH>",""

Write-Host " "
Write-Host " "
Write-Host " "
Write-Host "Ergebnis:"
Write-Host "------------------------------------------------------------------------------------------------"
Write-Host " "

Write-Host "[1] Folgende OUs enthalten Assets aus unserer Liste."
Write-Host " "
Write-host $ous -ForegroundColor Green
Write-Host " "
Write-Host " "
Write-Host "[2] In folgenden OUs befinden sich Kunden-Assets, die NICHT in unserer Liste sind." -ForegroundColor Red


foreach ($ou_check in $ous_check){
Write-Host " "
$notmanaged_vm = ""
$found_vms = Get-ADComputer -Filter * -SearchBase $ou_check | Select-Object DNSHostName

foreach($found_vm in $found_vms){

if ($vms -notcontains $found_vm.DNSHostName){

$notmanaged_vm += $found_vm.DNSHostName + "`n"

}

}

if ($notmanaged_vm){

Write-Host $ou_check
$notmanaged_vm

}


}
Write-Host " "
Write-Host " "
Write-Host "[3] Die GPO wird auf folgende OUs angewendet."
Write-Host " "
$SOMPaths
Write-Host " "
Write-Host " "

Write-Host "[4] Es gibt Unter-OUs unterhalb der OUs aus [1]"
$sub_ous  | Select-Object -Unique
Write-Host " "

Write-Host "[1] Diese OUs müssen gecheckt werden. Dort wird vom Kunden in unsere Assets eingegriffen. Evtl. muss hier sichergestellt werden, dass unsere Assets darunter" -ForegroundColor Cyan
Write-Host "    nicht von diesen Kundenseitigen Einstellungen beeinflusst werden." -ForegroundColor Cyan

Write-Host "[2] Achtung. Falls hier die GPO deaktiveriert oder gelöscht wird, betrifft das auch Assets, die nicht von uns verwaltet" -ForegroundColor Cyan
Write-Host "    werden. Es muss sichergestellt werden, dass diese Assets weiterhin die Einstellungen des Kunden behalten/übernehmen." -ForegroundColor Cyan

Write-Host "[3] Hier wird die GPO angewendet. Das heißt aber nicht, dass sie nur hier wirkt. Falls es Unter-OUs zu diesen OUs gibt und dort die Vererbung" -ForegroundColor Cyan
Write-Host "    nicht unterbrochen ist (die Standardfall) wirkt die OU auch auf die Unter-OUs. Sollten also in einer Unter-OU Assets des Kunden sein, die" -ForegroundColor Cyan
Write-Host "    wir nicht verwalten muss sichergestellt werden, dass diese Assets nachwievor die Einstellungen des Kunden behalten." -ForegroundColor Cyan

Write-Host "[4] Die GPO wird zwar NICHT explizit auf diese Unter-OUs angewendet, aber durch Vererbung auf diese Unter-OUs vererbt." -ForegroundColor Cyan
Write-Host "    Das bedeutet, dass auch evtl. sich dort befindliche Kunden-Assets, die wir nicht managen, von dieser GPO betroffen" -ForegroundColor Cyan
Write-Host "    sind. Dies bitte bei der Deaktivierung der GPO beachten." -ForegroundColor Cyan


