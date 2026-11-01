<#
.SYNOPSIS
  Sets the Windows volume-mixer level of an application (per-app volume) by process name, or lists the audio sessions.
.DESCRIPTION
  Core Audio (IAudioSessionManager2 -> ISimpleAudioVolume) on every active render device, so it works over a Vibepollo
  stream too (the stream's virtual audio device is one more render device). Windows remembers the level per exe path,
  so one call while the game is running keeps it for later launches.
  The owner's word 2026-10-30 18:21: "в микшере винды поставь конану громкость 1%".
  [NOT-TESTED]
.EXAMPLE
  powershell -File set-app-volume.ps1 -List
  powershell -File set-app-volume.ps1 -Process ConanSandbox -Percent 1
#>
param([string]$Process = 'ConanSandbox', [double]$Percent = -1, [switch]$List)
$ErrorActionPreference = 'Stop'

Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCo {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
  int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
}
[Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceCollection { int GetCount(out int n); int Item(int i, out IMMDevice d); }
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
  int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
  int OpenPropertyStore(int access, out IntPtr store);
  int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
}
[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 {
  int GetAudioSessionControl(IntPtr a, int b, out IntPtr c);
  int GetSimpleAudioVolume(IntPtr a, int b, out IntPtr c);
  int GetSessionEnumerator(out IAudioSessionEnumerator e);
}
[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator { int GetCount(out int n); int GetSession(int i, out IAudioSessionControl2 s); }
[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 {
  int GetState(out int s); int GetDisplayName(out IntPtr n); int SetDisplayName(IntPtr a, IntPtr b);
  int GetIconPath(out IntPtr p); int SetIconPath(IntPtr a, IntPtr b); int GetGroupingParam(out Guid g);
  int SetGroupingParam(IntPtr a, IntPtr b); int RegisterAudioSessionNotification(IntPtr a);
  int UnregisterAudioSessionNotification(IntPtr a); int GetSessionIdentifier(out IntPtr a);
  int GetSessionInstanceIdentifier(out IntPtr a); int GetProcessId(out uint pid);
}
[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume {
  int SetMasterVolume(float level, ref Guid ctx); int GetMasterVolume(out float level);
  int SetMute(bool mute, ref Guid ctx); int GetMute(out bool mute);
}

public static class AppVolume {
  // Returns "pid<TAB>volume%<TAB>device id" per session; sets the level where the pid is in `pids` and level >= 0.
  public static List<string> Walk(int[] pids, float level) {
    var rows = new List<string>();
    var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCo();
    IMMDeviceCollection col; en.EnumAudioEndpoints(0 /*eRender*/, 1 /*ACTIVE*/, out col);
    int n; col.GetCount(out n);
    Guid iid = typeof(IAudioSessionManager2).GUID;
    for (int i = 0; i < n; i++) {
      IMMDevice dev; col.Item(i, out dev);
      string id; dev.GetId(out id);
      object o; dev.Activate(ref iid, 23 /*CLSCTX_ALL*/, IntPtr.Zero, out o);
      var mgr = (IAudioSessionManager2)o;
      IAudioSessionEnumerator se; mgr.GetSessionEnumerator(out se);
      int m; se.GetCount(out m);
      for (int j = 0; j < m; j++) {
        IAudioSessionControl2 s; se.GetSession(j, out s);
        uint pid; s.GetProcessId(out pid);
        var vol = (ISimpleAudioVolume)s;
        if (level >= 0 && Array.IndexOf(pids, (int)pid) >= 0) { Guid g = Guid.Empty; vol.SetMasterVolume(level, ref g); }
        float v; vol.GetMasterVolume(out v);
        rows.Add(pid + "\t" + Math.Round(v * 100, 1) + "\t" + id);
      }
    }
    return rows;
  }
}
'@

$pids = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "$Process*" } | ForEach-Object { $_.Id })
$level = -1.0
if (-not $List) {
  if ($Percent -lt 0 -or $Percent -gt 100) { Write-Host 'Give -Percent 0..100 or -List'; exit 2 }
  if ($pids.Count -eq 0) { Write-Host "No process '$Process*' running: nothing in the mixer to set"; exit 3 }
  $level = $Percent / 100.0
}
$hit = $false
foreach ($row in [AppVolume]::Walk([int[]]$pids, [float]$level)) {
  $f = $row -split "`t"
  $name = (Get-Process -Id ([int]$f[0]) -ErrorAction SilentlyContinue).ProcessName
  if ($pids -contains [int]$f[0]) { $hit = $true }
  Write-Host ("{0,-28} pid {1,-6} {2,6}%" -f $name, $f[0], $f[1])
}
if (-not $List -and -not $hit) { Write-Host "'$Process' runs but has no audio session yet (it opens one when the game plays sound)"; exit 4 }
exit 0
