# offscreen.ps1 - the stand's proof that its launcher windows never reach the owner's screen (KUMM plans/57; the owner 2026-11-18 15:55 saw a stand window
# bottom-right, cut by the screen edges, with no taskbar button). Polls every 200 ms the visible top-level windows of every KrinikConanLauncher.exe whose
# path is under -Root and writes one line per window rect that intersects any monitor; ends when -Stop exists or after -Seconds.
#   powershell -File offscreen.ps1 -Root <case dir> -Out <file> -Stop <file> [-Seconds 900]
# Output: "ON SCREEN <pid> <l>,<t>,<r>,<b>" lines, then "windows seen <n>, on screen <m>". Physical pixels: the script is per-monitor DPI aware
# (a non-aware PowerShell reads 1/3-size rects at 300 %, EXP-0547). ASCII only: Windows PowerShell 5.1 reads a BOM-less script as ANSI. [NOT-TESTED]
param([string]$Root, [string]$Out, [string]$Stop, [int]$Seconds = 900)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class KrinikOff {
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    public delegate bool MonProc(IntPtr m, IntPtr dc, ref RECT r, IntPtr d);
    [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonProc f, IntPtr d);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public static void Aware() { try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch (Exception) { } }
    public static List<RECT> Monitors() {
        var list = new List<RECT>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr m, IntPtr dc, ref RECT r, IntPtr d) => { list.Add(r); return true; }, IntPtr.Zero);
        return list;
    }
    public static List<string> Windows(HashSet<uint> pids, List<RECT> mons) {
        var res = new List<string>();
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (!pids.Contains(p) || !IsWindowVisible(h)) return true;
            RECT r; if (!GetWindowRect(h, out r)) return true;
            bool on = false;
            foreach (var m in mons) if (r.L < m.R && r.R > m.L && r.T < m.B && r.B > m.T) on = true;
            res.Add((on ? "ON SCREEN " : "off ") + p + " " + r.L + "," + r.T + "," + r.R + "," + r.B + " " + h);
            return true;
        }, IntPtr.Zero);
        return res;
    }
}
'@
[KrinikOff]::Aware()
$mons = [KrinikOff]::Monitors()
$seen = @{}; $on = @{}
$deadline = (Get-Date).AddSeconds($Seconds)
$rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
# Readiness: the stand starts its case only after this line (a short case ended before the watcher compiled its code - "windows seen 0", 2026-11-18 18:40).
Add-Content -LiteralPath $Out -Value 'watching' -Encoding ASCII
while ((Get-Date) -lt $deadline -and -not (Test-Path -LiteralPath $Stop)) {
    $pids = New-Object 'System.Collections.Generic.HashSet[uint32]'
    foreach ($p in Get-CimInstance Win32_Process -Filter "Name='KrinikConanLauncher.exe'") {
        if ($p.ExecutablePath -and $p.ExecutablePath.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { [void]$pids.Add([uint32]$p.ProcessId) }
    }
    if ($pids.Count) {
        foreach ($line in [KrinikOff]::Windows($pids, $mons)) {
            $key = ($line -split ' ')[-1]
            $seen[$key] = 1
            if ($line.StartsWith('ON SCREEN') -and -not $on.ContainsKey($line)) { $on[$line] = 1; Add-Content -LiteralPath $Out -Value $line -Encoding ASCII }
        }
    }
    Start-Sleep -Milliseconds 200
}
Add-Content -LiteralPath $Out -Value ("windows seen {0}, on screen {1}, monitors {2}" -f $seen.Count, $on.Count, $mons.Count) -Encoding ASCII
