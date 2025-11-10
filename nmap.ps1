# PowerShell 7+ parallel scanner — rezultat drukowany na konsoli po skanowaniu
# --- KONFIG ---
$basePrefix = "192.168.122."
$lastOctets = 1..254
$ports = 22,23,80,443,9100
$timeoutMs = 150
$throttle = 200    # dostosuj do zasobów / sieci

# Przygotowanie
$ips = $lastOctets | ForEach-Object { "$basePrefix$_" }
$results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
$sw = [Diagnostics.Stopwatch]::StartNew()

# Równoległy skan — logika bezpośrednio w bloku -Parallel
$ips | ForEach-Object -Parallel {
    $ip = $_
    foreach ($port in $using:ports) {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        try {
            $task = $tcp.ConnectAsync($ip, [int]$port)
            $success = $task.Wait($using:timeoutMs)
            if ($success -and $tcp.Connected) {
                $obj = [PSCustomObject]@{
                    Host  = $ip
                    Port  = $port
                    State = "Open"
                    Time  = (Get-Date).ToString("s")
                }
                $using:results.Add($obj)
                # nie piszemy tutaj dużo na konsolę, żeby nie zaśmiecać podczas skanowania
            }
        } catch {
            # ignoruj błędy jeśli chcesz; możesz dodać logowanie
        } finally {
            try { $tcp.Close(); $tcp.Dispose() } catch {}
        }
    }
} -ThrottleLimit $throttle

$sw.Stop()

# Pobierz i posortuj wyniki
$resultsArray = $results.ToArray() | Sort-Object Host, Port

# Wyświetl ładne podsumowanie i tabelę wyników
Write-Host ""
Write-Host "=== Scan summary ==="
Write-Host ("Targets scanned: {0}  Ports per host: {1}  Timeout(ms): {2}" -f ($ips.Count), ($using:ports.Count), $timeoutMs)
Write-Host ("Elapsed time: {0:hh\:mm\:ss} (hh:mm:ss)" -f $sw.Elapsed)
Write-Host ("Open endpoints found: {0}" -f $resultsArray.Count)
Write-Host "===================="
Write-Host ""

if ($resultsArray.Count -gt 0) {
    # Przyjazna tabela: Host | Port | State | Time
    $resultsArray | Format-Table @{Label="Host";Expression={$_.Host}}, @{Label="Port";Expression={$_.Port}}, @{Label="State";Expression={$_.State}}, @{Label="When";Expression={$_.Time}} -AutoSize
} else {
    Write-Host "Brak otwartych portów."
}
