# mod-on.ps1 -- put the camera mod back. One line, no arguments, safe to run twice.
# ASCII ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY THIS EXISTS. shoot-vanilla.ps1 switches the camera mod OFF to take the
# one frame that needs the game's own camera, and switches it back in a finally
# block. A finally block does not survive every way a run can end - on
# 2026-09-11 the owner stopped the run and his camera mod stayed off. A restore
# that depends on the script surviving is not a restore; this is the one that
# does not depend on anything.

. "$PSScriptRoot\..\game-target.ps1"   # install path from targets.json (2026-10-25)
$modDir = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\Mods\ConanCameraControl')
$on  = Join-Path $modDir 'enabled.txt'
$off = Join-Path $modDir 'enabled.txt.off'

if (Test-Path $on) { Write-Output 'camera mod: already ON'; exit 0 }
if (Test-Path $off) {
  Move-Item $off $on -Force
  Write-Output 'camera mod: BACK ON'
  exit 0
}
New-Item -ItemType File -Path $on | Out-Null
Write-Output 'camera mod: enabled.txt recreated (neither file was present)'
