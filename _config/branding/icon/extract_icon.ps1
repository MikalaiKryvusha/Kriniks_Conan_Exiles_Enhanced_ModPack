# Extract the largest icon images of the Conan Exiles exe (read-only on the game folder; output into the scratchpad).
param([string]$Exe = 'D:\Games\Conan Exiles 3.0.1\ConanSandbox.exe', [string]$Out = 'D:\Temp\claude\d--work-ai-sandbox-KUMM\aabd6f1c-74de-4045-bda0-ad7d382ea665\scratchpad\icon')
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
