# hover-watch.ps1 -- hover a point of the game with the REAL cursor and record the screen around it, frame by frame.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY (2026-10-29, KUMM bug 64 item 17 class A): the owner sees an item tooltip open in one line and then jump to two
# ("Otkryvayutsya v odnu stroku, a zatem stanovyatsya v dve"). The remote cannot hover (Slate reads the real cursor), and
# PrintWindow of a background game never shows a hover tooltip. In full screen the tooltip is NOT a window of its own
# (2026-10-29 21:14: no second window of the process appeared during a hover) - it is drawn inside the game window.
# So: this script brings the game to the front (no wait for the owner's input idle since the owner cancelled the busy-keyboard rules 2026-11-20 19:37),
# moves the cursor by SendInput (absolute, DPI-free), grabs a screen region right-down of the cursor as fast as GDI allows
# (frames kept in memory, saved after), then hands the foreground back. tooltip-bbox.py turns the frames into the
# tooltip's rectangle per frame - the width over time IS the measurement.
#
#   .\hover-watch.ps1 -At 0.1734/0.424 -Dir D:\tmp\hw1
#   -At: fractions of the primary screen (x/y, 0..1); -Away: where the cursor waits first (an empty strip)
#   -Box: region in screen pixels, left/up offset from the cursor and size: "-150/-120/1500/900"
# Output: f_<ms>.jpg per frame (ms from the move), and a summary line.
# [TESTED: 2026-10-29 · first version (window polling) ran on the live game at 21:14: the game came to the front, the cursor moved,
#  the foreground came back; it found no tooltip window -> this region version]
param(
  [Parameter(Mandatory = $true)][string]$At,
  [Parameter(Mandatory = $true)][string]$Dir,
  [int]$WatchMs = 1500,
  [string]$Away = '0.5/0.6',
  [int]$AwayMs = 700,
  [string]$Box = '-150/-120/1500/900',
  [int]$MaxFrames = 260,
  [string]$Process = 'ConanSandbox-Win64-Shipping',
  [switch]$KeepFront,
  # -PultCmd: instead of moving the cursor to -At, write this line to the KrinikAgentRemote cmd.txt at t=0 (e.g. a hub tab switch); -At is then
  # only the anchor of -Box and the cursor stays at -Away. Added 2026-10-29 for the hub bottom bar (the owner: "knizu knopki prygayut").
  [string]$PultCmd = '',
  [string]$PultFile = ''   # default: the remote's cmd.txt in the first enabled target of targets.json (2026-11-13)
)
$ErrorActionPreference = 'Stop'
if (-not $PultFile) { . (Join-Path $PSScriptRoot 'game-target.ps1'); $PultFile = Join-Path $GameDir 'ConanSandbox\Binaries\Win64\ue4ss\Mods\KrinikAgentRemote\cmd.txt' }
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class HW {
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public int mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }   // 40 bytes on x64 = sizeof(INPUT)
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void MoveTo(double fx, double fy) {
    INPUT[] a = new INPUT[1]; a[0].type = 0;
    a[0].mi.dx = (int)(fx * 65535); a[0].mi.dy = (int)(fy * 65535);
    a[0].mi.dwFlags = 0x0001 | 0x8000;   // MOVE | ABSOLUTE (0..65535 of the primary screen, no DPI arithmetic)
    SendInput(1, a, Marshal.SizeOf(typeof(INPUT)));
  }
}
"@
$inv = [Globalization.CultureInfo]::InvariantCulture
function Frac([string]$s) { $p = $s -split '/'; return @([double]::Parse($p[0], $inv), [double]::Parse($p[1], $inv)) }

$null = [HW]::SetProcessDPIAware()
$sw0 = [HW]::GetSystemMetrics(0); $sh0 = [HW]::GetSystemMetrics(1)
$game = Get-Process $Process -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $game) { throw "no window for $Process" }
New-Item -ItemType Directory -Force $Dir | Out-Null
$pt = Frac $At; $aw = Frac $Away
$b = $Box -split '/' | ForEach-Object { [int]$_ }
$x0 = [Math]::Max(0, [int]($pt[0] * $sw0) + $b[0]); $y0 = [Math]::Max(0, [int]($pt[1] * $sh0) + $b[1])
$bw = [Math]::Min($b[2], $sw0 - $x0); $bh = [Math]::Min($b[3], $sh0 - $y0)

$prev = [HW]::GetForegroundWindow()
[HW]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [HW]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)   # ALT tap: the documented way past the foreground lock
[void][HW]::SetForegroundWindow($game.MainWindowHandle)
[HW]::MoveTo($aw[0], $aw[1])
Start-Sleep -Milliseconds $AwayMs

$frames = New-Object System.Collections.ArrayList
$stamps = New-Object System.Collections.ArrayList
$size = New-Object Drawing.Size $bw, $bh
$sw = [Diagnostics.Stopwatch]::StartNew()
if ($PultCmd) { [IO.File]::WriteAllText($PultFile, $PultCmd + "`n") } else { [HW]::MoveTo($pt[0], $pt[1]) }
while ($sw.ElapsedMilliseconds -lt $WatchMs -and $frames.Count -lt $MaxFrames) {
  $ms = $sw.ElapsedMilliseconds
  $bmp = New-Object Drawing.Bitmap $bw, $bh, ([Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x0, $y0, 0, 0, $size)
  $g.Dispose()
  [void]$frames.Add($bmp); [void]$stamps.Add($ms)
}
$total = $sw.ElapsedMilliseconds
[HW]::MoveTo($aw[0], $aw[1])
if (-not $KeepFront) { [void][HW]::SetForegroundWindow($prev) }
for ($i = 0; $i -lt $frames.Count; $i++) {
  $frames[$i].Save((Join-Path $Dir ('f_{0:D5}.jpg' -f $stamps[$i])), [Drawing.Imaging.ImageFormat]::Jpeg)
  $frames[$i].Dispose()
}
'frames={0} in {1} ms, box {2},{3} {4}x{5} of {6}x{7}' -f $frames.Count, $total, $x0, $y0, $bw, $bh, $sw0, $sh0
