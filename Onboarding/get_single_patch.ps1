$Port = 8530
$wsusserver = "localhost"
$report = @()
$kb = "5037765"
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($wsusserver,$False,$Port)
$CompSc = new-object Microsoft.UpdateServices.Administration.ComputerTargetScope
$updateScope = new-object Microsoft.UpdateServices.Administration.UpdateScope; 
$updateScope.UpdateApprovalActions = [Microsoft.UpdateServices.Administration.UpdateApprovalActions]::All
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) | Where-Object{$_.UpdateApprovalAction -eq "NotApproved"} |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object UpdateTitle, Computername, OS ,IpAddress, UpdateInstallationStatus, UpdateApprovalAction
          #$info.UpdateTitle = $update.Title
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = $Comp.FullDomainName
          $info.OS = $Comp.OSDescription
          $info.IpAddress = $Comp.IPAddress
          $info.UpdateInstallationStatus = $_.UpdateInstallationState
          $info.UpdateApprovalAction = $_.UpdateApprovalAction
          $report+=$info # Storing the information into the $report variable 
        }
     }
  
$report | Format-Table #|  Export-Csv -Path c:\temp\rep_wsus.csv -Append -NoTypeInformation

