# run-camera-test.ps1 -- one repeatable camera experiment, start to finish.
#
# ASCII-ONLY ON PURPOSE: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHAT IT DOES, in order:
#   launch -> wait for the main menu -> click CONTINUE -> wait for the world ->
#   settle -> BASELINE burst (no input) -> wheel to max zoom -> ZOOM burst ->
#   close the game cleanly.
#
# WHY A SCRIPT AND NOT COMMANDS BY HAND. The experiment gets repeated once per
# hypothesis, and a hand-typed sequence drifts between runs - which is exactly
# what makes two measurements incomparable. Owner's ask 2026-09-09: the agent
# runs these itself, the owner does not launch the game six times an evening.
#
# THE BASELINE BURST IS NOT OPTIONAL. In Conan the sea, the foliage and the
# character's idle animation move on their own; without a no-input burst from
# the SAME spot, the zoom numbers mean nothing.
#
#   .\run-camera-test.ps1 -Label with-immwar
#   .\run-camera-test.ps1 -Label no-immwar -OutRoot C:\tmp\cam

param(
  [Parameter(Mandatory = $true)][string]$Label,
  [string]$OutRoot = "$PSScriptRoot\..\_scratch\conan-cam",   # the pack's ignored _scratch, not %TEMP% (D:\Temp is the owner's, 2026-11-13)
  [int]$Frames = 30,
  [double]$Fps = 8,
  [int]$Width = 640,
  [int]$WheelNotches = 12,
  # The CONTINUE button as a FRACTION of the screen, never as pixels.
  # Paid for 2026-09-09: the TV falls asleep between runs, the game then opens
  # on the 1280x800 virtual display, and a coordinate computed for 3840x2160
  # lands off-screen entirely - three runs in a row clicked nothing and were
  # written off as "the world never loaded". The menu is anchored and scales,
  # so the fraction holds: measured 0.104/0.402 at 4K and again at 1280x800.
  [double]$ContinueFracX = 0.104,
  [double]$ContinueFracY = 0.402
)
. "$PSScriptRoot\game-target.ps1"   # install path from targets.json (2026-10-25)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$input_ps = Join-Path $here 'input.ps1'
$capture   = Join-Path $here 'capture.ps1'
$closeGame = Join-Path $here 'close-game.ps1'

$exe  = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe')
$glog = (Join-Path $GameDir 'ConanSandbox\Saved\Logs\ConanSandbox.log')
$ulog = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\UE4SS.log')

$out = Join-Path $OutRoot $Label
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
$null = New-Item -ItemType Directory -Path $out -Force

function Wait-ForLine([string]$Path, [string]$Pattern, [int]$TimeoutSec, [datetime]$After) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
    if (Test-Path $Path) {
      $f = Get-Item $Path
      if ($f.LastWriteTime -ge $After) {
        if (Select-String -Path $Path -Pattern $Pattern -Quiet -ErrorAction SilentlyContinue) {
          $sw.Stop(); return $true
        }
      }
    }
    Start-Sleep -Milliseconds 700
  }
  $sw.Stop(); return $false
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type 'using System;using System.Runtime.InteropServices;public class Dpi2{[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();}'
$null = [Dpi2]::SetProcessDPIAware()

