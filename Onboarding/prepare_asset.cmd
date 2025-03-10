net stop wuauserv
net stop bits
net stop dosvc
ren C:\windows\softwaredistribution
net start dosvc
net start bits
net start wuauserv