Import-Module pswindowsupdate
Get-WsusServer -Name localhost -PortNumber 8530


$WSUSComputers = Get-WsusComputer #-NameIncludes "-rd"
$vms = @()

ForEach ($WSUSComputer in $WSUSComputers){
$add_object = 0
$tsgw   = Get-Windowsfeature -Name RDS-Gateway           -ComputerName $WSUSComputer.FullDomainName -ErrorAction SilentlyContinue
$tssdis = Get-Windowsfeature -Name RDS-Connection-Broker -ComputerName $WSUSComputer.FullDomainName -ErrorAction SilentlyContinue
$tsts   = Get-Windowsfeature -Name RDS-RD-Server         -ComputerName $WSUSComputer.FullDomainName -ErrorAction SilentlyContinue
$tslic  = Get-Windowsfeature -Name RDS-Licensing         -ComputerName $WSUSComputer.FullDomainName -ErrorAction SilentlyContinue

if ($tsts.Installed){
$TermServ = "Yes"
$add_object = 1
}else{
$TermServ = "No"}

if ($tsgw.Installed){
$GWServ = "Yes"
$add_object = 1
}else{
$GWServ = "No"}

if ($tssdis.Installed){
$CBServ = "Yes"
$add_object = 1
}else{
$CBServ = "No"}

if ($tslic.Installed){
$LICServ = "Yes"
$add_object = 1
}else{
$LICServ = "No"}

if($add_object -eq 1){
$vms += [pscustomobject]@{Computername = $WSUSComputer.FullDomainName; Connection_Broker = $CBServ; Remote_Gateway = $GWServ; Session_Host = $TermServ; Licensing_Server = $LICServ}
#if ($GWServ -like "No") {
    Invoke-Command -ComputerName $WSUSComputer.FullDomainName -ScriptBlock {New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate' -Name 'TargetGroup' -Value 'MR_Server_RDS' -PropertyType String -Force}
}
#}
}

$vms

ForEach ($vm in $vms){

if ($vm.Connection_Broker -like "Yes"){

$collections = Get-RDSessionCollection -ConnectionBroker $vm.Computername

foreach ($collection in $collections){

$col_name = $collection.collectionname

Get-RDSessionHost -CollectionName $col_name -ConnectionBroker $vm.Computername


}
}


}