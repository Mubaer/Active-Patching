$Port = 8530
$wsusserver = "localhost"
$report = @()

$request2016 = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/4000825" –UseBasicParsing
If ($request2016.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request2016.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 14393.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
        $CurrentServer2016Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2016"
            'OS Version'   = "14393"
            'OS build'     = $BuildNumber[0].Groups[6].Value
            'KB'           = $BuildNumber[0].Groups[5].Value
        }
    }
}

$kb = $CurrentServer2016Raw.KB
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($wsusserver,$False,$Port)
$CompSc = new-object Microsoft.UpdateServices.Administration.ComputerTargetScope
$updateScope = new-object Microsoft.UpdateServices.Administration.UpdateScope; 
$updateScope.UpdateApprovalActions = [Microsoft.UpdateServices.Administration.UpdateApprovalActions]::All
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
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
          if ($info.OS -match "Windows Server 2016"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }
 $request2019 = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/4464619" –UseBasicParsing
If ($request2019.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request2019.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 17763.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
        $CurrentServer2019Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2019"
            'OS Version'   = "17763"
            'OS build'     = $BuildNumber[0].Groups[6].Value
            'KB'           = $BuildNumber[0].Groups[5].Value
        }
    }
}
 
   $kb = $CurrentServer2019Raw.KB
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
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
          if ($info.OS -match "Windows Server 2019"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }

     $request2022 = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/5020032" –UseBasicParsing
If ($request2022.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request2022.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 20348.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
        $CurrentServer2022Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2022"
            'OS Version'   = "20348"
            'OS build'     = $BuildNumber[0].Groups[6].Value
            'KB'           = $BuildNumber[0].Groups[5].Value
        }
    }
}

        $kb = $CurrentServer2022Raw.KB
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
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
          if ($info.OS -match "Windows Server 2022"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }
 
     $request2025 = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/5047442" –UseBasicParsing
If ($request2025.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request2025.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 26100.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
        $CurrentServer2025Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2025"
            'OS Version'   = "26100"
            'OS build'     = $BuildNumber[0].Groups[6].Value
            'KB'           = $BuildNumber[0].Groups[5].Value
        }
    }
}
             $kb = $CurrentServer2025Raw.KB
   #$kb = "5075897"
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
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
          if ($info.OS -match "Windows Server 2025"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }
$CurrentServer2016Raw
$CurrentServer2019Raw
$CurrentServer2022Raw
$CurrentServer2025Raw
  
$report | Format-Table #|  Export-Csv -Path c:\temp\rep_wsus.csv -Append -NoTypeInformation

