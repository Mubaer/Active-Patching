$version = "1.0.2"
$exitcode = 0
$warning = 0
$Port = 8530
$wsusserver = "localhost"
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($wsusserver,$False,$Port)
$CompSc = new-object Microsoft.UpdateServices.Administration.ComputerTargetScope
$updateScope = new-object Microsoft.UpdateServices.Administration.UpdateScope; 
$updateScope.UpdateApprovalActions = [Microsoft.UpdateServices.Administration.UpdateApprovalActions]::All

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
            'Title'        = ""
        }
    }
}

$kb = $CurrentServer2016Raw.KB
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState

          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $exitcode = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1}          
          
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
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
            'Title'        = ""
        }
    }
}
 
   $kb = $CurrentServer2019Raw.KB
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState
          
          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $exitcode = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1}          
          
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
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
            'Title'        = ""
        }
    }
}

        $kb = $CurrentServer2022Raw.KB
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState
          
          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $exitcode = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1}          
          
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
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
            'Title'        = ""
        }
    }
}
             $kb = $CurrentServer2025Raw.KB
   $updates = $wsus.GetUpdates($updateScope) | Where-Object{$_.Title -match $kb} #Getting every update where the title matches the $kbnumber
       ForEach($update in $updates){ #Loop against the list of updates I stored in $updates in the previous step
          $update.GetUpdateInstallationInfoPerComputerTarget($CompSc) |  ForEach-Object {
          $Comp = $wsus.GetComputerTarget($_.ComputerTargetId)# using #Computer object ID to retrieve the computer object properties (Name, #IP address)
          $info = "" | Select-Object ICStatus, InstallationStatus, UpdateTitle, Computername, OS ,IpAddress,  UpdateApprovalAction
          $info.InstallationStatus = $_.UpdateInstallationState
          
          if($info.InstallationStatus -like "Installed"){
          $info.InstallationStatus = "Installed"
          $info.ICStatus = "(OK)"
          
          }elseif($info.InstallationStatus -like "Failed"){
          $info.InstallationStatus = "Failed"
          $info.ICStatus = "(CRITICAL)"
          $exitcode = 2
          
          }elseif($info.InstallationStatus -like "InstalledPendingReboot"){
          $info.InstallationStatus = "     PendingReboot" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1          
          
          }elseif($info.InstallationStatus -like "NotApplicable"){
          $info.InstallationStatus = "     NotApplicable" + "      `t"
          $info.UpdateTitle = "`t" + $info.UpdateTitle
          $info.ICStatus = "(WARNING)"
          $warning = 1}          
          
          $info.UpdateTitle = $kb
          #$info.LegacyName = $update.LegacyName
          #$info.SecurityBulletins = ($update.SecurityBulletins -join ';')
          $info.Computername = "`t" + $Comp.FullDomainName
          $info.OS = "`t" + $Comp.OSDescription
          $info.IpAddress = "`t" + $Comp.IPAddress
          $info.UpdateApprovalAction = $_.UpdateApprovalAction
          if ($info.OS -match "Windows Server 2025"){
          $report+=$info # Storing the information into the $report variable 
          }
        }
     }

$CurrentServer2016Raw.Title = $($wsus.SearchUpdates($CurrentServer2016Raw.KB)).title
$CurrentServer2019Raw.Title = $($wsus.SearchUpdates($CurrentServer2019Raw.KB)).title
$CurrentServer2022Raw.Title = $($wsus.SearchUpdates($CurrentServer2022Raw.KB)).title
$CurrentServer2025Raw.Title = $($wsus.SearchUpdates($CurrentServer2025Raw.KB)).title

if($warning -eq 0 -and $exitcode -eq 0){
$result = "(OK) Overall Status"
}

if ($warning -eq 1 -and $exitcode -eq 0){
$result = "(WARNING) Overall Status"
$exitcode = 1
}

if($exitcode -eq 2){
$result = "(CRITICAL) Overall Status"
}


Write-host $result

$report | ft | Out-String -Width 9999 -Stream

Write-host "OS Name :" $CurrentServer2016Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2016Raw.'OS Version'"."$CurrentServer2016Raw.'OS build'
Write-host "KB      :" $CurrentServer2016Raw.KB
Write-host "Title   :" $CurrentServer2016Raw.Title
Write-host
Write-host "OS Name :" $CurrentServer2019Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2019Raw.'OS Version'"."$CurrentServer2019Raw.'OS build'
Write-host "KB      :" $CurrentServer2019Raw.KB
Write-host "Title   :" $CurrentServer2019Raw.Title
Write-host
Write-host "OS Name :" $CurrentServer2022Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2022Raw.'OS Version'"."$CurrentServer2022Raw.'OS build'
Write-host "KB      :" $CurrentServer2022Raw.KB
Write-host "Title   :" $CurrentServer2022Raw.Title
Write-host
Write-host "OS Name :" $CurrentServer2025Raw.'OS Name'
Write-host "OS Build:" $CurrentServer2025Raw.'OS Version'"."$CurrentServer2025Raw.'OS build'
Write-host "KB      :" $CurrentServer2025Raw.KB
Write-host "Title   :" $CurrentServer2025Raw.Title
Write-host

  
Write-host "Check-version: " $version

$LASTEXITCODE = $ExitCode
exit($exitcode)