# capture.ps1 -- DPI-aware screen capture for the agent: one frame or a burst.
#
# ASCII-ONLY ON PURPOSE: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY NOT shot.ps1. That one does not declare DPI awareness, so on this machine
# (4K TV at 300% scaling) Windows hands it 1280x720 coordinates and it grabs a
# CROP of the top-left corner instead of the screen. Measured 2026-09-09.
#
# WHY DOWNSCALED. Owner's instruction 2026-09-09: "low resolution, low frame
# rate, delete the video after yourself". A 4K PNG is ~10 MB and useless to
# read; 960px wide is enough to see whether the camera moved, and a burst of
# them IS the video - individual frames are what gets looked at anyway.
#
#   .\capture.ps1 -Out shot.png
#   .\capture.ps1 -Out C:\tmp\burst -Frames 40 -Fps 8      burst into a folder
#   .\capture.ps1 -Out shot.png -Width 1920                sharper single frame

param(
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Frames = 1,
  [double]$Fps = 8,
  [int]$Width = 960
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Dpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@
$null = [Dpi]::SetProcessDPIAware()

$vs = [Windows.Forms.SystemInformation]::VirtualScreen
$scale = $Width / $vs.Width
$outW = $Width
$outH = [int][Math]::Round($vs.Height * $scale)

if ($Frames -gt 1) {
  if (-not (Test-Path $Out)) { $null = New-Item -ItemType Directory -Path $Out }
}

$full = New-Object Drawing.Bitmap $vs.Width, $vs.Height
$g = [Drawing.Graphics]::FromImage($full)
$small = New-Object Drawing.Bitmap $outW, $outH
$gs = [Drawing.Graphics]::FromImage($small)
$gs.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear

$delayMs = [int][Math]::Round(1000 / $Fps)
$sw = [Diagnostics.Stopwatch]::StartNew()

for ($i = 0; $i -lt $Frames; $i++) {
  $target = $i * $delayMs
  while ($sw.ElapsedMilliseconds -lt $target) { Start-Sleep -Milliseconds 2 }

  $g.CopyFromScreen($vs.X, $vs.Y, 0, 0, $full.Size)
  $gs.DrawImage($full, 0, 0, $outW, $outH)

  # JPEG, not PNG: KUMM canon 2026-10-04 "PNG never" - WebP first, JPEG where the tool
  # cannot write WebP (System.Drawing cannot). A .png path is still honoured for old callers.
  if ($Frames -gt 1) {
    $path = Join-Path $Out ("f{0:d3}.jpg" -f $i)
  } else {
    $path = $Out
  }
  if ($path -match '\.png$') {
    $small.Save($path, [Drawing.Imaging.ImageFormat]::Png)
  } else {
    $small.Save($path, [Drawing.Imaging.ImageFormat]::Jpeg)
  }
}

$sw.Stop()
$gs.Dispose(); $small.Dispose(); $g.Dispose(); $full.Dispose()

Write-Output ("captured {0} frame(s) at {1}x{2} from a {3}x{4} screen in {5} ms -> {6}" -f `
  $Frames, $outW, $outH, $vs.Width, $vs.Height, $sw.ElapsedMilliseconds, $Out)
