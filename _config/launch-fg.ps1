# launch-fg.ps1 -- start the game and bring its window to the FRONT (the foreground path).
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# TWO PATHS (owner's word 2026-10-30 15:3x "sdelai dva puti: rabota s igroi v foregraunde i rabota
# s igroi v fone" / "inogda ya tak hochu, inogda inache" / "ty dolzhen umet' i tak i tak").
# THIS script is the FOREGROUND path; the BACKGROUND path is launch-bg.ps1. Which one - the
# owner's current word; both must carry the agent's work, tests included.
#
# The game window is pulled to the front once it appears and until it has HELD the front for
# $SettleSec (the fullscreen switch can drop it once). After that it never fights: when the owner
# moves to another window himself, that is his business (the 2026-10-25 lesson of launch-bg.ps1).
#
#   .\launch-fg.ps1
#   .\launch-fg.ps1 -GameDir '<game folder>' -HoldSec 60   (default: the first enabled target of targets.json)
# [NOT-TESTED]

param(
  [string]$GameDir = '',
  [int]$HoldSec = 60,
  [int]$SettleSec = 3,
  [string]$GameArgs = '',
  [switch]$OwnerAsked   # the agent's mark 'the owner asked for the game': the KUMM hook owner-presence checks his words (tools/hooks/.owner-ask.txt); the script itself ignores it
)

$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class FgFG {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@

if (-not $GameDir) { . (Join-Path $PSScriptRoot 'game-target.ps1') }   # the first enabled target of targets.json (2026-11-13, KUMM plan 53)
$exe = Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe'
# ONE GAME AT A TIME. Paid 2026-10-30 15:29: a launch interrupted by the owner had left a game running
# (the check looked for "ConanSandbox.exe" - the process is ConanSandbox-Win64-Shipping), a second
# launch started beside it and the first one's window was pulled to the front.
$running = @(Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue)
if ($running.Count) { Write-Output ("game already running, PID {0} - close it first (by PID)" -f (($running | ForEach-Object { $_.Id }) -join ', ')); exit 2 }
# The moment of the agent's launch: close-crash-reporter.ps1 closes only reporters started after it (HOUSE_RULES par. 1, 2026-10-26).
$scratch = Join-Path (Split-Path $PSScriptRoot -Parent) '_scratch'; if (-not (Test-Path $scratch)) { $null = New-Item -ItemType Directory $scratch }
# the stamp lives in the pack's ignored _scratch, not %TEMP% (D:\Temp is the owner's folder, KUMM HOUSE_RULES rule 15, 2026-11-13)
Set-Content -Path (Join-Path $scratch 'kumm-conan-agent-launch.txt') -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding ASCII
if ($GameArgs) { $proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -ArgumentList $GameArgs -PassThru }
else { $proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru }
Write-Output ("[{0}] launched (foreground path), PID {1}" -f (Get-Date -Format HH:mm:ss), $proc.Id)

$VK_F24 = 0x87; $KEYUP = 2; $SW_RESTORE = 9
$pulls = 0; $heldMs = 0
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $HoldSec -and $heldMs -lt ($SettleSec * 1000)) {
  $game = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
  if ($game) {
    if ([FgFG]::GetForegroundWindow() -eq $game.MainWindowHandle) { $heldMs += 500 }
    else {
      # A key tap is the documented way to let a background process call SetForegroundWindow at all. F24, not Alt: Alt lands in the
      # owner's window first (VS Code opens its menu) and Alt is the game's dodge - the game-front.ps1 rule of 2026-11-07 (judges 2026-11-13).
      $heldMs = 0
      [FgFG]::keybd_event($VK_F24, 0, 0, [UIntPtr]::Zero)
      [FgFG]::keybd_event($VK_F24, 0, $KEYUP, [UIntPtr]::Zero)
      $null = [FgFG]::ShowWindow($game.MainWindowHandle, $SW_RESTORE)
      $null = [FgFG]::SetForegroundWindow($game.MainWindowHandle)
      $pulls++
    }
  }
  Start-Sleep -Milliseconds 500
}
$game = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
$front = ($game -and [FgFG]::GetForegroundWindow() -eq $game.MainWindowHandle)
Write-Output ("[{0}] pulled to front {1} time(s); game in front: {2}" -f (Get-Date -Format HH:mm:ss), $pulls, $front)
if (-not $front) { exit 1 }
