# Extract the largest icon images of the Conan Exiles exe (read-only on the game folder; output into the scratchpad).
param([string]$Exe = '', [string]$Out = 'D:\work\ai_sandbox\ConanExiles\_scratch\icon')
if (-not $Exe) { . (Join-Path $PSScriptRoot '..\game-target.ps1'); $Exe = Join-Path $GameDir 'ConanSandbox.exe' }   # the game of targets.json, 2026-11-13
if (-not (Test-Path $Out)) { $null = New-Item -ItemType Directory $Out }   # GDI+ Save gives a "generic error" into a missing folder
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace W -Name S -MemberDefinition @'
[DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern uint ExtractIconEx(string f, int i, IntPtr[] large, IntPtr[] small, uint n);
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int PrivateExtractIcons(string f, int i, int cx, int cy, IntPtr[] h, int[] id, int n, int flags);
'@
foreach ($size in 256, 48) {
  $h = New-Object IntPtr[] 1; $id = New-Object int[] 1
  $n = [W.S]::PrivateExtractIcons($Exe, 0, $size, $size, $h, $id, 1, 0)
  if ($n -gt 0 -and $h[0] -ne [IntPtr]::Zero) {
    $ico = [System.Drawing.Icon]::FromHandle($h[0]); $bmp = $ico.ToBitmap(); $bmp.Save("$Out\conan_icon_$size.png", [System.Drawing.Imaging.ImageFormat]::Png)
    "saved $size : $($bmp.Width)x$($bmp.Height)"
  } else { "no icon at $size" }
}
