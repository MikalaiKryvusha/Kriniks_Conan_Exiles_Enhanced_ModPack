# capture-burst.ps1 -- a SERIES of frames of the game window while it stays in the background (a clip without the screen).
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY (2026-10-26, KUMM bugs/64 items 15-17, plan 35 B4): the owner sees the hub "dance" on Q/E and mod elements appear late. A clip is
# needed (HOUSE_RULES: smoke of UI - with video), but rec_clip.sh records the SCREEN, i.e. the owner's browser. PrintWindow with
# PW_RENDERFULLCONTENT reads the game window's own surface; one process keeps the bitmaps and the handle, so frames come fast.
# File names carry milliseconds since the burst start: f_<ms>.jpg; start time (unix ms) is printed first, to align with pult commands.
#
#   .\capture-burst.ps1 -Dir C:\tmp\burst -Count 30 -IntervalMs 100 -Width 1280
# [NOT-TESTED]

param(
  [Parameter(Mandatory = $true)][string]$Dir,
  [int]$Count = 30,
  [int]$IntervalMs = 100,
  [int]$Width = 1280,
  [string]$Process = 'ConanSandbox-Win64-Shipping'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class CapBurst {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
}
'@
$null = [CapBurst]::SetProcessDPIAware()
$p = Get-Process -Name $Process -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { throw "no window for $Process" }
$hwnd = $p.MainWindowHandle
$r = New-Object CapBurst+RECT
$null = [CapBurst]::GetClientRect($hwnd, [ref]$r)
$w = $r.R - $r.L; $h = $r.B - $r.T
if ($w -le 0 -or $h -le 0) { throw "window has no client area ($w x $h) - minimized?" }
New-Item -ItemType Directory -Force $Dir | Out-Null

$full = New-Object Drawing.Bitmap $w, $h
$g = [Drawing.Graphics]::FromImage($full)
$outH = [int]($h * $Width / $w)
$small = New-Object Drawing.Bitmap $Width, $outH
$gs = [Drawing.Graphics]::FromImage($small)
$gs.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::Bilinear
$sw = [Diagnostics.Stopwatch]::StartNew()
$t0 = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
Write-Output ("start_unix_ms={0}" -f $t0)
for ($i = 0; $i -lt $Count; $i++) {
  $due = $i * $IntervalMs
  while ($sw.ElapsedMilliseconds -lt $due) { Start-Sleep -Milliseconds 5 }
  $ms = $sw.ElapsedMilliseconds
  $hdc = $g.GetHdc()
  $null = [CapBurst]::PrintWindow($hwnd, $hdc, 2)
  $g.ReleaseHdc($hdc)
  $gs.DrawImage($full, 0, 0, $Width, $outH)
  $small.Save((Join-Path $Dir ("f_{0:D6}.jpg" -f $ms)), [Drawing.Imaging.ImageFormat]::Jpeg)
}
$gs.Dispose(); $small.Dispose(); $g.Dispose(); $full.Dispose()
Write-Output ("frames={0} in {1} ms ({2}x{3} -> {4} wide)" -f $Count, $sw.ElapsedMilliseconds, $w, $h, $Width)
