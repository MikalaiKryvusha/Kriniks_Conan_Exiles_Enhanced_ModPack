# close-crash-reporter.ps1 -- close the crash reporter window left by a crash in the AGENT'S run.
#
# ASCII-ONLY ON PURPOSE: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY. Owner's word 2026-10-26 ~19:39 (after the 18:03 crash left "ConanSandbox Crash Reporter" on his
# screen): "ubirai za soboi okna kresh reportov, pozhaluista" (HOUSE_RULES.md par. 1). The rule:
# only reporters started AFTER the agent's launch, closed by PID, never by image name
# (memory never-kill-by-image-name: taskkill /IM node.exe once took down the owner's pm2).
#
# Which reporter is "ours": StartTime >= the agent's launch moment and the exe lies inside the game
# install. The launch moment comes from -Since or from the stamp launch-bg.ps1 writes
# (the pack's _scratch\kumm-conan-agent-launch.txt). No stamp and no -Since -> nothing is closed: the owner's own
# game session may have crashed, and his report window is his.
#
#   .\close-crash-reporter.ps1
#   .\close-crash-reporter.ps1 -Since '2026-10-26 18:00'
# [TESTED: 2026-10-31 · three twin processes: before the launch - left, after inside the game dir - closed by PID, after outside - left · KUMM testcases/reports/2026-10-31_conan-crash-reporter-closer-twins.md]

param(
  [string]$Since = '',
  [string]$GameDir = '',
  [string]$Name = 'CrashReportClient'
)

$ErrorActionPreference = 'Stop'
if (-not $GameDir) { . (Join-Path $PSScriptRoot 'game-target.ps1') }   # the first enabled target of targets.json (2026-11-13, KUMM plan 53)
$stamp = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) '_scratch') 'kumm-conan-agent-launch.txt'

if ($Since) { $t0 = [datetime]::Parse($Since) }
elseif (Test-Path $stamp) { $t0 = [datetime]::Parse((Get-Content $stamp -TotalCount 1)) }
else { Write-Output 'crash reporter: no agent launch stamp - nothing closed'; exit 0 }

$root = [IO.Path]::GetFullPath($GameDir).TrimEnd('\') + '\'
$closed = 0
foreach ($p in @(Get-Process -Name $Name -ErrorAction SilentlyContinue)) {
  $path = $null
  try { $path = $p.Path } catch { }
  if (-not $path -or -not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Output ("crash reporter pid {0}: not of this game ({1}) - left" -f $p.Id, $path); continue
  }
  if ($p.StartTime -lt $t0) {
    Write-Output ("crash reporter pid {0}: started {1:HH:mm:ss} before the agent launch {2:HH:mm:ss} - left" -f $p.Id, $p.StartTime, $t0); continue
  }
  Stop-Process -Id $p.Id -Force
  Write-Output ("crash reporter closed, pid {0}, started {1:HH:mm:ss}, title '{2}'" -f $p.Id, $p.StartTime, $p.MainWindowTitle)
  $closed++
}
if ($closed -eq 0) { Write-Output ("crash reporter: none of the agent's run (since {0:HH:mm:ss})" -f $t0) }
exit 0
