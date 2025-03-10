Remove-Item 'C:\mr_managed_it\regsettings.reg' -ErrorAction SilentlyContinue
reg export 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' C:\mr_managed_it\regsettings.reg