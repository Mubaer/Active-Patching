######################################################################################################
# Script zum Entfernen von Clients aus der WSUS-Datenbank.                                           #
# evtl. wenn der Kunde oder wir assets aus der zu patchenden Umgebung entfernt haben.                #
#                                                                                                    #
# Peter Ziegler 08/2025                                                                              #
######################################################################################################
# version 0.9.0
$ErrorActionPreference = "Silentlycontinue"
$wsus = Get-WsusServer -Name localhost -PortNumber 8530
$computernames = Get-Content -Path "C:\temp\vms.txt"
$softwareName = "Icinga 2"

foreach ($computername in $computernames){
$computername
$software = Get-WmiObject Win32_Product -ComputerName $computername | Where-Object { $_.Name -eq $softwareName }

# Loeschen des Icinga2-Agents
if ($software) {
    $software.Uninstall()
} else {
    Write-Host "$softwareName is not installed on $computername"
}

# Aufraeumen
Remove-Item "\\$computername\c$\mr_managed_it" -Recurse -Force
Remove-Item "\\$computername\c$\mrdaten" -Recurse -Force
Remove-Item "\\$computername\c$\MR" -Recurse -Force
Remove-Item "\\$computername\c$\ProgramData\Icinga2" -Recurse -Force
Remove-Item "\\$computername\c$\Program Files\Icinga2" -Recurse -Force
Remove-Item "\\$computername\c$\Program Files\WindowsPowershell\Modules\icinga-powershell-framework" -Recurse -Force
Remove-Item "\\$computername\c$\Program Files\WindowsPowershell\Modules\icinga-powershell-plugins" -Recurse -Force
Remove-Item "\\$computername\c$\Program Files\WindowsPowershell\Modules\PSWindowsUpdate" -Recurse -Force

# Registry-Werte fuer Patching zuruecksetzen
Invoke-Command -ComputerName $ComputerName -ScriptBlock {
    $KeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\"
    $KeyPathAU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    Remove-Item -Path $KeyPath -Recurse -Force
    New-Item -Path $KeyPath -Force
    New-Item -Path $KeyPathAU -Force
    New-ItemProperty -Path $KeyPathAU -PropertyType 'DWord' -Name 'NoAutoUpdate' -Value 1
    Unregister-ScheduledTask -TaskName "MR Flightcheck" -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "Enable PSUpdate" -ErrorAction SilentlyContinue
}

# Loeschen des Assets aus der WSUS-Datenbank
$client_to_delete = $wsus.SearchComputerTargets($ComputerName)
$client_to_delete.delete()

}