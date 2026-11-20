# mouse-seq.ps1 -- REAL input for the game: hold and release mouse buttons and keys by a sequence, through SendInput.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY. Owner 2026-10-27: "press, release, shoot - emulate real button presses" - the pult cannot hold RMB
# (IsInputKeyDown sees only the physical key), so every camera test on RMB passed on the pult and failed in the owner's
# hands. SendInput goes through the Windows input stack: the game sees it as a real button. The game window is brought
# to the front for the sequence (input goes to the foreground window) and the previous window is restored after.
#
#   .\mouse-seq.ps1 -Seq "rdown,wait:1500,lclick,wait:1500,rup,wait:500"
#   steps: rdown rup ldown lup mdown mup lclick (down+up 60 ms)  x1down x1up x2down x2up (mouse side buttons)  kdown:W kup:W (letter or 0xNN virtual key)  wheel:-1  wait:<ms>
#          move:<fx>/<fy> - the real cursor to a fraction of the primary screen (0..1, the game is fullscreen on it; as hover-watch.ps1 -At),
#          added 2026-10-30 for clicks on a settings row (KUMM plan 38 phase 0)
#   (mdown/mup - middle button: the owner's heavy attack, which draws the bow without RMB - 2026-10-28)
# [NOT-TESTED]
#
# The owner-at-the-keyboard guard (2026-11-07) was REMOVED 2026-11-20 19:37 by the owner's word: every busy-keyboard / busy-mouse rule is cancelled
# (KUMM PROJECT_HISTORY entry 2026-11-20 19:37). The input is sent at once.
param(
  [Parameter(Mandatory = $true)][string]$Seq,
  [string]$Process = 'ConanSandbox-Win64-Shipping',
  [switch]$KeepFront
)
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class SI {
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public int mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit)] public struct UNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public UNION u; }
  [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint mapType);
  public static void Mouse(uint flags, int data) {
    INPUT[] a = new INPUT[1]; a[0].type = 0; a[0].u.mi.dwFlags = flags; a[0].u.mi.mouseData = data;
    SendInput(1, a, Marshal.SizeOf(typeof(INPUT)));
  }
  public static void MoveTo(double fx, double fy) {
    INPUT[] a = new INPUT[1]; a[0].type = 0;
    a[0].u.mi.dx = (int)(fx * 65535); a[0].u.mi.dy = (int)(fy * 65535);
    a[0].u.mi.dwFlags = 0x0001 | 0x8000;   // MOVE | ABSOLUTE (0..65535 of the primary screen, no DPI arithmetic)
    SendInput(1, a, Marshal.SizeOf(typeof(INPUT)));
  }
  public static void Key(ushort vk, bool up) {
    INPUT[] a = new INPUT[1]; a[0].type = 1; a[0].u.ki.wVk = vk; a[0].u.ki.wScan = (ushort)MapVirtualKey(vk, 0);
    a[0].u.ki.dwFlags = (uint)(0x0008 | (up ? 0x0002 : 0));   // KEYEVENTF_SCANCODE (games read scan codes) | KEYUP
    a[0].u.ki.wVk = 0;
    SendInput(1, a, Marshal.SizeOf(typeof(INPUT)));
  }
  // vkdown/vkup (2026-11-07 19:3x, KUMM Locomotion M6): Conan's JUMP ignored the scan-code Space above, while a VK-only Space (input.ps1) jumped
  // the hero twice (the mod's log 19:24:59, 19:26:00). [TESTED: 2026-11-07 19:37 - ran: the vk Space did NOT jump either (no AirCombat line); the RMB/LMB of the same run fired arrow #3]
  public static void KeyVk(ushort vk, bool up) {
    INPUT[] a = new INPUT[1]; a[0].type = 1; a[0].u.ki.wVk = vk; a[0].u.ki.wScan = (ushort)MapVirtualKey(vk, 0);
    a[0].u.ki.dwFlags = (uint)(up ? 0x0002 : 0);
    SendInput(1, a, Marshal.SizeOf(typeof(INPUT)));
  }
}
"@
$MOUSE = @{ ldown = 0x0002; lup = 0x0004; rdown = 0x0008; rup = 0x0010; mdown = 0x0020; mup = 0x0040 }
function Vk([string]$k) { if ($k -match '^0x') { return [uint16]([Convert]::ToInt32($k, 16)) } return [uint16][char]$k.ToUpper() }

