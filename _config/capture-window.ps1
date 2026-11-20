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
#   .\capture-window.ps1 -Out C:\tmp\kumm.jpg -Width 1920 -Title 'KUMM - Visual Studio Code'
#     -Title: the visible top-level window whose title STARTS with this text (one process may own several windows - VS Code with four
#     projects: the process's main window is whichever it names, KUMM plan 54 / auto-relay 2026-11-17 15:21).
# [NOT-TESTED]

param(
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Width = 1280,
  [string]$Process = 'ConanSandbox-Win64-Shipping',
  [string]$Title
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
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
  public static IntPtr ByTitle(string prefix) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var s = new System.Text.StringBuilder(512); GetWindowText(h, s, 512);
      if (!s.ToString().StartsWith(prefix, StringComparison.Ordinal)) return true;
      found = h; return false;
    }, IntPtr.Zero);
    return found;
  }
}
'@
$null = [CapWin]::SetProcessDPIAware()

if ($Title) {
  $hwnd = [CapWin]::ByTitle($Title)
  if ($hwnd -eq [IntPtr]::Zero) { throw "no visible window titled '$Title...'" }
} else {
  $p = Get-Process -Name $Process -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { throw "no window for $Process" }
  $hwnd = $p.MainWindowHandle
}
$r = New-Object CapWin+RECT
$null = [CapWin]::GetClientRect($hwnd, [ref]$r)
$w = $r.R - $r.L; $h = $r.B - $r.T
if ($w -le 0 -or $h -le 0) { throw "window has no client area ($w x $h) - minimized?" }

$full = New-Object Drawing.Bitmap $w, $h
$g = [Drawing.Graphics]::FromImage($full)
$hdc = $g.GetHdc()
$ok = [CapWin]::PrintWindow($hwnd, $hdc, 2)
$g.ReleaseHdc($hdc)

$outH = [int]($h * $Width / $w)
$small = New-Object Drawing.Bitmap $Width, $outH
$gs = [Drawing.Graphics]::FromImage($small)
$gs.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gs.DrawImage($full, 0, 0, $Width, $outH)
$small.Save($Out, [Drawing.Imaging.ImageFormat]::Jpeg)
$gs.Dispose(); $small.Dispose(); $g.Dispose(); $full.Dispose()
Write-Output ("PrintWindow={0} window {1}x{2} -> {3}" -f $ok, $w, $h, $Out)
