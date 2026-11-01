# capture-window.ps1 -- grab the GAME WINDOW's own content while it stays in the background.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY. Owner's word 2026-10-25: "snimai v bekgraunde skrinshoty i tam vzaimodeistvui -
# chtoby ya mog v brauzere rabotat', a ty s igroi". capture.ps1 copies the SCREEN, so it
# photographs whatever is in front (the browser, VS Code). PrintWindow with
# PW_RENDERFULLCONTENT (2) asks DWM for the window's own surface, covered or not.
# Writes JPEG (KUMM canon: never PNG; System.Drawing cannot write WebP).
#
#   .\capture-window.ps1 -Out C:\tmp\menu.jpg
#   .\capture-window.ps1 -Out C:\tmp\menu.jpg -Width 1920
# [NOT-TESTED]

param(
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Width = 1280,
  [string]$Process = 'ConanSandbox-Win64-Shipping'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class CapWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
}
'@
$null = [CapWin]::SetProcessDPIAware()

$p = Get-Process -Name $Process -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { throw "no window for $Process" }
$r = New-Object CapWin+RECT
$null = [CapWin]::GetClientRect($p.MainWindowHandle, [ref]$r)
$w = $r.R - $r.L; $h = $r.B - $r.T
if ($w -le 0 -or $h -le 0) { throw "window has no client area ($w x $h) - minimized?" }

$full = New-Object Drawing.Bitmap $w, $h
$g = [Drawing.Graphics]::FromImage($full)
$hdc = $g.GetHdc()
$ok = [CapWin]::PrintWindow($p.MainWindowHandle, $hdc, 2)
$g.ReleaseHdc($hdc)

$outH = [int]($h * $Width / $w)
$small = New-Object Drawing.Bitmap $Width, $outH
$gs = [Drawing.Graphics]::FromImage($small)
$gs.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gs.DrawImage($full, 0, 0, $Width, $outH)
$small.Save($Out, [Drawing.Imaging.ImageFormat]::Jpeg)
$gs.Dispose(); $small.Dispose(); $g.Dispose(); $full.Dispose()
Write-Output ("PrintWindow={0} window {1}x{2} -> {3}" -f $ok, $w, $h, $Out)
