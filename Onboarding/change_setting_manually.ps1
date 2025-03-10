# Damit können auf allen Hosts schnell mal ein Paar Settings geändert werden


$WSUSComputers = Get-WsusComputer

ForEach ($WSUSComputer in $WSUSComputers){

$FDN = $WSUSComputer.FullDomainName
$rnd = get-random -Maximum 2

if($rnd -eq '0'){

$result = Invoke-Command -ComputerName $FDN -ScriptBlock {New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'AlwaysAutoRebootAtScheduledTime' -Value '0' -PropertyType DWORD -Force}

}else{

$result = Invoke-Command -ComputerName $FDN -ScriptBlock {New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'AlwaysAutoRebootAtScheduledTime' -Value '1' -PropertyType DWORD -Force}

}

}

Invoke-Command -ComputerName mrm-stg-22pswu1 -ScriptBlock {New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate' -Name 'TargetGroup' -Value 'MR_Server' -PropertyType String -Force}