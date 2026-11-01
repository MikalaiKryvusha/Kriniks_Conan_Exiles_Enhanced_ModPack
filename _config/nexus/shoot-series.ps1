# shoot15.ps1 -- the series for the Nexus page, one spot, one session.
# ASCII ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# THE RULE THE SERIES IS BUILT ON (owner, 2026-09-10, verbatim):
#   "s pricelom u geroya na zhope - ne ochen horosho"
#   "rovno kak i s pricelom nizhe geroya - eto pizdec, nepravilno"
#   "pricel dolzhen byt vyshe golovy"
# The crosshair is the centre of the screen, so the hero must sit BELOW it.
#
# THE ARITHMETIC THAT MAKES THAT RULE CHECKABLE INSTEAD OF FELT:
#     hero below crosshair, degrees = atan(offset_z / arm_length) - |pitch|
# Raising the camera pushes the hero down the frame; tilting the view down
# lifts him back up. Cancel them and he lands ON the crosshair.
#
# That is not a theory - it is what went wrong. The first cut of this series
# used the same tilt at 950 units as at 250, and at that distance a lift of
# 200 buys only 12 degrees, so a 14-degree tilt ate all of it and put the
# crosshair on the hero's head. Three frames, and the owner spotted every one.
#
# The check now runs BEFORE each shot and refuses the frame. A rule that lives
# in a comment gets broken by the next session; a rule that refuses to shoot
# does not.
#
# Driven through the mod's keyless channel: the agent cannot press the mod's
# numpad keys (measured 2026-09-10), so a key-driven series would silently
# shoot the same frame fourteen times.

param([string]$OutDir = 'D:\work\ai_sandbox\ConanExiles\_unpacked\ConanCameraControl\nexus-screenshots')
. "$PSScriptRoot\..\game-target.ps1"   # install path from targets.json (2026-10-25)

$ErrorActionPreference = 'Stop'
$cmd = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\Mods\ConanCameraControl\agent-cmd.txt')
$cap = 'D:\work\ai_sandbox\ConanExiles\_config\capture.ps1'
if (-not (Test-Path $OutDir)) { $null = New-Item -ItemType Directory -Path $OutDir }

# Below this the hero crowds the crosshair. Twelve is drawn from the frames
# the owner accepted (lowest 12.9) versus the ones he rejected (all negative).
$MIN_BELOW = 12.0

# name, offset_y, offset_z, arm_length, camera_pitch
$shots = @(
  @('02-behind',          0,  65, 190,   0),
  @('03-closest',         0,  65,  70,   0),
  @('04-close-tilt',      0,  90,  90, -10),
  @('05-normal-tilt',     0,  95, 190, -10),
  @('06-lift-soft',       0, 110, 220,  -8),
  @('07-lift-mid',        0, 150, 250, -12),
  @('08-lift-strong',     0, 190, 280, -16),
  @('09-lift-tall',       0, 240, 300, -20),
  @('10-shoulder-right', 90,  65, 190,  -6),
  @('11-shoulder-left', -90,  65, 190,  -6),
  @('12-lift-shoulder',  70, 150, 250, -12),
  @('13-far',             0, 360, 950,  -6),
  @('14-panorama',        0, 480, 950, -10),
  @('15-limit',           0, 620, 1000, -12)
)

# Check the WHOLE table first, and shoot nothing if any row fails. Finding out
# at frame twelve that frame thirteen is impossible wastes the weather window
# the owner waited for.
foreach ($s in $shots) {
  $below = [Math]::Atan($s[2] / $s[3]) * 180.0 / [Math]::PI - [Math]::Abs($s[4])
  if ($below -lt $MIN_BELOW) {
    throw ("{0}: hero would sit {1:n1} deg below the crosshair, under the {2} minimum" -f $s[0], $below, $MIN_BELOW)
  }
}
Write-Output ("all {0} frames pass the crosshair rule" -f $shots.Count)

# THE MANIFEST IS THE SOURCE OF TRUTH FOR THE CAPTIONS.
# Until now the numbers lived twice - here and in caption.py's table - and
# within one afternoon they drifted: four frames were refitted here and the
# captions still carried the old distances. A caption that states settings the
# frame does not have is the same defect as the three identical frames, only
# harder to spot. So the settings are WRITTEN OUT with the frames, and the
# captioning step reads them instead of keeping its own copy.
$manifest = Join-Path $OutDir 'shots.csv'
"name,offset_y,offset_z,arm_length,camera_pitch,below_deg" | Set-Content -Path $manifest -Encoding utf8

foreach ($s in $shots) {
  $below = [Math]::Atan($s[2] / $s[3]) * 180.0 / [Math]::PI - [Math]::Abs($s[4])
  # InvariantCulture on the one fractional column: this shell runs under ru-RU
  # and "{0:n1}" writes 18,9 - a decimal comma inside a COMMA-separated file,
  # which quietly turns one column into two. It did not bite yet only because
  # the reader takes the first five fields; the next reader will not be so
  # lucky, and the file would still look right to the eye.
  $belowStr = $below.ToString("F1", [System.Globalization.CultureInfo]::InvariantCulture)
  ("{0},{1},{2},{3},{4},{5}" -f $s[0], $s[1], $s[2], $s[3], $s[4], $belowStr) |
    Add-Content -Path $manifest -Encoding utf8
  $body = "offset_y = $($s[1])`noffset_z = $($s[2])`narm_length = $($s[3])`ncamera_pitch = $($s[4])`n"
  [System.IO.File]::WriteAllText($cmd, $body)
  Start-Sleep -Seconds 4
  & $cap -Out (Join-Path $OutDir ($s[0] + '.png')) -Width 3840 | Out-Null
  Write-Output ("{0}: y={1} z={2} arm={3} pitch={4} -> hero {5:n1} deg below crosshair" -f $s[0], $s[1], $s[2], $s[3], $s[4], $below)
}

# Back to the seating the owner accepted on 2026-09-10, so the game is never
# left standing in an experiment's state.
[System.IO.File]::WriteAllText($cmd, "offset_y = 0`noffset_z = 65`narm_length = 190`ncamera_pitch = 0`n")
Write-Output 'restored the accepted seating'
