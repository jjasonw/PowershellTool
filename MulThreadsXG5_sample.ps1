# Note: you may refer to MulThreadsXG5_readme.md and get familiarized with the scrip in non-production environment prior to any operation on production environment.
# Configuration Section (modify as needed)
$url = 'https://<EnterpriseServerIP>/LN.WebServices/12.0/XGServices.svc/Search'
$soapAction = "https://bridgerinsight.lexisnexis.com/BridgerInsight.Web.Services.Interfaces.12.0/ISearch/Search"

$headers = @{
    "Content-Type" = "text/xml;charset=utf-8"
    "SOAPAction"   = $soapAction
    "Cookie"       = "_culture=en"
}

# Initial warm-up SOAP request body
$xmlBodyInitial = @"
<?xml version='1.0' encoding='UTF-8'?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:brid="https://bridgerinsight.lexisnexis.com/BridgerInsight.Web.Services.Interfaces.12.0">
   <soapenv:Header/>
   <soapenv:Body>
      <brid:Search>
       <brid:context>
           <brid:ClientID></brid:ClientID>          
            <brid:Password></brid:Password>
            <brid:UserID></brid:UserID>
            <brid:ClientReference></brid:ClientReference>
         </brid:context>

         <brid:config>
            <brid:AssignResultTo>
               <brid:Division>Default division</brid:Division>
               <brid:EmailNotification>false</brid:EmailNotification>

               <brid:RolesOrUsers>
                  <brid:string></brid:string>
               </brid:RolesOrUsers>

               <brid:Type>Role</brid:Type>
            </brid:AssignResultTo>

            <brid:PredefinedSearchName>PDS</brid:PredefinedSearchName>
            <brid:WriteResultsToDatabase>false</brid:WriteResultsToDatabase>
         </brid:config>

         <brid:input>
             <brid:Records>
               <brid:InputRecord>
                   <brid:RecordID>2323</brid:RecordID>
                  <brid:Text>
                     <brid:Text>bin Laden</brid:Text>
                  </brid:Text>
               </brid:InputRecord>
            </brid:Records>
         </brid:input>

      </brid:Search>
   </soapenv:Body>
</soapenv:Envelope>
"@

# Test message SOAP request body
$xmlBody = @"
<?xml version='1.0' encoding='UTF-8'?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:brid="https://bridgerinsight.lexisnexis.com/BridgerInsight.Web.Services.Interfaces.12.0">
   <soapenv:Header/>
   <soapenv:Body>
      <brid:Search>

       <brid:context>
           <brid:ClientID></brid:ClientID>          
            <brid:Password></brid:Password>
            <brid:UserID></brid:UserID>
            <brid:ClientReference></brid:ClientReference>
         </brid:context>

         <brid:config>
            <brid:AssignResultTo>
               <brid:Division>Default division</brid:Division>
               <brid:EmailNotification>false</brid:EmailNotification>

               <brid:RolesOrUsers>
                  <brid:string></brid:string>
               </brid:RolesOrUsers>

               <brid:Type>Role</brid:Type>
            </brid:AssignResultTo>

            <brid:PredefinedSearchName>PDS</brid:PredefinedSearchName>
            <brid:WriteResultsToDatabase>false</brid:WriteResultsToDatabase>
         </brid:config>

         <brid:input>
             <brid:Records>
               <brid:InputRecord>
                   <brid:RecordID>2323</brid:RecordID>

                  <brid:Text>
                     <brid:Text>
Test</brid:Text>
                  </brid:Text>

               </brid:InputRecord>
            </brid:Records>
         </brid:input>

      </brid:Search>
   </soapenv:Body>
</soapenv:Envelope>
"@

# Concurrency and request settings
$ThreadCount = 2                 # Number of concurrent runspaces
$CallsPerThread = 10             # Number of requests per thread
$PerRequestTimeoutSec = 600      # Timeout for each request (seconds)

# Optional: Ignore SSL certificate validation (for testing environments only)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Connection pool optimization
$servicePoint = [System.Net.ServicePointManager]::FindServicePoint([Uri]$url)
$servicePoint.Expect100Continue = $false
$servicePoint.ConnectionLeaseTimeout = -1
$servicePoint.MaxIdleTime = 600000

# Warm-up request to establish connection
Write-Host "Warm-up call (establishing connection)..." -ForegroundColor Cyan

