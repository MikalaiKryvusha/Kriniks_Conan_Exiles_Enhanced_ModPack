# close-game.ps1 -- close Conan the way the game expects, and wait for it.
#
# ASCII-ONLY ON PURPOSE: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY NOT Stop-Process. CloseMainWindow() asks the window to close, so the game
# writes its save and its config on the way out; Stop-Process kills it and the
# save of the last minutes is gone. Verified twice on Palworld (project canon,
# AGENT_GUIDE -> perf harness) and it holds for Conan too - Conan additionally
# rewrites Game.ini / GameUserSettings.ini on exit, and those rewrites are the
# only way an in-game setting reaches the pack.
#
# Owner's instruction 2026-09-09: "learn to close the game yourself, so it does
# not sit there loading the machine for nothing."
#
#   .\close-game.ps1
#   .\close-game.ps1 -TimeoutSec 90

param([int]$TimeoutSec = 60)

$ErrorActionPreference = 'Stop'
$name = 'ConanSandbox-Win64-Shipping'

$reporter = Join-Path $PSScriptRoot 'close-crash-reporter.ps1'

$p = Get-Process -Name $name -ErrorAction SilentlyContinue
# Not running may mean "crashed": the reporter window of our run stays on the owner's screen otherwise (HOUSE_RULES par. 1).
if (-not $p) { Write-Output 'game is not running'; & $reporter; exit 0 }

Write-Output ("closing pid {0} (running since {1})" -f $p.Id, $p.StartTime.ToString('HH:mm:ss'))
# UE4SS.dll lies next to the running exe (Binaries\Win64\ue4ss). Taken from the process, not a hard-coded install:
# 2026-10-25 the hard-coded 2.2.3 path outlived that install and the wait below watched a file that no longer existed.
$dll = Join-Path (Split-Path $p.Path) 'ue4ss\UE4SS.dll'
$null = $p.CloseMainWindow()

$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  Start-Sleep -Milliseconds 500
  if (-not (Get-Process -Name $name -ErrorAction SilentlyContinue)) {
    # The process is gone, but Windows keeps UE4SS.dll MAPPED for a moment
    # longer, and a deploy that runs right now fails with "cannot be performed
    # on a file with a user-mapped section open". Seen on every run of the
    # camera harness 2026-09-09. So wait for the file to actually be writable -
    # "the process exited" and "the file is free" are two different facts.
    for ($i = 0; $i -lt 40; $i++) {
      try {
        $fs = [IO.File]::Open($dll, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        break
      } catch { Start-Sleep -Milliseconds 500 }
    }
    $sw.Stop()
    Write-Output ("closed cleanly in {0:n1} s (UE4SS.dll free)" -f $sw.Elapsed.TotalSeconds)
    & $reporter
    exit 0
  }
}

$sw.Stop()
# Deliberately NOT killing here: a hung game is a fact worth seeing, and killing
# it would destroy the save that the hang is about. Report and let a human decide.
Write-Output ("STILL RUNNING after {0} s - not killing it. Save would be lost." -f $TimeoutSec)
exit 1