# СНИМОК НАСТРОЕК ВЛАДЕЛЬЦА ПЕРЕД ОПЫТОМ.
# Мод камеры сохраняет себя САМ, через 1200 мс после нажатия клавиши - а опыт
# жмёт клавиши дистанции и высоты десятками. 09.09.2026 настройки владельца
# (offset_x -130, offset_z 50, arm_length 230, подбирались два вечера) уцелели
# только потому, что следующая раскатка случайно затёрла файл пакетным. Это
# везение, а не защита. Здесь - защита.
$modCfg = (Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\Mods\KrinikConanCamera\config.lua')
$cfgBackup = Join-Path $out 'config.lua.before'
if (Test-Path $modCfg) {
  Copy-Item $modCfg $cfgBackup -Force
  Write-Output ("snapshot of the owner's camera config -> {0}" -f $cfgBackup)
}

# ИГРА ЗАКРЫВАЕТСЯ ВСЕГДА, В ТОМ ЧИСЛЕ ПРИ ОШИБКЕ.
# Владелец сидит на УДАЛЁННОМ РАБОЧЕМ СТОЛЕ: полноэкранная игра, оставленная
# запущенной, отбирает у него экран целиком. 09.09.2026 он выбирался в VS Code
# через диспетчер задач - "еле-еле добрался". Прогон, упавший в середине,
# оставлял игру висеть, и это не мелочь, а потеря управления машиной.
trap {
  Write-Output 'run failed - closing the game anyway (the owner is on a remote desktop)'
  try { & $closeGame | Out-Null } catch { }
  break
}

$started = Get-Date
Write-Output ("[{0}] run '{1}'" -f $started.ToString('HH:mm:ss'), $Label)

if (Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue) {
  Write-Output 'game already running - closing it first'
  & $closeGame | Out-Null
}

$null = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru
Write-Output 'launched; waiting for the loader'

if (-not (Wait-ForLine $ulog 'Event loop start' 120 $started)) {
  throw 'UE4SS never reached "Event loop start" - the Lua layer is down, stop here'
}
Write-Output 'UE4SS up (Event loop start)'

if (-not (Wait-ForLine $glog 'LoadMap\(/Game/Maps/Startup\)' 180 $started)) {
  throw 'the game never loaded its startup map'
}
# The menu builds itself for a few seconds after the map is loaded.
Start-Sleep -Seconds 12
& $capture -Out (Join-Path $out 'menu.png') -Width 960 | Out-Null

$vs = [Windows.Forms.SystemInformation]::VirtualScreen
$ContinueAt = "{0},{1}" -f [int]($vs.Width * $ContinueFracX), [int]($vs.Height * $ContinueFracY)
Write-Output ("screen {0}x{1} -> CONTINUE at {2}" -f $vs.Width, $vs.Height, $ContinueAt)
& $input_ps -Move $ContinueAt | Out-Null
Start-Sleep -Milliseconds 500
& $capture -Out (Join-Path $out 'menu-hover.png') -Width 960 | Out-Null
& $input_ps -Click $ContinueAt | Out-Null
Write-Output ('clicked CONTINUE at ' + $ContinueAt)

if (-not (Wait-ForLine $glog 'LoadMap\(/Game/Maps/ConanSandbox/ConanSandbox\)' 240 $started)) {
  # Say WHY, not just "timed out": the two causes look identical from here.
  $stuck = Select-String -Path $glog -Pattern 'Precompiles Remaining: (\d+)' |
           Select-Object -Last 1
  if ($stuck) { Write-Output ('last PSO line: ' + $stuck.Line.Trim()) }
  & $capture -Out (Join-Path $out 'stuck.png') -Width 960 | Out-Null
  throw ('the world never finished loading - look at ' + (Join-Path $out 'stuck.png'))
}
Write-Output 'world loaded; settling'
Start-Sleep -Seconds 12
& $capture -Out (Join-Path $out 'world.png') -Width 960 | Out-Null

Write-Output 'BASELINE burst (no input at all)'
& $capture -Out (Join-Path $out 'burst-baseline') -Frames $Frames -Fps $Fps -Width $Width | Out-Null

Write-Output ('wheel out {0} notches, then ZOOM burst' -f $WheelNotches)
& $input_ps -Wheel (-1 * $WheelNotches) | Out-Null
Start-Sleep -Seconds 2
& $capture -Out (Join-Path $out 'zoom.png') -Width 960 | Out-Null
& $capture -Out (Join-Path $out 'burst-zoom') -Frames $Frames -Fps $Fps -Width $Width | Out-Null

# The camera mod's own numbers: copy the log BEFORE closing, the next run wipes it.
Copy-Item $ulog (Join-Path $out 'UE4SS.log') -Force

& $closeGame | Out-Null

# Возврат настроек владельца. Сравниваем и говорим ВСЛУХ, если мод их менял -
# молчаливое восстановление скрыло бы факт, что опыт трогает чужое.
if ((Test-Path $cfgBackup) -and (Test-Path $modCfg)) {
  $a = (Get-Content $cfgBackup -Raw)
  $b = (Get-Content $modCfg -Raw)
  if ($a -ne $b) {
    Copy-Item $cfgBackup $modCfg -Force
    Write-Output 'ATTENTION: the mod rewrote the camera config during the run - restored from the snapshot'
  } else {
    Write-Output "the owner's camera config is untouched"
  }
}
Write-Output ("done -> {0}" -f $out)