$game = Get-Process $Process -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$prev = [SI]::GetForegroundWindow()
# Foreground lock: a background process may not steal focus; an ALT tap first is the documented way round it.
[SI]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [SI]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
# MINIMIZED (2026-11-18 21:18, KUMM bug 85): a minimized game can still BE the foreground window, so the focus proof below passed while the game lay on the
# taskbar - a real click went to the owner's screen under the cursor (the feedback collector had minimized the game). Restore it (SW_RESTORE 9) first;
# still minimized after that - nothing is sent (exit 6, below).
if ([SI]::IsIconic($game.MainWindowHandle)) { [void][SI]::ShowWindow($game.MainWindowHandle, 9); Start-Sleep -Milliseconds 500 }
[void][SI]::SetForegroundWindow($game.MainWindowHandle)
Start-Sleep -Milliseconds 300
# FOCUS PROOF (2026-11-15 00:1x): after the owner's remote session closed, the foreground stayed with the Windows shell (ShellExperienceHost) and this
# script still sent its keys - the mouse reached the full-screen game under the cursor, the keys went to the shell. Keys are sent only when the game
# window IS the foreground; one more ALT + SetForegroundWindow try, then refuse with exit 6 and nothing sent.
if ([SI]::GetForegroundWindow() -ne $game.MainWindowHandle -or [SI]::IsIconic($game.MainWindowHandle)) {
  [SI]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [SI]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  if ([SI]::IsIconic($game.MainWindowHandle)) { [void][SI]::ShowWindow($game.MainWindowHandle, 9); Start-Sleep -Milliseconds 500 }
  [void][SI]::SetForegroundWindow($game.MainWindowHandle)
  Start-Sleep -Milliseconds 300
  if ([SI]::GetForegroundWindow() -ne $game.MainWindowHandle -or [SI]::IsIconic($game.MainWindowHandle)) {
    Write-Output "GAME NOT IN FRONT: the foreground window is not the game - nothing sent"
    exit 6
  }
}
$t0 = Get-Date
$log = @()
foreach ($step in ($Seq -split ',')) {
  $s = $step.Trim()
  $ms = [int]((Get-Date) - $t0).TotalMilliseconds
  if ($MOUSE.ContainsKey($s)) { [SI]::Mouse([uint32]$MOUSE[$s], 0) }
  elseif ($s -eq 'lclick') { [SI]::Mouse(0x0002, 0); Start-Sleep -Milliseconds 60; [SI]::Mouse(0x0004, 0) }
  elseif ($s -like 'wait:*') { Start-Sleep -Milliseconds ([int]$s.Substring(5)) }
  elseif ($s -like 'kdown:*') { [SI]::Key((Vk $s.Substring(6)), $false) }
  elseif ($s -like 'kup:*') { [SI]::Key((Vk $s.Substring(4)), $true) }
  elseif ($s -like 'vkdown:*') { [SI]::KeyVk((Vk $s.Substring(7)), $false) }
  elseif ($s -like 'vkup:*') { [SI]::KeyVk((Vk $s.Substring(5)), $true) }
  elseif ($s -like 'wheel:*') { [SI]::Mouse(0x0800, 120 * [int]$s.Substring(6)) }
  # x1down/x1up, x2down/x2up (2026-11-14, KUMM plan 53 step 14): the mouse side buttons - MOUSEEVENTF_XDOWN 0x0080 / XUP 0x0100 with
  # mouseData XBUTTON1 = 1 or XBUTTON2 = 2; Unreal names them ThumbMouseButton / ThumbMouseButton2 (the owner's dodge is ThumbMouseButton)
  elseif ($s -match '^x([12])(down|up)$') { [SI]::Mouse($(if ($Matches[2] -eq 'down') { [uint32]0x0080 } else { [uint32]0x0100 }), [int]$Matches[1]) }
  elseif ($s -like 'move:*') { $p = $s.Substring(5) -split '/'; [SI]::MoveTo([double]::Parse($p[0], [Globalization.CultureInfo]::InvariantCulture), [double]::Parse($p[1], [Globalization.CultureInfo]::InvariantCulture)) }
  else { throw "unknown step: $s" }
  $log += ('{0,6} ms  {1}' -f $ms, $s)
}
if (-not $KeepFront) { [void][SI]::SetForegroundWindow($prev) }
# The 'last input is mine' mark for owner-idle.ps1 (-MarkOwn after every sequence) is gone: its readers were the busy-keyboard guards the owner cancelled
# 2026-11-20 19:37 (KUMM HOUSE_RULES 30), and the last of them left the pack the same evening - one PowerShell start (0.5-1 s) less per sequence.
$log -join "`n"
