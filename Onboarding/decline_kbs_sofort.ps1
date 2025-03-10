########################################################################################
#                                                                                      #
# Script zum sofortigen Entzug von Freigaben einzelner Patches auf Kunden-WSUS-Servern #                      
#                                                                                      #
# Peter Ziegler                                                                        #
#                                                                                      #
#                                                                                      #
#                                                                                      #
########################################################################################

$Transscript_path = "C:\mr_managed_it\Logs\decline_kbs_sofort." + (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss") + ".txt"
Start-Transcript -Path $Transscript_path
$version = "2.0.1"
Write-host "Script-Version: " + $version 
Import-Module poshwsus
Import-Module pswindowsupdate
Connect-PSWSUSServer -WsusServer localhost -Port 8530

Write-Host "Decline unwanted KBs and unapprove unwanted KBs from specific groups ..."
$CSVData = Import-CSV -Path "C:\mr_managed_it\scripts\kb_decline_approve.csv" | Group-Object -Property KB-Number  | Sort-Object -Property Name


ForEach($PSItem in $CSVData) {
        $PSItem
        $KBNumber = $PSItem.Name
        $Groups = $($PSItem.Group).Group
        "Aktuelle KB-Nummer: " + $KBNumber
        "Aktuelle Groups dafuer: " + $Groups


if($Groups){
        foreach($Group in ($PSItem.Group).Group) {

        write-host $KBNumber " wird fuer " $Group " aufgehoben."
        
        $WSUSGroup = Get-PSWSUSGroup -name $Group
        
        Get-PSWSUSUpdate -Update  $KBNumber | Approve-PSWSUSUpdate -Group $WSUSGroup -Action NotApproved
        }
        }else{
        write-host $KBNumber " wird declined."
        Get-PSWSUSUpdate -Update  $KBNumber | Deny-PSWSUSUpdate
        
        }

        }

Stop-Transcript