$assemblyPath = "C:\Program Files\Update Services\Api\Microsoft.UpdateServices.Administration.dll";
Add-Type -Path $assemblyPath;

$wsusServer = "localhost";
$csvResult = "C:\mr_managed_it\WSUSSummary.csv";
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($wsusServer, $false, 8530);

$computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope;
$updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope;
$updateSummaries = $wsus.GetSummariesPerComputerTarget($updatescope, $computerscope);

$results = New-Object System.Collections.ArrayList;

foreach ($summary in $updateSummaries) {
    $computerTarget = $wsus.GetComputerTarget([guid]$summary.ComputerTargetId);
    $total = ($summary.NotApplicableCount + $summary.InstalledCount + $summary.NotInstalledCount + $summary.FailedCount);

    $entry = @{
        ComputerTarget                         = $computerTarget.FullDomainName
        NeededCount                            = ($summary.DownloadedCount + $summary.NotInstalledCount)
        DownloadedCount                        = $summary.DownloadedCount
        NotInstalledCount                      = $summary.NotInstalledCount
        InstalledCount                         = $summary.InstalledCount
        FailedCount                            = $summary.FailedCount
        InstalledOrNotApplicablePercentage     = if ($total -ne 0){([Math]::Round((($summary.NotApplicableCount + $summary.InstalledCount) / $total) * 100, 2)).tostring() + '%'}else{[string]0 + '%'}
    }

    $results.Add($entry) > $null
}

$resultsArray = $results.ToArray();
$resultsArray;

foreach ($test in $resultsArray){$test;" "}