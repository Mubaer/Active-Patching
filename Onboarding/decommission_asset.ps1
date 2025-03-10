######################################################################################################
# Script zum Entfernen von Clients aus der WSUS-Datenbank.                                           #
# evtl. wenn der Kunde oder wir assets aus der zu patchenden Umgebung entfernt haben.                #
#                                                                                                    #
# Die Datei dec_hosts.txt listet in einfacher Liste de betreffenden Hosts auf. Ein Host pro Zeile.   #
#                                                                                                    #
# Peter Ziegler 06/2024                                                                              #
######################################################################################################


$wsus = Get-WsusServer -Name localhost -PortNumber 8530

$clients = Get-Content -Path "C:\mr_managed_it\Scripts\dec_hosts.txt"

Foreach($client in $clients){
$client_to_delete = $wsus.SearchComputerTargets($client)
$client_to_delete.delete()

}