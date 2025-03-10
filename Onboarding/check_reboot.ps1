Import-Module pswindowsupdate

$logfile = "C:\mr_managed_it\logs\reboot.log"
       
While($true)
    {
        $servers = Get-WsusComputer -IncludedInstallationStates InstalledPendingReboot 
        $today = (Get-Date).DayOfWeek.value__  + 1

        foreach ($server in $servers){
        
        $server = $server.FullDomainName
        $rebootstatus = ''
        $rebootrequired = 0
        $scheduledtask = ''
        $scheduledtaskstate = 0
        $readykeyexists = ''
        $rebootkeyexists = ''
        $uptime = ''
        $dayofreboot = ''
        $correctday = ''
        

        # Muss der Server überhaupt rebootet werden?
        $rebootstatus = $(Get-WURebootStatus -ComputerName $server -Silent)
        if($rebootstatus -eq "True"){
        $rebootrequired = 1
        }

        # Läuft aktuell ein Patchjob?
        $scheduledtask = $(Get-ScheduledTask -CimSession $server  | Where-Object TaskName -eq PSWindowsUpdate ).State
        if ($scheduledtask -notlike "Running"){
        $scheduledtaskstate = 1
        }

        # Wurde der Registrykey schon gesetzt?
        $readykeyexists = $(Invoke-Command -ComputerName $server -ScriptBlock {(Get-itemproperty -ea SilentlyContinue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -name SystemReadyForRebootByMR)}).SystemReadyForRebootByMR

        # Rebootet der Server aktuell?
        $rebootkeyexists = $(Invoke-Command -ComputerName $server -ScriptBlock {(Get-itemproperty -ea SilentlyContinue -path "HKLM:\" -name SystemRebootByMR)}).SystemRebootByMR

        # Ist der Server schon länger als 24h up?
        $uptime = $(Invoke-Command -ComputerName $server -ScriptBlock {(Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootupTime}).totalminutes

        # Ist heute der richtige Tag?
        $dayofreboot = $(Invoke-Command -ComputerName $server {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'  -Name ScheduledInstallDay -ErrorAction SilentlyContinue}).ScheduledInstallDay
        if($dayofreboot -eq $today){
        $correctday = 1
        }

        # Falls folgende Bedingungen erfüllt sind, wird das Flag in der Registry gesetzt, das Ansible signalisert, dass der Server rebootet werden soll:
        # 1. es muss rebootet werden, da vorher ein Patchlauf stattgefunden hat
        # 2. es läuft aktuell kein Patchlauf, dh. es ist sicher, zu rebooten
        # 3. der Key wurde noch nicht gesetzt.
        # 4. der Server rebootet gerade nicht bereits
        # 5. der letzte Reboot ist schon mindestens 24 Stunden her
        # 6. ist heute der richtige Tag


        if($rebootrequired -eq "1" -and $scheduledtaskstate -eq "1" -and -not $readykeyexists -eq "1" -and -not $rebootkeyexists -eq "1" -and $uptime -gt "1440" -and $correctday -eq "1"){
        
        "$server müssten wir rebooten" | Out-File $logfile -Append
        #Invoke-Command -ComputerName $server -ScriptBlock {New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "SystemReadyForRebootByMR" -Value "1" -PropertyType DWord}
        
        }else{
        
        "$server muss nicht rebootet werden" | Out-File $logfile -Append
        }

        }
        Start-Sleep 60
    }