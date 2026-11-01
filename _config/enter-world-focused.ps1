# enter-world-focused.ps1 -- after the game is launched: bring its window to the front and click CONTINUE
# until the world loads. ASCII-only (PowerShell 5.1 reads BOM-less scripts as ANSI).
# Why: 13.09 22:00 a click landed in VS Code - SetForegroundWindow from a background process is refused
# by Windows unless the calling thread just received input; a tap of ALT satisfies that rule.
param([int]$TimeoutSec = 240, [double]$FracX = 0.104, [double]$FracY = 0.402)
. "$PSScriptRoot\game-target.ps1"   # install path from targets.json (2026-10-25)
$glog = (Join-Path $GameDir 'ConanSandbox\Saved\Logs\ConanSandbox.log')
# Launch moment = start time of the running game process (the log is fresh only after it).
$gp = Get-Process ConanSandbox-Win64-Shipping, ConanSandbox -ErrorAction SilentlyContinue | Sort-Object StartTime | Select-Object -First 1
if (-not $gp) { 'game is not running - launch it first: Start-Process $GameDir\ConanSandbox.exe'; exit 3 }
$launch = $gp.StartTime
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Fg {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@
function Has([string]$p) { (Test-Path $glog) -and ((Get-Item $glog).LastWriteTime -gt $launch) -and (Select-String -LiteralPath $glog -Pattern $p -Quiet) }
$sw = [Diagnostics.Stopwatch]::StartNew(); $clicks = 0
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  if (Has 'LoadMap\(/Game/Maps/ConanSandbox/ConanSandbox\)') { "in the world after $([int]$sw.Elapsed.TotalSeconds) s, clicks $clicks"; exit 0 }
  if (Has 'Fatal error') { "FATAL in game log"; exit 2 }
  $p = Get-Process ConanSandbox-Win64-Shipping -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($p -and (Has 'LoadMap\(/Game/Maps/Startup')) {
    [Fg]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [Fg]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [Fg]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    [Fg]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 700
    $front = [Fg]::GetForegroundWindow() -eq $p.MainWindowHandle
    $vs = [Windows.Forms.SystemInformation]::VirtualScreen
    $xy = "{0},{1}" -f [int]($vs.Width * $FracX), [int]($vs.Height * $FracY)
    if ($front) { & 'D:\work\ai_sandbox\ConanExiles\_config\input.ps1' -Click $xy | Out-Null; $clicks++ }
    "t=$([int]$sw.Elapsed.TotalSeconds)s front=$front click=$xy screen=$($vs.Width)x$($vs.Height)"
  }
  Start-Sleep -Seconds 5
}
"never reached the world, clicks $clicks"; exit 1

# [TESTED: 2026-09-13 22:54-23:12 - focus+click loop: four launches, in the world after 58-83 s every time (the old plain click landed in VS Code)]
# [TESTED: 2026-09-13 23:15 - this very file: launch moment from the process StartTime, in the world after 83 s]
