# ue4ss-probe.ps1 -- launch the game and answer ONE question: did UE4SS survive its own init?
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY IT EXISTS. Bug 10 (FName::StaticAlignment fatal) is fixed by trying ONE settings key per
# launch. Every attempt costs the owner his screen (remote desktop), so the probe answers as
# early as the log allows -- at UE4SS init, long before the main menu -- and never enters the
# world. It does NOT close the game: closing is a separate, deliberate step.
#
#   .\ue4ss-probe.ps1
#   .\ue4ss-probe.ps1 -TimeoutSec 180

param([int]$TimeoutSec = 150)
. "$PSScriptRoot\game-target.ps1"   # install path from targets.json (2026-10-25)

$ErrorActionPreference = 'Stop'
$exe  = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe')
$ulog = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\UE4SS.log')

$started = Get-Date
if (-not (Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue)) {
  $null = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
  Write-Output ("[{0}] launched" -f (Get-Date -Format HH:mm:ss))
} else {
  Write-Output 'game already running - probing the CURRENT log, not a fresh one'
}

function Fresh-Log { (Test-Path $ulog) -and ((Get-Item $ulog).LastWriteTime -ge $started) }
function Log-Line([string]$Pattern) {
  if (-not (Fresh-Log)) { return $null }
  Select-String -Path $ulog -Pattern $Pattern -ErrorAction SilentlyContinue | Select-Object -First 1
}

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  $dead = Log-Line 'StaticAlignment_Private is not valid'
  if ($dead) {
    $sw.Stop()
    Write-Output ("[{0}] VERDICT: DEAD after {1:n0} s -- {2}" -f (Get-Date -Format HH:mm:ss), $sw.Elapsed.TotalSeconds, $dead.Line.Trim())
    exit 2
  }
  $alive = Log-Line 'FName Alignment'
  if ($alive) {
    $sw.Stop()
    Write-Output ("[{0}] VERDICT: ALIVE after {1:n0} s -- {2}" -f (Get-Date -Format HH:mm:ss), $sw.Elapsed.TotalSeconds, $alive.Line.Trim())
    # give the Lua layer a moment to announce itself, then report which mods started
    Start-Sleep -Seconds 20
    Write-Output '--- Lua mods that announced themselves ---'
    Select-String -Path $ulog -Pattern "Starting Lua mod|mod .* started|\[HosavRU\]|Event loop start" -ErrorAction SilentlyContinue |
      ForEach-Object { $_.Line.Trim() } | Select-Object -Last 25
    exit 0
  }
  if (-not (Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue)) {
    $sw.Stop()
    Write-Output ("[{0}] VERDICT: PROCESS GONE after {1:n0} s - it aborted before UE4SS decided" -f (Get-Date -Format HH:mm:ss), $sw.Elapsed.TotalSeconds)
    exit 3
  }
  Start-Sleep -Seconds 3
}
$sw.Stop()
Write-Output ("[{0}] VERDICT: NO ANSWER in {1} s - log wrote neither line" -f (Get-Date -Format HH:mm:ss), $TimeoutSec)
exit 4
