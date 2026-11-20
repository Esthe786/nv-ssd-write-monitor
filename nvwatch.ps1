<#
  nvwatch.ps1 - watch how much NVDisplay.Container.exe writes (NVIDIA driver SSD-write bug check)
  Usage: nvwatch.bat [-IntervalSec 60] [-Hours 0]   (Hours 0 = run until Ctrl+C)
  Read-only: it only reads process I/O counters. Changes nothing.
#>
param(
    [int]$IntervalSec = 60,
    [double]$Hours = 0
)

$ErrorActionPreference = 'SilentlyContinue'
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$csv   = Join-Path $here "nvwatch-$stamp.csv"
$sumf  = Join-Path $here "nvwatch-$stamp-summary.txt"
$nvlog = Join-Path $env:ProgramData 'NVIDIA Corporation\nvtopps\nct\nvlog.nvlgstg'
$end   = if ($Hours -gt 0) { (Get-Date).AddHours($Hours) } else { [datetime]::MaxValue }

function Get-NvDriver {
    $v = (Get-CimInstance Win32_VideoController | Where-Object Name -like '*NVIDIA*' | Select-Object -First 1)
    if (-not $v) { return $null }
    $p = $v.DriverVersion.Split('.')
    $n = ($p[2].Substring($p[2].Length - 1) + $p[3].PadLeft(4, '0'))
    [pscustomobject]@{ Gpu = $v.Name; Raw = $v.DriverVersion; Ver = $n.Substring(0, 3) + '.' + $n.Substring(3) }
}

function Get-Verdict([double]$mbh) {
    if ($mbh -le 50)   { return @('NORMAL',   'Green') }   # 621.01 measured < 24 MB/h
    if ($mbh -le 1000) { return @('ELEVATED', 'Yellow') }
    return @('HIGH - bug likely', 'Red')                   # 621.14 ~6 GB/h, 621.24 up to 30 GB/h
}

function Get-Instances {
    # every NVDisplay.Container.exe instance (there are usually two: the service and its child)
    @(Get-CimInstance Win32_Process -Filter "Name='NVDisplay.Container.exe'")
}

function Get-Counters($procs) {
    # PID -> bytes written so far
    $h = @{}
    foreach ($x in $procs) { $h[[int]$x.ProcessId] = [double]$x.WriteTransferCount }
    $h
}

$drv = Get-NvDriver
$Host.UI.RawUI.WindowTitle = 'NVIDIA SSD write monitor'
Write-Host '=== NVIDIA Display Container SSD write monitor ===' -ForegroundColor Cyan
if ($drv) { Write-Host ("GPU    : {0}`nDriver : {1}  ({2})" -f $drv.Gpu, $drv.Ver, $drv.Raw) }
else      { Write-Host 'No NVIDIA GPU found.' -ForegroundColor Red; exit 1 }
if ($drv.Ver -in '621.14', '621.24') { Write-Host 'This driver version is one of the reported-affected ones.' -ForegroundColor Yellow }
Write-Host ("Sample every {0}s, hourly summary. Log: {1}" -f $IntervalSec, $csv)
Write-Host 'Thresholds: <=50 MB/h normal | <=1000 elevated | >1000 high.  Ctrl+C to stop.' -ForegroundColor DarkGray
Write-Host ''

'time,pids,write_mb_total,delta_mb,nvlog_bytes' | Out-File $csv -Encoding utf8

$start = Get-Date
$procs = Get-Instances
if ($procs.Count -eq 0) { Write-Host 'NVDisplay.Container.exe is not running.' -ForegroundColor Red; exit 1 }
$last  = Get-Counters $procs
foreach ($x in $procs | Sort-Object WriteTransferCount -Descending) {
    $mb  = $x.WriteTransferCount / 1MB
    $upH = ((Get-Date) - $x.CreationDate).TotalHours
    Write-Host ("PID {0} already wrote {1:N1} MB since it started {2:N1} h ago (~{3:N0} MB/h, includes boot burst)" -f $x.ProcessId, $mb, $upH, ($mb / [math]::Max($upH, 0.01)))
}
Write-Host ''

$totalMB   = 0.0
$hourMB    = 0.0
$hourStart = $start
$hourNo    = 0

while ((Get-Date) -lt $end) {
    Start-Sleep -Seconds $IntervalSec
    $now = Get-Date
    $procs = Get-Instances
    if ($procs.Count -eq 0) { Write-Host ("{0:HH:mm:ss}  process not running" -f $now) -ForegroundColor DarkYellow; continue }
    $cur   = Get-Counters $procs
    # delta per PID: a PID seen before adds its increase; a new PID (service restarted) adds all it wrote so far
    $deltaB = 0.0
    foreach ($id in $cur.Keys) {
        if ($last.ContainsKey($id)) { $deltaB += [math]::Max($cur[$id] - $last[$id], 0) }
        else {
            Write-Host ("{0:HH:mm:ss}  new PID {1} (service restarted?)" -f $now, $id) -ForegroundColor DarkYellow
            $deltaB += $cur[$id]
        }
    }
    $last  = $cur
    $delta = $deltaB / 1MB
    $mb    = ($cur.Values | Measure-Object -Sum).Sum / 1MB
    $pids  = ($cur.Keys | Sort-Object) -join ' '
    $totalMB += $delta; $hourMB += $delta
    $len = if (Test-Path $nvlog) { (Get-Item $nvlog).Length } else { '' }
    "{0:yyyy-MM-dd HH:mm:ss},{1},{2:F1},{3:F2},{4}" -f $now, $pids, $mb, $delta, $len | Out-File $csv -Append -Encoding utf8

    $rate = $delta * 3600 / $IntervalSec
    $v = Get-Verdict $rate
    Write-Host ("{0:HH:mm:ss}  +{1,8:N2} MB   (~{2,8:N0} MB/h)   total {3,9:N1} MB" -f $now, $delta, $rate, $totalMB) -ForegroundColor $v[1]

    if (($now - $hourStart).TotalMinutes -ge 60) {
        $hourNo++
        $hrs  = ($now - $start).TotalHours
        $avg  = $totalMB / $hrs
        $vh   = Get-Verdict $hourMB
        $line = "[Hour {0}] {1:HH:mm}-{2:HH:mm}  this hour {3:N1} MB  |  avg {4:N1} MB/h over {5:N1} h  |  {6}" -f $hourNo, $hourStart, $now, $hourMB, $avg, $hrs, $vh[0]
        Write-Host ''
        Write-Host ('=' * 78) -ForegroundColor Cyan
        Write-Host $line -ForegroundColor $vh[1]
        Write-Host ("          projected per day ~{0:N2} GB" -f ($avg * 24 / 1024)) -ForegroundColor $vh[1]
        Write-Host ('=' * 78) -ForegroundColor Cyan
        Write-Host ''
        $line | Out-File $sumf -Append -Encoding utf8
        $hourMB = 0.0; $hourStart = $now
    }
}
Write-Host ("Done. Total {0:N1} MB in {1:N1} h. Log: {2}" -f $totalMB, ((Get-Date) - $start).TotalHours, $csv) -ForegroundColor Cyan