try {

    $invokeParams = @{
        Uri = $url
        Method = 'Post'
        Headers = $headers
        Body = $xmlBodyInitial
        TimeoutSec = $PerRequestTimeoutSec
    }

    $null = Invoke-RestMethod @invokeParams

    Write-Host "Warm-up completed" -ForegroundColor Green

} catch {

    Write-Host "Warm-up failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "-------------------------------------"

# Thread-safe collections for storing results
$syncRoot = New-Object object
$allTimes = New-Object System.Collections.ArrayList
$threadSummaries = New-Object System.Collections.ArrayList
$totalFailures = 0

# Create RunspacePool
$minThreads = 1
$maxThreads = [int]$ThreadCount

$runspacePool = [runspacefactory]::CreateRunspacePool($minThreads, $maxThreads)
$runspacePool.ThreadOptions = "ReuseThread"
$runspacePool.Open()

# Store asynchronous handles
$asyncHandles = @()

for ($t = 1; $t -le $ThreadCount; $t++) {

    $ps = [powershell]::Create()
    $ps.RunspacePool = $runspacePool

    # Script block executed by each thread
    $script = {

        param(
            $threadIndex,
            $url,
            $headers,
            $xmlBody,
            $callsPerThread,
            $PerRequestTimeoutSec
        )

        $results = @{
            ThreadIndex = $threadIndex
            CallsPlanned = $callsPerThread
            SuccessCount = 0
            FailureCount = 0
            Times = @()
        }

        for ($i = 1; $i -le $callsPerThread; $i++) {

            # Start timer
            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            try {

                $invokeParams = @{
                    Uri = $url
                    Method = 'Post'
                    Headers = $headers
                    Body = $xmlBody
                    TimeoutSec = $PerRequestTimeoutSec
                }

                # Send request
                $resp = Invoke-RestMethod @invokeParams

                # Successful request
                $sw.Stop()

                $results.SuccessCount++
                $results.Times += ,$sw.ElapsedMilliseconds

            } catch {

                # Failed request
                $sw.Stop()

                $results.FailureCount++
            }
        }

        # Calculate thread statistics
        if ($results.Times.Count -gt 0) {

            $arr = $results.Times | ForEach-Object { [long]$_ }

            $avg = [Math]::Round(($arr | Measure-Object -Average).Average, 2)
            $min = ($arr | Measure-Object -Minimum).Minimum
            $max = ($arr | Measure-Object -Maximum).Maximum
            $sum = ($arr | Measure-Object -Sum).Sum

        } else {

            $avg = $null
            $min = $null
            $max = $null
            $sum = 0
        }

        [PSCustomObject]@{
            ThreadIndex   = $results.ThreadIndex
            CallsPlanned  = $results.CallsPlanned
            SuccessCount  = $results.SuccessCount
            FailureCount  = $results.FailureCount
            TimesList     = ($results.Times)
            AvgMs         = $avg
            MinMs         = $min
            MaxMs         = $max
            SumMs         = $sum
        }
    }

    # Add parameters
    $ps.AddScript($script) | Out-Null
    $ps.AddArgument($t) | Out-Null
    $ps.AddArgument($url) | Out-Null
    $ps.AddArgument($headers) | Out-Null
    $ps.AddArgument($xmlBody) | Out-Null
    $ps.AddArgument($CallsPerThread) | Out-Null
    $ps.AddArgument($PerRequestTimeoutSec) | Out-Null

    # Start asynchronous execution
    $async = $ps.BeginInvoke()

    $asyncHandles += [PSCustomObject]@{
        PowerShell = $ps
        Handle = $async
    }
}

# Wait for all runspaces to complete and collect results
foreach ($h in $asyncHandles) {

    $ps = $h.PowerShell
    $async = $h.Handle

    $output = $ps.EndInvoke($async)

    foreach ($o in $output) {

        # Thread-safe result collection
        [System.Threading.Monitor]::Enter($syncRoot)

        try {

            $null = $threadSummaries.Add($o)

            if ($o.TimesList) {
                foreach ($tt in $o.TimesList) {
                    $null = $allTimes.Add([long]$tt)
                }
            }

            $totalFailures += $o.FailureCount

        } finally {

            [System.Threading.Monitor]::Exit($syncRoot)
        }
    }

    # Cleanup
    $ps.Dispose()
}

# Close RunspacePool
$runspacePool.Close()
$runspacePool.Dispose()

# Output per-thread statistics
Write-Host "`n========= Per-Thread Statistics =========" -ForegroundColor Cyan

$threadSummaries | Sort-Object ThreadIndex | ForEach-Object {

    $t = $_

    Write-Host "Thread $($t.ThreadIndex): Planned $($t.CallsPlanned), Success $($t.SuccessCount), Failure $($t.FailureCount)"

    if ($t.SuccessCount -gt 0) {

        Write-Host "  Average: $($t.AvgMs) ms, Min: $($t.MinMs) ms, Max: $($t.MaxMs) ms, Total: $($t.SumMs) ms"

    } else {

        Write-Host "  No successful requests. Unable to calculate statistics." -ForegroundColor Yellow
    }
}

# Overall summary
$totalPlanned = $ThreadCount * $CallsPerThread

$totalSuccess = ($threadSummaries | Measure-Object -Property SuccessCount -Sum).Sum
$totalFailure = ($threadSummaries | Measure-Object -Property FailureCount -Sum).Sum

Write-Host "`n========= Overall Statistics =========" -ForegroundColor Cyan

Write-Host "Thread Count: $ThreadCount"
Write-Host "Calls Per Thread: $CallsPerThread"
Write-Host "Total Planned Calls: $totalPlanned"
Write-Host "Total Success Calls: $totalSuccess"
Write-Host "Total Failure Calls: $totalFailure"

if ($allTimes.Count -gt 0) {

    $overallAvg = [Math]::Round(($allTimes | Measure-Object -Average).Average, 2)
    $overallMin = ($allTimes | Measure-Object -Minimum).Minimum
    $overallMax = ($allTimes | Measure-Object -Maximum).Maximum
    $overallSum = ($allTimes | Measure-Object -Sum).Sum

    Write-Host "Overall Average Response Time: $overallAvg ms"
    Write-Host "Overall Minimum Response Time: $overallMin ms"
    Write-Host "Overall Maximum Response Time: $overallMax ms"
    Write-Host "Overall Total Time: $overallSum ms"

} else {

    Write-Host "All requests failed. No response time statistics available." -ForegroundColor Red
}

Write-Host "============================"