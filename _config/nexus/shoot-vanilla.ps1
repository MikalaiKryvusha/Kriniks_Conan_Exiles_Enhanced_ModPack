# shoot-vanilla.ps1 -- the one frame that needs the mod switched OFF.
# ASCII ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY A RESTART AND NOT A FAKE. The vanilla seating could be reproduced by
# feeding the mod the game's own numbers, and the frame would look right - but
# the mod would still be holding the camera, muting another mod's zoom and
# owning the pull target. A "before" picture in which the thing being compared
# is still running is not a before picture.
#
# The mod is switched off the way UE4SS switches mods off: enabled.txt goes
# away. Only ConanCameraControl - the status mod stays, because it is what
# clears the offline modal the launcher script has to click past.

. "$PSScriptRoot\..\game-target.ps1"   # install path from targets.json (2026-10-25)
$ErrorActionPreference = 'Stop'

# Said out loud before anything is touched, because an operator who stops this
# run needs to know the one command that undoes it.
Write-Output 'if this run is interrupted, restore the mod with: _config\nexus\mod-on.ps1'
$modDir = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\Mods\ConanCameraControl')
$on  = Join-Path $modDir 'enabled.txt'
$off = Join-Path $modDir 'enabled.txt.off'
$cfg = 'D:\work\ai_sandbox\ConanExiles\_config'
$out = 'D:\work\ai_sandbox\ConanExiles\_unpacked\ConanCameraControl\nexus-screenshots'

try {
  & (Join-Path $cfg 'close-game.ps1') | Select-Object -Last 1
  Start-Sleep -Seconds 5

  if (Test-Path $on) { Move-Item $on $off -Force }
  Write-Output 'camera mod: OFF'

  & (Join-Path $cfg 'enter-world.ps1') -TimeoutSec 260 -AllowDisabledMods | Select-Object -Last 1
  Start-Sleep -Seconds 8
  # A LADDER, NOT ONE FRAME. The first vanilla attempt came out with the hero
  # tiny: with the mod off the distance is the game's own wheel value, and
  # nothing in the run could read it back. So the run shoots several zoom
  # steps in ONE session and the choice is made afterwards, by measuring the
  # hero against the modded frame - instead of another launch per guess.
  $cap = Join-Path $cfg 'capture.ps1'
  $inp = Join-Path $cfg 'input.ps1'
  for ($i = 0; $i -lt 5; $i++) {
    & $cap -Out (Join-Path $out ('01-vanilla-z{0}.png' -f $i)) -Width 3840 | Out-Null
    Write-Output ('shot 01-vanilla-z{0}' -f $i)
    if ($i -lt 4) {
      & $inp -Wheel 1 | Out-Null      # positive = closer
      Start-Sleep -Milliseconds 900
    }
  }
}
finally {
  # THE MOD COMES BACK FIRST, BEFORE ANYTHING ELSE IN THIS BLOCK.
  #
  # It used to come back LAST, after close-game and a five second sleep - and
  # on 2026-09-11 the owner stopped the run, the interrupt landed inside that
  # sleep, and his camera mod stayed disabled. The file only matters at the
  # NEXT launch, so there is no reason at all for it to wait behind a shutdown:
  # every second it waits is a second in which an interrupt costs the owner his
  # camera. Restore first, tidy afterwards.
  if (Test-Path $off) { Move-Item $off $on -Force }
  Write-Output 'camera mod: BACK ON'
  & (Join-Path $cfg 'close-game.ps1') | Select-Object -Last 1
}
