Get-WsusProduct -TitleIncludes "2012 R2" | Set-WsusProduct -Disable
Get-WsusProduct -TitleIncludes "SQL Server 2008" | Set-WsusProduct -Disable
Get-WsusProduct -TitleIncludes "Exchange Server 2013" | Set-WsusProduct -Disable
Get-WsusProduct | where-Object {
    $_.Product.Title -in (
    'Windows - Server, version 21H2 and later, Servicing Drivers',
    'Windows - Server, version 21H2 and later, Upgrade & Servicing Drivers',
    'Windows - Server, version 24H2 and later, Upgrade & Servicing Drivers',
    'Microsoft Server Operating system-23H2',
    'Microsoft Server Operating system-24H2'
    )
} | Set-WsusProduct