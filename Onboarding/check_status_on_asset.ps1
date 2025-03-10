$WindowsUpdateInfo = $(New-Object -ComObject Microsoft.Update.AutoUpdate)
$WindowsUpdateInfo.Results.LastSearchSuccessDate

###################################################################################################

$server = "localhost";

<# Get Windows Update Info #>
$out += Invoke-Command -ComputerName $server -ScriptBlock {

    $updateInfoMsg = "Windows Update Status: `n";
    
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session;
    $UpdateSearcher = $UpdateSession.CreateupdateSearcher();
    $Updates = @($UpdateSearcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'").Updates);
    $Found = ($Updates | Select-Object -Expand Title);
    
    If ($Found -eq $Null) {
        $updateInfoMsg += "Up to date";
    } Else {
        $Found = ($Updates | Select-Object -Expand Title) -Join "`n";
        $updateInfoMsg += "Updates available:`n";
        $updateInfoMsg += $Found;
    }

    Return $updateInfoMsg;
}
$out;

######################################################################################################

$updateInfoMsg = "Windows Update Status: `n";

$UpdateSession = New-Object -ComObject Microsoft.Update.Session;
$UpdateSearcher = $UpdateSession.CreateupdateSearcher();
$Updates = @($UpdateSearcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'").Updates);
$Found = ($Updates | Select-Object -Expand Title);

If ($Found -eq $Null) {
    $updateInfoMsg += "Up to date";
} Else {
    $Found = ($Updates | Select-Object -Expand Title) -Join "`n";
    $updateInfoMsg += "Updates available:`n";
    $updateInfoMsg += $Found;
}

$updateInfoMsg;

