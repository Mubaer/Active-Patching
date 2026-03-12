# Check if running as Administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running as Administrator. Relaunching with elevated privileges..."
    
    # Build argument list with script path and parameters
    $argsList = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    
    # Start new elevated process
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argsList
    exit
}

# Script continues here with elevated privileges
Write-Host "Running with elevated privileges!"
# Your admin-level commands go here