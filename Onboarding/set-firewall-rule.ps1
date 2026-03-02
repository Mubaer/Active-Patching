#Get-WsusServer -Name localhost -PortNumber 8530

#$VMs = get-wsuscomputer | Select-Object fulldomainname

#ForEach ($vm in $vms){

#Invoke-Command -ComputerName $vm.FullDomainName -ScriptBlock {

#$ruleexists = Get-NetFirewallRule -DisplayName "Enable PSUpdate" -ea SilentlyContinue

#if( -not $ruleexists){

New-NetFirewallRule -DisplayName "Enable PSUpdate" -Direction Inbound -Action Allow -Enabled True -Protocol tcp -LocalPort 80 -Group "MR PSWindowsUpdate" #-RemoteAddress 10.254.244.52
$ruleexists = Get-NetFirewallRule -DisplayName "Enable PSUpdate"
$ports = @("135", "445", "5985", "49660-49670")

foreach($rule in $ruleexists)
{
    Set-NetFirewallRule -DisplayName $rule.DisplayName -LocalPort $ports
}

#}

#}

#}

#Port: 49664 Service: LSASS.EXE
#Port: 49665 Service: WININIT.EXE
#Port: 49666 Service: SVCHOST.EXE
#Port: 49668 Service: SVCHOST.EXE
#Port: 49669 Service: LSASS.EXE
#Port: 49670 Service: SVCHOST.EXE