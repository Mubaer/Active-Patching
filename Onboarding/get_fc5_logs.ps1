############################################################################################################################################
#                                                                                                                                          #
#  Dieses Script holt von allen Windows-Server-Assets die FC5-Logdateien                                                                   #
#  Peter Ziegler, November 2025                                                                                                            #
#  MR Datentechnik                                                                                                                         #
#                                                                                                                                          #
#                                                                                                                                          #
#                                                                                                                                          #
############################################################################################################################################
Start-Transcript -Path "C:\mr_managed_it\logs\get_fc5.log" -IncludeInvocationHeader
$version = "1.0.2" # format filenames to id_name.log

# Teil 1: Hole alle Dateien von Assets, die Mitglied der gleichen AD-Domain sind wie der Mgmnt-Server (localhost)

$vms = Get-Content -Path "C:\mr_managed_it\fc_ad_hosts.txt"

foreach ($vm in $vms){

$id = $vm.split(",")[0]
$name =  $vm.split(",")[1]
$Sourcepath   = "\\$name\C" + "$" + "\mr_managed_it\fc_result.log"
$Destpath = "C:\mr_managed_it\fc_logs\" + $id + "_" + $name + ".log"
Copy-Item -Path $SourcePath -destination $DestPath  -ErrorAction SilentlyContinue
}

# Teil 2: Hole alle Dateien von Assets, die nicht Mitglied einer AD-Domain sind

$vms = Get-Content -Path "C:\mr_managed_it\fc_mbs_hosts.txt" -ErrorAction SilentlyContinue

foreach ($vm in $vms){
$id = $vm.split(",")[0]
$name =  $vm.split(",")[1]
$vm = [string]$name
Set-Item wsman:\localhost\client\TrustedHosts -Value $vm -Force -Concatenate -ErrorAction SilentlyContinue
$s_creds = Get-StoredCredential -Target $VM
$securePassword = $s_creds.Password
$user = $s_creds.UserName 
if ($s_creds){$credential = New-Object System.Management.Automation.PsCredential($user,$securePassword)}

$Session = New-PSSession -ComputerName  $vm -Credential $credential
$Sourcepath   = "C:\mr_managed_it\fc_result.log"
$Destpath = "C:\mr_managed_it\fc_logs\" + $id + "_" + $name + ".log"

Copy-Item "C:\mr_managed_it\fc_result.log" -Destination $Destpath -FromSession $Session

remove-pssession -Session $Session
}


# Teil 3: Hole alle Dateien von Assets, die Mitglied einer anderen AD-Domain sind

$domainuser = Get-Content -Path "C:\mr_managed_it\Scripts\aduser.txt"
$VMs = Get-Content -Path "C:\mr_managed_it\fc_nonad_hosts.txt" -ErrorAction SilentlyContinue
foreach ($vm in $vms){
$id = $vm.split(",")[0]
$name =  $vm.split(",")[1]
$vm = [string]$name
Set-Item wsman:\localhost\client\TrustedHosts -Value $vm -Force -Concatenate -ErrorAction SilentlyContinue
$s_creds = Get-StoredCredential -Target $domainuser
$securePassword = $s_creds.Password
$user = $s_creds.UserName 
if ($s_creds){$credential = New-Object System.Management.Automation.PsCredential($user,$securePassword)}

$Session = New-PSSession -ComputerName  $vm -Credential $credential
$Destpath = "C:\mr_managed_it\fc_logs\" + $id + "_" + $name + ".log"

Copy-Item "C:\mr_managed_it\fc_result.log" -Destination $Destpath -FromSession $Session

remove-pssession -Session $Session
}

Stop-Transcript




