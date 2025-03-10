Import-Module pswindowsupdate

while($true){

$filePath   = "C:\mr_managed_it\scripts\reboot_hosts.csv"
$logpath    = "C:\mr_managed_it\logs\reboot.log"
$result = -1
$rebootresult = 0

# Solange nicht alle auf Reboot Pending stehen machen wir gar nichts. Wir warten und checken.

while($result -ne 0){
    $result = 0
    $today      = (Get-Date).DayOfWeek.value__  + 1
    $WF = ""
    switch ($today) {
    
    4 { $WF = "1" } #Heute ist Mittwoch   --> WF1 muss rebootet werden
    5 { $WF = "2" } #Heute ist Donnerstag --> WF2 muss rebootet werden
    7 { $WF = "3" } #Heute ist Samstag    --> WF3 muss rebootet werden
    1 { $WF = "4" } #Heute ist Sonntag    --> WF4 muss rebootet werden
    
    }
    
    # Importiere nur die Assets, die heute dran sind
    $datacheck  = Import-Csv $filePath  | Where-Object WF -Like $WF
    $datareboot = Import-Csv $filePath  | Where-Object WF -Like $WF | Group-Object -Property PRIO | Sort-Object -Property Name

    if ($datacheck){
    
    $datacheck  | ForEach-Object {

    $server = $PSItem.ComputerName
    
    "$(get-date) $server"  | out-file -filepath $logpath -append

    $connect = tnc -ComputerName $server
    if ($connect.PingSucceeded -ne "True"){
        $result = $result + 1
        "   (WARN) Nicht erreichbar" | out-file -filepath $logpath -append
    }else{"   (INFO) Erreichbar" | out-file -filepath $logpath -append

    $rebootstatus  = $(Get-WURebootStatus -ComputerName $server -Silent)
    if ($rebootstatus -like "False"){
        $result =  $result + 2
        "   (WARN) Muss NICHT rebootet werden" | out-file -filepath $logpath -append
    }else{"   (INFO) Muss rebootet werden" | out-file -filepath $logpath -append}

    $scheduledtask = $(Get-ScheduledTask -CimSession $server  | Where-Object TaskName -eq PSWindowsUpdate).State
    if ($scheduledtask -like "Running"){
        $result = $result + 4
        "   (WARN) Job läuft noch" | out-file -filepath $logpath -append
    }else{"   (INFO) Kein Job aktiv" | out-file -filepath $logpath -append}
    
    $dayofreboot   = $(Invoke-Command -ComputerName $server {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'  -Name ScheduledInstallDay -ErrorAction SilentlyContinue}).ScheduledInstallDay
    if ($dayofreboot -ne $today){
        $result = $result + 8
        "   (WARN) Heute ist der falsche Tag" | out-file -filepath $logpath -append
    }else{"   (INFO) VM ist heute dran" | out-file -filepath $logpath -append}
    }
    $result
    } #End ForEach
    
    "$(get-date) Das Ergebnis des Rebootchecks ist aktuell: " + $result | out-file -filepath $logpath -append
    
    if($result -ne 0){
    "   (WARN) Es sind noch nicht alle Assets im Status 'Reboot required'. Naechster Check " + $(get-date).AddMinutes(5) | out-file -filepath $logpath -append
  
   
   }
   }else{
   "$(get-date) Keine Assets fuer den heutigen Tag im Import-File gefunden." | out-file -filepath $logpath -append
   $result = 999} #Keine Assets fuer den heutigen Tag in der Input-Datei gefunden
     Start-Sleep 300
   } # End While

    # Jetzt sind alle bereit. Wir rebooten jede Gruppe für sich nacheinander

    "   (INFO) Alle Assets sind im Zustand 'Reboot required'. Die Neustart-Sequenz beginnt." | out-file -filepath $logpath -append
    ForEach($PSItem in $datareboot) {
        $phase = $PSItem.Name
        "$(get-date) Aktuelle Priorität: $phase, $($PSItem.Count) Assets werden rebootet. " | out-file -filepath $logpath -append
        $restartgrp = ""
        foreach ($server in (($PSItem.Group).COMPUTERNAME))
        {$restartgrp = $restartgrp + $server + ", "}
    
        $restartgrp = [string]$restartgrp -replace ".{2}$"
        "$(get-date) $restartgrp" | out-file -filepath $logpath -append
        $restartcmd = "Restart-Computer -ComputerName " + $restartgrp + " -Wait -For PowerShell -Delay 2 -Force -Timeout 1800"
        if($restartgrp){Invoke-Expression $restartcmd}

        # Nachdem eine Prio-Gruppe zum Neustart aufgefordert wurde warten wir max. 1800 Sekunden, bis wir checken, ob alles ok ist.
        # Wir müssen leider aktiv checken, da das cmdlet "Restart-Computer keinen Rückgabewert liefert. D.h. wenn der Timeout erreicht wurde wird weitergemacht als ob nichts schief gegangen wäre.
    
        foreach ($server in (($PSItem.Group).COMPUTERNAME)){
        $rebootresult = 0
        $connect = tnc -ComputerName $server
        if($connect.PingSucceeded -ne "True"){
            $rebootresult = 1
        }
        $uptime = $(Invoke-Command -ComputerName $server -ScriptBlock {(Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootupTime}).totalminutes
        if($uptime -gt 10){
            $rebootresult = 1
        }
        
        } # End ForEach
        if($rebootresult -eq 1){
            "$(get-date) (ERR) Irgendetwas hat nicht geklappt. Wir steigen aus und machen mit dem Anfang weiter. " | out-file -filepath $logpath -append
            # Falls wir hier ankommen wurden die Assets zwar gepatcht aber beim Reboot ist irgendwas in einer Prio-Gruppe hängen geblieben. Ein Asset hat nicht mehr gestartet oder ungewöhnlich lange gebraucht
            # Falls das so ist, springen wir zum Anfang und prüfen wieder kontinuierlich, ob irgendwas rebootet werden muss.
            # Sobald von einem Bearbeiter der Fehler behoben wurde kann der Mechanismus wieder korrekt arbeiten. Leider kann er nicht da weitermachen wo er aufgehört hat.
            Break
        }else{
        "$(get-date) (INFO) Alle Server der Priorität " + $phase + " sind erfolgreich neu gestartet." | out-file -filepath $logpath -append
        }
        } # End ForEach

        } # End While