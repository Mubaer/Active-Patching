$web = Invoke-WebRequest  "https://www.catalog.update.microsoft.com/Search.aspx?q=KB5070884"

$web.content | out-file "C:\mr_managed_it\temp\out.txt"



$test = [string]$(Get-Content -Path "C:\mr_managed_it\temp\out.txt" | Select-String -Pattern "goToDetails" | Select-String -Pattern  "onclick")


$test.substring(31, 34)