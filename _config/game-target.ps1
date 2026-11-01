# game-target.ps1 -- dot-source me: $GameDir = folder of the first enabled target in targets.json.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY (2026-10-25): after the move to 3.0.1 and the deletion of 2.2.3, 21 tools in _config kept the
# hard-coded 2.2.3 path. The install path now lives in one place - targets.json - like the KUMM engine
# reads it. Python tools: game_target.py (same rule).
#
#   . "$PSScriptRoot\game-target.ps1"      (from _config\nexus: "$PSScriptRoot\..\game-target.ps1")
# [NOT-TESTED]

$__targets = Get-Content -Raw -Encoding UTF8 (Join-Path (Split-Path $PSScriptRoot -Parent) 'targets.json') -ErrorAction SilentlyContinue
if (-not $__targets) {
  $__targets = Get-Content -Raw -Encoding UTF8 (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'targets.json')
}
$GameDir = $null
foreach ($t in ($__targets | ConvertFrom-Json).targets) {
  if ($t.PSObject.Properties.Name -notcontains 'enabled' -or $t.enabled) { $GameDir = $t.path; break }
}
if (-not $GameDir) { throw 'targets.json has no enabled target' }
