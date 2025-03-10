$wsus = Get-WSUSServer
$wsus.CreateComputerTargetGroup("MR_Server_PR")


Get-WsusProduct | where-Object {
    $_.Product.Title -in (
    'Windows - Server, version 21H2 and later, Upgrade & Servicing Drivers',
    'Windows - Server, version 21H2 and later, Servicing Drivers',
    'Windows - Server, version 24H2 and later, Upgrade & Servicing Drivers',
    'Microsoft Server Operating system-22H2',
    'Microsoft Server Operating system-23H2',
    'Microsoft Server Operating system-24H2'
    )
} | Set-WsusProduct

Get-WsusProduct | where-Object {$_.Product.Title -match "Exchange Server 2013"} | Set-WsusProduct -Disable
Get-WsusProduct | where-Object {$_.Product.Title -match "SQL Server 2008"}      | Set-WsusProduct -Disable
Get-WsusProduct | where-Object {$_.Product.Title -match "Windows Server 2012"}  | Set-WsusProduct -Disable