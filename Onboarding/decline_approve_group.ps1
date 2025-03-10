Import-Module poshwsus
Connect-PSWSUSServer -WsusServer localhost -Port 8530


$CSVData = Import-CSV -Path "C:\mr_managed_it\scripts\decline_approve.csv" | Group-Object -Property KB-Number  | Sort-Object -Property Name


ForEach($PSItem in $CSVData) {
        $PSItem
        $KBNumber = $PSItem.Name
        $Groups = $($PSItem.Group).Group
        "Aktuelle KB-Nummer: " + $KBNumber
        "Aktuelle Groups dafür: " + $Groups


if($Groups){
        foreach($Group in ($PSItem.Group).Group) {

        write-host $KBNumber " wird für " $Group " aufgehoben."
        
        $WSUSGroup = Get-PSWSUSGroup -name $Group
        
        Get-PSWSUSUpdate -Update  $KBNumber | Approve-PSWSUSUpdate -Group $WSUSGroup -Action NotApproved
        }
        }else{
        write-host $KBNumber " wird declined."
        Get-PSWSUSUpdate -Update  $KBNumber | Deny-PSWSUSUpdate
        
        }

        }