# enter-world.ps1 -- launch the game and get INTO the world, stubbornly.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY STUBBORN. Observed four times on 2026-09-09 (18:08, 18:14, 18:19, 20:58):
# this build ABORTS after about three minutes sitting on the main menu -
# "Precompiles Remaining: 4736, Paused: 1" and then an abort signal. So a single
# click attempt is not enough: if the window handle is not ready yet, the focus
# gate (rightly) refuses, the click never lands, and the game kills itself.
# Here we retry until the world log line appears.
#
# The CONTINUE button is addressed as a FRACTION of the screen, never as pixels:
# the TV falls asleep between runs and the game then opens on a 1280x800 virtual
# display, where a coordinate computed for 3840x2160 lands off-screen.
#
#   .\enter-world.ps1
#   .\enter-world.ps1 -TimeoutSec 240

param(
  [int]$TimeoutSec = 240,
  # The ONE legitimate reason to launch with a mod switched off: the vanilla
  # frame, which exists to show the game's own camera. Anything else that meets
  # a disabled mod is an unfinished run and must stop.
  [switch]$AllowDisabledMods,
  # The ONE legitimate reason to walk past the UE4SS guard: a run that deliberately
  # tests something the Lua layer takes no part in (2026-09-12: the .locres translation
  # of the Hosav HUD, which the ENGINE loads, not UE4SS). Without this switch the guard
  # stands - it exists so a dead UE4SS is never mistaken for a broken mod pack.
  [switch]$AllowDeadUE4SS,
  [double]$FracX = 0.104,
  [double]$FracY = 0.402,
  # Which install to launch. 2026-10-02: a second install (a raw copy for the bundle
  # test) needed the same door, and the path was baked into four lines below.
  [string]$GameDir = $GameDir
)
. "$PSScriptRoot\game-target.ps1"   # install path from targets.json (2026-10-25)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$input_ps = Join-Path $here 'input.ps1'

$exe  = Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe'
$glog = Join-Path $GameDir 'ConanSandbox\Saved\Logs\ConanSandbox.log'
$ulog = Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\UE4SS.log'

Add-Type -AssemblyName System.Windows.Forms
Add-Type 'using System;using System.Runtime.InteropServices;public class DpiEW{[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();}'
$null = [DpiEW]::SetProcessDPIAware()

# GUARD: A MOD LEFT SWITCHED OFF MUST NEVER REACH A PLAY SESSION QUIETLY.
# Paid for 2026-09-11: shoot-vanilla.ps1 disables the camera mod to take the
# one frame that needs the game's own camera, the run was interrupted before
# its restore, and the next launch would have had no camera mod at all - with
# the symptom looking exactly like a broken build. Every door the agent uses
# to launch the game now NAMES this state instead of walking past it.
$modsDir = Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\Mods'
$disabled = @(Get-ChildItem -Path $modsDir -Filter 'enabled.txt.off' -Recurse -ErrorAction SilentlyContinue)
if ($disabled.Count -gt 0 -and -not $AllowDisabledMods) {
  $names = ($disabled | ForEach-Object { Split-Path (Split-Path $_.FullName -Parent) -Leaf }) -join ', '
  throw ("MOD LEFT DISABLED: $names. Some run switched it off and did not put it back. " +
         "Restore with _config\nexus\mod-on.ps1, then launch again.")
}

$started = Get-Date
if (-not (Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue)) {
  $null = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
  Write-Output ("[{0}] launched" -f (Get-Date -Format HH:mm:ss))
}

# GUARD: UE4SS DIES BEFORE ANY LUA MOD, AND THE SYMPTOM LOOKS LIKE OUR BUG.
# Paid for 2026-09-10: seven dead launches, ~2 hours of elimination testing, and
# the owner convinced the mod pack was broken - because the visible effect was
# "the offline modal is not hidden any more", which IS one of our mods.
#
# SOLVED 2026-09-12 (UE4SS issue #1421, maintainer's diagnosis): the alignment is
# fetched by calling a VIRTUAL function, and Conan Enhanced carries one extra
# virtual in FProperty, so UE4SS called the wrong slot and stored whatever that
# returned - a pointer on some launches (0x2684C788, 0x997C788, 0x74ABC788 - note
# the shared low bits), null on others, and null is the fatal.
#
# THE CURE IS ONE LINE, NOT A REBOOT: an 'Unknown_1' entry in VTableLayout.ini,
# section [FProperty], directly above GetMinAlignment. Proved A/B: with it
# 'FName Alignment' reads 0x4 (4 of 4 launches), without it the garbage returns.
# The earlier 'reboot' advice was a coincidence and is retired (EXP-0091).
#
# The guard STAYS: if this line ever comes back, the shipped VTableLayout.ini has
# been restored over ours, or the game moved its vtable again after a patch.
function Assert-UE4SSAlive([string]$Path) {
  if (-not (Test-Path $Path)) { return }
  if ((Get-Item $Path).LastWriteTime -lt $started) { return }
  if (Select-String -Path $Path -Pattern 'StaticAlignment_Private is not valid' -Quiet -ErrorAction SilentlyContinue) {
    throw ('UE4SS DIED ON ITS OWN INIT (FName::StaticAlignment). This is NOT the mod pack ' +
           'and NOT a recent edit - it fails before any Lua mod exists. ' +
           'CURE: VTableLayout.ini, section [FProperty], needs the Unknown_1 line directly ' +
           'above GetMinAlignment - check it is still there. Upstream accepted this line on ' +
           '2026-09-12 (commit 3fe75235), so a CURRENT UE4SS ships it; only an update to a ' +
           'build older than that fix can wipe it. ' +
           'Details: bugs/10 in KUMM, UE4SS issue #1421.')
  }
}

function Log-Has([string]$Path, [string]$Pattern) {
  if (-not (Test-Path $Path)) { return $false }
  if ((Get-Item $Path).LastWriteTime -lt $started) { return $false }
  return [bool](Select-String -Path $Path -Pattern $Pattern -Quiet -ErrorAction SilentlyContinue)
}

$sw = [Diagnostics.Stopwatch]::StartNew()
$clicks = 0
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  if (-not $AllowDeadUE4SS) { Assert-UE4SSAlive $ulog }

  if (Log-Has $glog 'LoadMap\(/Game/Maps/ConanSandbox/ConanSandbox\)') {
    $sw.Stop()
    Write-Output ("[{0}] in the world after {1:n0} s and {2} click(s)" -f `
      (Get-Date -Format HH:mm:ss), $sw.Elapsed.TotalSeconds, $clicks)
    exit 0
  }

  if (-not (Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue)) {
    throw 'the game process is gone - it aborted before we got in'
  }

  if (Log-Has $glog 'LoadMap\(/Game/Maps/Startup\)') {
    $p = Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue |
         Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($p) {
      $vs = [Windows.Forms.SystemInformation]::VirtualScreen
      $xy = "{0},{1}" -f [int]($vs.Width * $FracX), [int]($vs.Height * $FracY)
      try {
        & $input_ps -Click $xy | Out-Null
        $clicks++
        Write-Output ("[{0}] click #{1} at {2} (screen {3}x{4})" -f `
          (Get-Date -Format HH:mm:ss), $clicks, $xy, $vs.Width, $vs.Height)
      } catch {
        Write-Output ("[{0}] click refused: {1}" -f (Get-Date -Format HH:mm:ss), $_.Exception.Message)
      }
    }
  }
  Start-Sleep -Seconds 5
}

$sw.Stop()
throw ("never reached the world in {0} s ({1} clicks tried)" -f $TimeoutSec, $clicks)
