# launch-bg.ps1 -- start the game and hand the foreground straight back to the owner.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY. Owner's word 2026-10-25: "snimai v bekgraunde skrinshoty i tam vzaimodeistvui -
# chtoby ya mog v brauzere rabotat', a ty s igroi". A fresh game process takes the
# foreground when its window appears (and again when it goes fullscreen), covering
# whatever the owner works in. This script remembers the window that was in front,
# starts the game, and keeps giving the foreground back for a while.
# Screenshots and actions then go through the KrinikAgentRemote mod, never through focus.
#
# TWO PATHS (owner's word 2026-10-30 15:3x "sdelai dva puti: rabota s igroi v foregraunde i rabota
# s igroi v fone" / "inogda ya tak hochu, inogda inache" / "ty dolzhen umet' i tak i tak").
# THIS script is the BACKGROUND path; the FOREGROUND path is launch-fg.ps1. Which one - the
# owner's current word; both must carry the agent's work, tests included.
#
#   .\launch-bg.ps1
#   .\launch-bg.ps1 -GameDir '<game folder>' -HoldSec 40   (default: the first enabled target of targets.json)
# [NOT-TESTED]

param(
  [string]$GameDir = '',
  [int]$HoldSec = 40,
  # e.g. '-continuesession' - the launcher's own "Continue": straight into the last session, no menu clicks
  [string]$GameArgs = ''
)

$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class FgBG {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@

if (-not $GameDir) { . (Join-Path $PSScriptRoot 'game-target.ps1') }   # the first enabled target of targets.json (2026-11-13, KUMM plan 53)
$exe = Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe'
# ONE GAME AT A TIME - the twin of the guard in launch-fg.ps1 (paid 2026-10-30 15:29).
$running = @(Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue)
if ($running.Count) { Write-Output ("game already running, PID {0} - close it first (by PID)" -f (($running | ForEach-Object { $_.Id }) -join ', ')); exit 2 }
$prev = [FgBG]::GetForegroundWindow()
# The moment of the agent's launch: close-crash-reporter.ps1 closes only reporters started after it (HOUSE_RULES par. 1, 2026-10-26).
$scratch = Join-Path (Split-Path $PSScriptRoot -Parent) '_scratch'; if (-not (Test-Path $scratch)) { $null = New-Item -ItemType Directory $scratch }
# the stamp lives in the pack's ignored _scratch, not %TEMP% (D:\Temp is the owner's folder, KUMM HOUSE_RULES rule 15, 2026-11-13)
Set-Content -Path (Join-Path $scratch 'kumm-conan-agent-launch.txt') -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding ASCII
if ($GameArgs) { $proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -ArgumentList $GameArgs -PassThru }
else { $proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru }
Write-Output ("[{0}] launched (background path), PID {1}, owner window 0x{2:X}" -f (Get-Date -Format HH:mm:ss), $proc.Id, $prev.ToInt64())

# Give the foreground back every half second while the game settles. The ALT tap is the
# documented way to let a background process call SetForegroundWindow at all.
$VK_MENU = 0x12; $KEYUP = 2
# ONLY THE GAME'S OWN WINDOW IS PUSHED BACK. Paid for 2026-10-25 09:39: the first version
# reclaimed the foreground from ANY window, so when the owner switched windows himself it
# fought him 42 times in 45 s. The owner moving between his windows is his business.
$returns = 0
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $HoldSec) {
  $fg = [FgBG]::GetForegroundWindow()
  $game = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
  if ($game -and $fg -eq $game.MainWindowHandle) {
    [FgBG]::keybd_event($VK_MENU, 0, 0, [UIntPtr]::Zero)
    [FgBG]::keybd_event($VK_MENU, 0, $KEYUP, [UIntPtr]::Zero)
    $null = [FgBG]::SetForegroundWindow($prev)
    $returns++
  }
  Start-Sleep -Milliseconds 500
}
Write-Output ("[{0}] foreground returned {1} time(s); now 0x{2:X}" -f (Get-Date -Format HH:mm:ss), $returns, [FgBG]::GetForegroundWindow().ToInt64())
