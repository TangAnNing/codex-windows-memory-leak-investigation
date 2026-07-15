$ErrorActionPreference = 'Continue'

$root = Join-Path $PSScriptRoot 'memory-monitor'
New-Item -ItemType Directory -Path $root -Force | Out-Null
$summaryPath = Join-Path $root 'system.csv'
$processPath = Join-Path $root 'process-groups.csv'
$pidPath = Join-Path $root 'process-pids.csv'
$stopPath = Join-Path $root 'stop.txt'

Remove-Item -LiteralPath $stopPath -Force -ErrorAction SilentlyContinue

while (-not (Test-Path -LiteralPath $stopPath)) {
    $now = Get-Date
    $counters = Get-Counter @(
        '\Memory\Committed Bytes',
        '\Memory\Commit Limit',
        '\Memory\Available MBytes',
        '\Memory\Pool Nonpaged Bytes',
        '\Memory\Pool Paged Bytes'
    ) -ErrorAction SilentlyContinue

    $values = @{}
    foreach ($sample in $counters.CounterSamples) {
        $values[$sample.Path.Split('\')[-1]] = $sample.CookedValue
    }

    $processes = Get-Process -ErrorAction SilentlyContinue
    $summary = [pscustomobject]@{
        Time = $now.ToString('o')
        AvailableMB = [math]::Round($values['available mbytes'], 1)
        CommittedMB = [math]::Round($values['committed bytes'] / 1MB, 1)
        CommitLimitMB = [math]::Round($values['commit limit'] / 1MB, 1)
        NonpagedMB = [math]::Round($values['pool nonpaged bytes'] / 1MB, 1)
        PagedMB = [math]::Round($values['pool paged bytes'] / 1MB, 1)
        ProcessPrivateMB = [math]::Round((($processes | Measure-Object PrivateMemorySize64 -Sum).Sum) / 1MB, 1)
        ProcessWorkingMB = [math]::Round((($processes | Measure-Object WorkingSet64 -Sum).Sum) / 1MB, 1)
        ProcessCount = $processes.Count
    }
    $summary | Export-Csv -LiteralPath $summaryPath -Append -NoTypeInformation -Encoding UTF8

    $groups = $processes | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{
            Time = $now.ToString('o')
            Name = $_.Name
            Count = $_.Count
            PrivateMB = [math]::Round((($_.Group | Measure-Object PrivateMemorySize64 -Sum).Sum) / 1MB, 1)
            WorkingMB = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB, 1)
            Handles = (($_.Group | Measure-Object HandleCount -Sum).Sum)
        }
    }
    $groups | Sort-Object PrivateMB -Descending | Select-Object -First 40 |
        Export-Csv -LiteralPath $processPath -Append -NoTypeInformation -Encoding UTF8

    if ($summary.AvailableMB -lt 1000 -or ($summary.CommittedMB / $summary.CommitLimitMB) -gt 0.80) {
        $processes | Select-Object ProcessName,Id,Path,StartTime,
            @{N='PrivateMB';E={[math]::Round($_.PrivateMemorySize64/1MB,1)}},
            @{N='WorkingMB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
            HandleCount,@{N='Threads';E={$_.Threads.Count}},CPU |
            Sort-Object PrivateMB -Descending |
            Export-Csv -LiteralPath $pidPath -Append -NoTypeInformation -Encoding UTF8
    }

    Start-Sleep -Seconds 10
}

