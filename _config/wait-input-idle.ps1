# idle.ps1 -Min <sec> -MaxWait <sec> -- wait until nobody has touched mouse/keyboard for Min seconds; print the idle time.
# ASCII-only (PowerShell 5.1 reads BOM-less scripts as ANSI).
param([int]$Min = 10, [int]$MaxWait = 120)
Add-Type @'
using System; using System.Runtime.InteropServices;
public class IdleW { [StructLayout(LayoutKind.Sequential)] struct LII { public uint cbSize; public uint dwTime; }
 [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LII p);
 public static uint Sec() { LII l = new LII(); l.cbSize = (uint)Marshal.SizeOf(l); GetLastInputInfo(ref l); return ((uint)Environment.TickCount - l.dwTime) / 1000; } }
'@
$t0 = Get-Date
while ([IdleW]::Sec() -lt $Min) {
  if (((Get-Date) - $t0).TotalSeconds -gt $MaxWait) { "idle never reached $Min s (now $([IdleW]::Sec()))"; exit 1 }
  Start-Sleep -Milliseconds 500
}
"idle $([IdleW]::Sec()) s"
