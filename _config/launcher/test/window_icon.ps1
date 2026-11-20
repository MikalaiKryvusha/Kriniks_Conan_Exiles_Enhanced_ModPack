# window_icon.ps1 — the icon a live launcher window gives Windows (WM_GETICON ICON_BIG / ICON_SMALL2) saved as images: what the taskbar shows.
# Usage: powershell -File window_icon.ps1 -Exe <launcher exe> -Out <dir>
param([string]$Exe, [string]$Out)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W { [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr GetClassLongPtr(IntPtr h, int i); }
"@
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$env:KRINIK_LAUNCHER_NOACTIVATE = '1'
$p = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
try {
    $h = [IntPtr]::Zero
    for ($i = 0; $i -lt 60 -and $h -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $p.Refresh(); $h = $p.MainWindowHandle }
    if ($h -eq [IntPtr]::Zero) { "no window"; exit 1 }
    foreach ($k in @(@{n='big'; w=1}, @{n='small'; w=2})) {
        $hi = [W]::SendMessage($h, 0x7F, [IntPtr]$k.w, [IntPtr]::Zero)
        if ($hi -eq [IntPtr]::Zero) { "$($k.n): none"; continue }
        $bmp = [System.Drawing.Icon]::FromHandle($hi).ToBitmap()
        $f = Join-Path $Out "icon_$($k.n).png"; $bmp.Save($f, [System.Drawing.Imaging.ImageFormat]::Png)
        "$($k.n): $($bmp.Width)x$($bmp.Height) -> $f"
    }
}
finally { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
