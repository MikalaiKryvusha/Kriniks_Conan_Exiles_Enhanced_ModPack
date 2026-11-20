# no-power-throttle.ps1 — turn off Windows power throttling (EcoQoS) for the running Conan game process.
#
# Why (KUMM 2026-11-08 12:5x, TC_conan_xp1000_and_water_reflections): on the background path the krinik-show flight ran at 19-23 FPS with
# 40-46 ms CPU per frame (front-path reference: ~60 FPS, ~15 ms). Windows 11 throttles the execution speed of processes whose window is
# not in front; a flight measured that way is invalid and hides any GPU cost. ProcessPowerThrottling with ControlMask = EXECUTION_SPEED and
# StateMask = 0 opts the process OUT of throttling (documented: SetProcessInformation, PROCESS_POWER_THROTTLING_STATE).
#   powershell -File no-power-throttle.ps1            -> applies to ConanSandbox-Win64-Shipping, prints "throttle off PID <n>"
#   powershell -File no-power-throttle.ps1 -Restore   -> back to the system default (ControlMask 0)
# Exit: 0 applied · 3 no game process · 4 the call failed.
# [NOT-TESTED]
param([switch]$Restore)
$ErrorActionPreference = 'Stop'
$p = Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { Write-Output 'no game process'; exit 3 }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PowerThrottle {
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_POWER_THROTTLING_STATE { public uint Version; public uint ControlMask; public uint StateMask; }
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetProcessInformation(IntPtr hProcess, int infoClass, ref PROCESS_POWER_THROTTLING_STATE info, int size);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr h);
}
'@
$PROCESS_SET_INFORMATION = 0x0200
$ProcessPowerThrottling = 4
$EXECUTION_SPEED = 0x1
$h = [PowerThrottle]::OpenProcess($PROCESS_SET_INFORMATION, $false, $p.Id)
if ($h -eq [IntPtr]::Zero) { Write-Output "OpenProcess failed $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 4 }
$s = New-Object PowerThrottle+PROCESS_POWER_THROTTLING_STATE
$s.Version = 1
if ($Restore) { $s.ControlMask = 0 } else { $s.ControlMask = $EXECUTION_SPEED }
$s.StateMask = 0
$ok = [PowerThrottle]::SetProcessInformation($h, $ProcessPowerThrottling, [ref]$s, [Runtime.InteropServices.Marshal]::SizeOf($s))
$err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
[void][PowerThrottle]::CloseHandle($h)
if (-not $ok) { Write-Output "SetProcessInformation failed $err"; exit 4 }
if ($Restore) { Write-Output "throttle default PID $($p.Id)" } else { Write-Output "throttle off PID $($p.Id)" }
exit 0
