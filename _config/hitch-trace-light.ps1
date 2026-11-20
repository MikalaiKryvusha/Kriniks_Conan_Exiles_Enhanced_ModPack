# hitch-trace-light.ps1 -- the LIGHT probe for one krinik-show flight: the kernel trace lives in a 2 GB in-memory ring (xperf -Buffering) and is written to disk
# only AFTER the flight, to C: (not the game's disk D:). Sampled profile with stacks; context switches WITHOUT stacks; no ReadyThread.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY (KUMM HOUSE_RULES 11.6e, the owner's word 2026-11-09 21:27 "kak nashim shchupom oscillografa ne vnesti izmeneniya v izmeryaemuyu shemu"): the heavy
# hitch-trace.ps1 wrote 8.5 GB to D: during the flight; traced base 67 hitches / 55.7 FPS vs untraced 35-59 / 58-59, and the N1 traced worst frame froze behind
# a log write. This probe writes nothing during the flight; the present events (tiny) go to a file on C:.
#   powershell -File hitch-trace-light.ps1 -Label light-1
# Exit: 0 ok, 3 no game, 4 a tracing step failed.
# [NOT-TESTED]
param([Parameter(Mandatory = $true)][string]$Label, [string]$OutDir = 'C:\Temp\kumm-wpr')
$ErrorActionPreference = 'Continue'
$wpt = 'C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\xperf.exe'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$k = Join-Path $OutDir "$($stamp)_$($Label)_kernel.etl"
$merged = Join-Path $OutDir "$($stamp)_$($Label).etl"
if (-not (Get-Process ConanSandbox-Win64-Shipping -ErrorAction SilentlyContinue)) { Write-Output 'no game'; exit 3 }
& $wpt -stop 2>$null | Out-Null
& $wpt -on 'PROC_THREAD+LOADER+PROFILE+CSWITCH' -stackwalk 'Profile' -Buffering -BufferSize 1024 -MinBuffers 2048 -MaxBuffers 2048
if ($LASTEXITCODE -ne 0) { Write-Output "kernel logger failed $LASTEXITCODE"; exit 4 }
Write-Output "tracing (in memory) since $(Get-Date -Format 'HH:mm:ss')"
& 'C:\Program Files\Git\bin\bash.exe' D:/work/ai_sandbox/ConanExiles/_config/bench-flight.sh krinik-show $Label
& $wpt -flush 'NT Kernel Logger' -f $k
& $wpt -stop | Out-Null
& $wpt -merge $k $merged | Out-Null
Remove-Item $k -ErrorAction SilentlyContinue
if (Test-Path $merged) { Write-Output ("trace {0} ({1} GB)" -f $merged, [math]::Round((Get-Item $merged).Length / 1GB, 2)) } else { Write-Output 'no merged trace'; exit 4 }
exit 0
