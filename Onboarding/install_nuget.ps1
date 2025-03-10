
#$NuGet       = ""
#$PSGallery   = ""

#$NuGet = Invoke-Command -ComputerName $FDN -ScriptBlock {Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue}

#if(! $NuGet){
#Write-Host "Installiere NuGet"
#Invoke-Command -ComputerName $FDN -ScriptBlock {Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force}
#}

#$PSGallery = Invoke-Command -ComputerName $FDN -ScriptBlock {Get-PSRepository -Name 'PSGallery'}

#if($PSGallery.InstallationPolicy -ne "Trusted"){
#Write-Host "Setze Trusted"
#Invoke-Command -ComputerName $FDN -ScriptBlock {Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted}
#}

#Write-Host "Installiere PSWindowsUpdate"
#Invoke-Command -ComputerName $FDN -ScriptBlock {Install-module PSWindowsUpdate -force -SkipPublisherCheck -AllowClobber}
