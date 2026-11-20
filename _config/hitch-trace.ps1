# hitch-trace.ps1 -- record ONE krinik-show flight under an ETW trace that tells what the engine does inside each hitch frame.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY (KUMM researches/conan-hitch-profiler, owner's question 2026-11-09 19:39 "chto delaet dvizhok v momenty friznyh kadrov"):
# the first try (wpr -start CPU -start GPU) wrote 23 GB and lost 5 038 727 events -- void. This one is the lean set: the kernel logger with
# big buffers (sampled profile 1 ms + context switches, with stacks) and one user session with the present events only, so PresentMon can
# find the hitches inside the SAME trace (--etl_file) and xperf can cut the trace at each hitch (-range).
#   powershell -File hitch-trace.ps1 -Label hitch-2
#   -> D:\work\ai_sandbox\ConanExiles\_library\_bench\wpr\<date>_<label>.etl and <label>_presents.csv
# Needs an elevated shell (the agent's is) and the machine lock. Exit: 0 ok, 3 no game, 4 a tracing step failed.
# [NOT-TESTED]
param([Parameter(Mandatory = $true)][string]$Label,
      # where the ETL goes: NOT the game's disk D: — the 2026-11-09 N1 trace's worst frame was a whole-process freeze behind a log write while 8.5 GB went to D:
      [string]$OutDir = 'C:\Temp\kumm-wpr')
# 'Continue', not 'Stop': in PowerShell 5.1 a native tool's stderr line under 'Stop' is a terminating error -- the first run (2026-11-09 20:19)
# died on the expected "no such session" of the pre-clean `xperf -stop kumm-present`. Every step checks $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'
$wpt = 'C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\xperf.exe'
$pm = 'D:\work\ai_sandbox\_tools\PresentMon-2.5.1-x64.exe'
$out = $OutDir
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$k = Join-Path $out "$($stamp)_$($Label)_kernel.etl"
$u = Join-Path $out "$($stamp)_$($Label)_user.etl"
$merged = Join-Path $out "$($stamp)_$($Label).etl"
New-Item -ItemType Directory -Force $out | Out-Null
if (-not (Get-Process ConanSandbox-Win64-Shipping -ErrorAction SilentlyContinue)) { Write-Output 'no game'; exit 3 }

& $wpt -stop kumm-present 2>$null | Out-Null
& $wpt -stop 2>$null | Out-Null
& $wpt -on 'PROC_THREAD+LOADER+PROFILE+CSWITCH+DISPATCHER' -stackwalk 'Profile+CSwitch+ReadyThread' -BufferSize 1024 -MinBuffers 512 -MaxBuffers 2048 -f $k
if ($LASTEXITCODE -ne 0) { Write-Output "kernel logger failed $LASTEXITCODE"; exit 4 }
& $wpt -start kumm-present -on 'Microsoft-Windows-DXGI+Microsoft-Windows-DxgKrnl:0x1' -BufferSize 1024 -MinBuffers 64 -MaxBuffers 512 -f $u
if ($LASTEXITCODE -ne 0) { & $wpt -stop | Out-Null; Write-Output "user session failed $LASTEXITCODE"; exit 4 }
Write-Output "tracing since $(Get-Date -Format 'HH:mm:ss')"

# Git Bash by its full path: `bash` is not on the PATH of this machine's PowerShell (2026-11-09 20:20 -- the flight never started)
& 'C:\Program Files\Git\bin\bash.exe' D:/work/ai_sandbox/ConanExiles/_config/bench-flight.sh krinik-show $Label

& $wpt -stop kumm-present -stop -d $merged
if ($LASTEXITCODE -ne 0) { Write-Output "stop/merge failed $LASTEXITCODE"; exit 4 }
Remove-Item $k, $u -ErrorAction SilentlyContinue
$gb = [math]::Round((Get-Item $merged).Length / 1GB, 2)
Write-Output "trace $merged ($gb GB)"
& $pm --etl_file $merged --process_name ConanSandbox-Win64-Shipping.exe --output_file (Join-Path $out "$($stamp)_$($Label)_presents.csv") --no_console_stats 2>&1 | Select-Object -Last 3
exit 0
