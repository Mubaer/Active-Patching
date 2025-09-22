#############################################################################################################
# Peter Ziegler 05/2025                                                                                     #
# MR Datentechnik                                                                                           #
# Dieses Script sucht bei MS im Web auf den angeführten URLS nach aktuelle  Buildnumbers der Windows Server #
# Betriebssysteme 2016, 2019, 2022 und 2025                                                                 #
#############################################################################################################

$months = @{
Januar = "January"
Februar = "February"
März = "March"
April = "April"
Mai = "May"
Juni = "June"
Juli = "July"
August = "August"
September = "September"
Oktober = "October"
November = "November"
Dezember = "December"
}

$request2016 = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/4000825" –UseBasicParsing
If ($request2016.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request2016.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*) \(OS Build 14393.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
        $CurrentServer2016Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2016"
            'OS Version'   = "14393"
            'OS build'     = $BuildNumber[0].Groups[6].Value
            'Released'     = "$($BuildNumber[0].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[0].Groups[2].Value)}).Name) $($BuildNumber[0].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[0].Groups[1].Value)"
            'KB'           = $BuildNumber[0].Groups[5].Value
            #'Info'     = $BuildNumber[0].Groups[7].Value                                
        }
        $LastServer2016Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2016"
            'OS Version'   = "14393"
            'OS build'     = $($BuildNumber[1].Groups[6].Value)
            'Released'     = "$($BuildNumber[1].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[1].Groups[2].Value)}).Name) $($BuildNumber[1].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[1].Groups[1].Value)"
            'KB'           = $BuildNumber[1].Groups[5].Value
            #'Info'     = $BuildNumber[1].Groups[7].Value                                
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
            'Released'     = "$($BuildNumber[0].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[0].Groups[2].Value)}).Name) $($BuildNumber[0].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[0].Groups[1].Value)"
            'KB'           = $BuildNumber[0].Groups[5].Value
            #'Info'     = $BuildNumber[0].Groups[7].Value                                
        }
        $LastServer2019Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2019"
            'OS Version'   = "17763"
            'OS build'     = $($BuildNumber[1].Groups[6].Value)
            'Released'     = "$($BuildNumber[1].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[1].Groups[2].Value)}).Name) $($BuildNumber[1].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[1].Groups[1].Value)"
            'KB'           = $BuildNumber[1].Groups[5].Value
            #'Info'     = $BuildNumber[1].Groups[7].Value                                
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
            'Released'     = "$($BuildNumber[0].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[0].Groups[2].Value)}).Name) $($BuildNumber[0].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[0].Groups[1].Value)"
            'KB'           = $BuildNumber[0].Groups[5].Value
            #'Info'     = $BuildNumber[0].Groups[7].Value                                
        }
        $LastServer2022Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2022"
            'OS Version'   = "20348"
            'OS build'     = $($BuildNumber[1].Groups[6].Value)
            'Released'     = "$($BuildNumber[1].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[1].Groups[2].Value)}).Name) $($BuildNumber[1].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[1].Groups[1].Value)"
            'KB'           = $BuildNumber[1].Groups[5].Value
            #'Info'     = $BuildNumber[1].Groups[7].Value                                
        }
    }
}

$request2025 = Invoke-WebRequest "https://support.microsoft.com/en-gb/help/5047442" –UseBasicParsing
If ($request2025.StatusCode -eq 200) {
    $BuildNumber = [regex]::Matches($request2025.Content, 'href="([a-z0-9-\/]*)">([a-zA-Z]*) ([0-9]{1,2}), ([0-9]{4}).*?(KB[0-9]*): Update for Windows Server 2025 \(OS Build 26100.([0-9]*)\)(?: ([a-zA-Z-]*)<\/a>)?')
    if ($BuildNumber.Count -gt 0) {
        $CurrentServer2025Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2025"
            'OS Version'   = "26100"
            'OS build'     = $BuildNumber[0].Groups[6].Value
            'Released'     = "$($BuildNumber[0].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[0].Groups[2].Value)}).Name) $($BuildNumber[0].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[0].Groups[1].Value)"
            'KB'           = $BuildNumber[0].Groups[5].Value
            #'Info'     = $BuildNumber[0].Groups[7].Value                                
        }
        $LastServer2025Raw = [PSCustomObject]@{
            'OS Name'      = "Windows Server 2025"
            'OS Version'   = "26100"
            'OS build'     = $($BuildNumber[1].Groups[6].Value)
            'Released'     = "$($BuildNumber[1].Groups[3].Value). $($months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[1].Groups[2].Value)}).Name) $($BuildNumber[1].Groups[4].Value)"
            'URL'          = "https://support.microsoft.com$($BuildNumber[1].Groups[1].Value)"
            'KB'           = $BuildNumber[1].Groups[5].Value
            #'Info'     = $BuildNumber[1].Groups[7].Value                                
        }
    }
}

#$LastServer2022Raw.Released = $months.GetEnumerator().Where({$_.Value -contains $($BuildNumber[1].Groups[2].Value)}).Name


$BuildNumberJson =
@([PSCustomObject]@{Last2016=$LastServer2016Raw},
  [PSCustomObject]@{Curr2016=$CurrentServer2016Raw},
  [PSCustomObject]@{Last2019=$LastServer2019Raw},
  [PSCustomObject]@{Curr2019=$CurrentServer2019Raw},
  [PSCustomObject]@{Last2022=$LastServer2022Raw},
  [PSCustomObject]@{Curr2022=$CurrentServer2022Raw},
  [PSCustomObject]@{Last2025=$LastServer2025Raw},
  [PSCustomObject]@{Curr2025=$CurrentServer2025Raw})

$BuildNumberJson | ConvertTo-Json -depth 100 | Out-File "C:\MR\buildnumbers.json"

