# --- CONFIG ---
$basePrefix = "192.168.122."
$lastOctets = 1..254
$ports = 22,23,80,443,9100
$timeoutMs = 150
$throttle = 50             # how many parallel tasks at once (adjust to your system/network)
$outCsv = "scan_results_parallel.csv"

$ips = $lastOctets | ForEach-Object { "$basePrefix$_" }

# Use a thread-safe collection (ConcurrentQueue style) to collect results
$results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

$scriptBlock = {
    param($ip, $ports, $timeoutMs, $results)

    foreach ($port in $ports) {
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $task = $tcp.ConnectAsync($ip, [int]$port)
            $success = $task.Wait($timeoutMs)
            if ($success -and $tcp.Connected) {
                $obj = [PSCustomObject]@{
                    Host  = $ip
                    Port  = $port
                    State = "Open"
                    Time  = (Get-Date).ToString("s")
                }
                $results.Add($obj)
                Write-Output "$ip port $port Open"
            } else {
                # optionally silent for closed ports to reduce noise
                # Write-Output "$ip port $port Closed/Timeout"
            }
        } catch {
            # handle/ignore
        } finally {
            try { $tcp.Close(); $tcp.Dispose() } catch {}
        }
    }
}

$ips | ForEach-Object -Parallel {
    & $using:scriptBlock -ip $_ -ports $using:ports -timeoutMs $using:timeoutMs -results $using:results
} -ThrottleLimit $throttle

# Export results
if ($results.Count -gt 0) {
    $results | Sort-Object Host, Port | Export-Csv -Path $outCsv -NoTypeInformation -Force
    Write-Host "Saved results to $outCsv"
} else {
    Write-Host "No open ports found."
}