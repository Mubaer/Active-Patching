# Einfach auf dem WSUS-Server aufrufen.
# Parameter: Keine
# Ausgabe: Ergebnisse der einzelenen Patchaufgaben
# So können einfach die Results der Patchaufgaben aller assets
# abgefragt werden. Es wird der letzte Monat abgefragt
# Es werden die Zeitpunkte der letzten Reboots ausgegeben

Import-Module pswindowsupdate
Get-WsusServer -Name localhost -PortNumber 8530


$WSUSComputers = Get-WsusComputer # -NameIncludes dthhi-s-mrmgmt.dth-tiemann.local



ForEach ($WSUSComputer in $WSUSComputers){



Get-WUHistory -ComputerName $WSUSComputer.FullDomainName -MaxDate (Get-Date).AddDays(-30) -Last 100 | Select-Object Computername, Title, Date, Result

Get-WURebootStatus -ComputerName  $WSUSComputer.FullDomainName | Select-Object rebootrequired





            $Connection = Test-Connection $WSUSComputer.FullDomainName -Quiet -Count 2

            If(!$Connection) {
                Write-Warning "Computer: $WSUSComputer.FullDomainName appears to be offline!"
            } #end If

            Else {
                Get-WinEvent -ComputerName $WSUSComputer.FullDomainName -FilterHashtable @{logname = 'System'; id = 1074} -MaxEvents 3 |
                    ForEach-Object {
                        $EventData = New-Object PSObject | Select-Object Date, EventID, User, Action, Reason, ReasonCode, Comment, Computer, Message, Process
                        $EventData.Date = $_.TimeCreated
                        $EventData.User = $_.Properties[6].Value
                        $EventData.Process = $_.Properties[0].Value
                        $EventData.Action = $_.Properties[4].Value
                        $EventData.Reason = $_.Properties[2].Value
                        $EventData.ReasonCode = $_.Properties[3].Value
                        $EventData.Comment = $_.Properties[5].Value
                        $EventData.Computer = $WSUSComputer.FullDomainName
                        $EventData.EventID = $_.id
                        #$EventData.Message = $_.Message
                    
                        $EventData | Select-Object Date, Computer, EventID, Action, User, Reason #, Message

                    }
                } #end Else


}

