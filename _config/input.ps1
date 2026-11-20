# input.ps1 -- drive mouse and keyboard through the Windows API so the agent can
# operate the game without a human.
#
# ASCII-ONLY ON PURPOSE: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI,
# so any Cyrillic here would be corrupted before the script even runs
# (paid for on this machine; same reason shot.ps1 is ASCII-only).
#
# WHY IT EXISTS. Owner's ask 2026-09-09: "can you launch the game yourself,
# click CONTINUE, spin the wheel and see whether the camera stutters".
# Without it every camera experiment costs the owner a launch.
#
# CAVEAT, STATED UP FRONT: games that read RAW INPUT (WM_INPUT) ignore
# synthetic mouse motion and wheel. Menus built on Slate/UMG usually accept it.
# This is a fact to be MEASURED per game, not assumed - see the -Probe mode.
#
#   .\input.ps1 -Move 1920,1080
#   .\input.ps1 -Click 1920,1080          move, then left click
#   .\input.ps1 -Wheel -3                 negative = toward the user (zoom out)
#   .\input.ps1 -Key 0x1B                 press and release a virtual key
#   .\input.ps1 -Probe                    print cursor pos and screen bounds

param(
  [string]$Move,
  [string]$Click,
  # Правый клик. Добавлен 12.09.2026: отладочная консоль UE4SS прячет фильтры Live View
  # («Instances only», «Include inheritance») за правым кликом по строке поиска, а стенд,
  # который не умеет нажать кнопку, не может проверить то, что за ней (EXP-0082).
  [string]$RightClick,
  # Печать текста В ОБХОД РАСКЛАДКИ. Оплачено 12.09.2026: у владельца по умолчанию
  # русская раскладка, и keybd_event по кодам клавиш напечатал «здфнук» вместо «player».
  # SendInput с KEYEVENTF_UNICODE шлёт СИМВОЛ, а не клавишу, и раскладке не подчиняется.
  [string]$Type,
  # Относительное движение мыши = ОБЗОР в игре. Абсолютный SetCursorPos камеру
  # не поворачивает: игра читает ДЕЛЬТУ через raw input, а курсор в ней спрятан.
  [string]$Look,
  [int]$Wheel = 0,
  [string]$Key,
  # MODIFIERS. Added 2026-09-10 because the harness could not press Ctrl AT ALL,
  # while the owner's own layout rule is "Ctrl = the extra camera options" - so
  # every Ctrl-bound key of the camera mod (the rotation axis among them) had
  # never once been exercised by the agent. A key the harness cannot press is a
  # key nobody tests.
  [switch]$Ctrl,
  [switch]$Shift,
  [switch]$Alt,
  # Repeat the key N times inside ONE process. A nudge moves 5 units per press,
  # so returning an axis from 200 to 0 is 40 presses - 40 PowerShell launches
  # otherwise, and the run drifts while they start.
  [int]$Repeat = 1,
  [switch]$Probe,
  [int]$HoldMs = 60,
  # Refuse to send anything unless THIS process owns the foreground window.
  # Paid for 2026-09-09: the game lost focus to another window and the agent's
  # clicks landed in the OWNER'S other VS Code session. Synthetic input goes
  # wherever the focus is - so the target must be asserted, never assumed.
  [string]$RequireWindow = 'ConanSandbox-Win64-Shipping',
  [switch]$NoFocusCheck
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Inp {
  // DPI AWARENESS IS NOT OPTIONAL HERE. The gaming TV is 3840x2160 at 300%
  // scaling; a process that does not declare itself DPI-aware is handed
  // VIRTUALIZED coordinates - 1280x720 - and every SetCursorPos lands at one
  // third of the intended position. Measured on this machine 2026-09-09:
  // Screen.Bounds said 1280x720 while the adapter reported 3840x2160.
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, int d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint mapType);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public const uint MOVE = 0x0001, LEFTDOWN = 0x0002, LEFTUP = 0x0004, WHEEL = 0x0800;
  public const uint RIGHTDOWN = 0x0008, RIGHTUP = 0x0010;
  public const uint KEYUP = 0x0002;
  public const uint UNICODE = 0x0004;
  [StructLayout(LayoutKind.Sequential)]
  public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size = 40)]
  public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KEYBDINPUT ki; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
}
'@

$null = [Inp]::SetProcessDPIAware()

# PowerShell turns an unquoted "400,868" into an ARRAY and then joins it with a
# space when the parameter is [string] - so "-Move 400,868" arrives as "400 868"
# and [int] conversion dies. Split on comma OR whitespace and both forms work.
function Get-XY([string]$s) {
  $parts = $s -split '[,\s]+' | Where-Object { $_ -ne '' }
  if ($parts.Count -ne 2) { throw "expected 'X,Y', got '$s'" }
  return @([int]$parts[0], [int]$parts[1])
}

function Show-Pos {
  $p = New-Object Inp+POINT
  $null = [Inp]::GetCursorPos([ref]$p)
  $vs = [Windows.Forms.SystemInformation]::VirtualScreen
  Write-Output ("cursor: {0},{1}" -f $p.X, $p.Y)
  Write-Output ("virtual screen: x={0} y={1} w={2} h={3}" -f $vs.X, $vs.Y, $vs.Width, $vs.Height)
}

# --- the focus gate -------------------------------------------------------
# Synthetic input has no target of its own: it goes to whatever window is
# focused. So we ASSERT the target instead of hoping. If the game is not
# foreground we try to raise it once, then check again - and refuse if it is
# still not there. Refusing is the whole point: a click that misses the game
# does not vanish, it lands in someone else's window.
function Assert-Foreground([string]$ProcName) {
  $p = Get-Process -Name $ProcName -ErrorAction SilentlyContinue |
       Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { throw "no window for process '$ProcName' - is the game running?" }
  $h = $p.MainWindowHandle
  if ([Inp]::GetForegroundWindow() -eq $h) { return }
  if ([Inp]::IsIconic($h)) { $null = [Inp]::ShowWindow($h, 9) }   # SW_RESTORE
  $null = [Inp]::SetForegroundWindow($h)
  Start-Sleep -Milliseconds 400
  if ([Inp]::GetForegroundWindow() -ne $h) {
    throw "'$ProcName' is NOT the foreground window - refusing to send input, it would land elsewhere"
  }
  Write-Output "focus: raised '$ProcName'"
}

if ($Probe) { Show-Pos; exit 0 }

# HOUSE_RULES rule 30 (2026-11-07 19:3x): this tool sent a real Space into the game while the owner was typing - mouse-seq refused the same second, input.ps1
# had no guard and the hook checks only once before a whole command. Same probe as mouse-seq: a person touched keyboard/mouse < 10 s ago -> exit 5, nothing sent.
if ($Move -or $Click -or $RightClick -or $Look -or $Wheel -ne 0 -or $Key -or $Type) {
  $probe = & powershell -NoProfile -File 'D:\work\ai_sandbox\_tools\owner-idle.ps1'
  if ($LASTEXITCODE -eq 5) { Write-Output ("OWNER AT THE KEYBOARD: {0} - nothing sent" -f $probe); exit 5 }
}

if (-not $NoFocusCheck -and ($Move -or $Click -or $RightClick -or $Look -or $Wheel -ne 0 -or $Key -or $Type)) {
  Assert-Foreground $RequireWindow
}

if ($Move) {
  $xy = Get-XY $Move
  $null = [Inp]::SetCursorPos($xy[0], $xy[1])
  Start-Sleep -Milliseconds $HoldMs
  Show-Pos
}

if ($Click) {
  $xy = Get-XY $Click
  $null = [Inp]::SetCursorPos($xy[0], $xy[1])
  Start-Sleep -Milliseconds $HoldMs
  # Two small jiggles first: some UIs only light a button up on real MOUSEMOVE.
  $null = [Inp]::SetCursorPos($xy[0] + 1, $xy[1])
  Start-Sleep -Milliseconds 30
  $null = [Inp]::SetCursorPos($xy[0], $xy[1])
  Start-Sleep -Milliseconds 30
  [Inp]::mouse_event([Inp]::LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds $HoldMs
  [Inp]::mouse_event([Inp]::LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
  Write-Output ("clicked at {0},{1}" -f $xy[0], $xy[1])
}

if ($RightClick) {
  $xy = Get-XY $RightClick
  $null = [Inp]::SetCursorPos($xy[0], $xy[1])
  Start-Sleep -Milliseconds $HoldMs
  $null = [Inp]::SetCursorPos($xy[0] + 1, $xy[1])
  Start-Sleep -Milliseconds 30
  $null = [Inp]::SetCursorPos($xy[0], $xy[1])
  Start-Sleep -Milliseconds 30
  [Inp]::mouse_event([Inp]::RIGHTDOWN, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds $HoldMs
  [Inp]::mouse_event([Inp]::RIGHTUP, 0, 0, 0, [UIntPtr]::Zero)
  Write-Output ("right-clicked at {0},{1}" -f $xy[0], $xy[1])
}

if ($Type) {
  # Один символ = две записи INPUT (нажатие и отпускание) с KEYEVENTF_UNICODE.
  foreach ($ch in $Type.ToCharArray()) {
    $down = New-Object Inp+INPUT; $down.type = 1
    $k1 = New-Object Inp+KEYBDINPUT; $k1.wVk = 0; $k1.wScan = [uint16][char]$ch; $k1.dwFlags = [Inp]::UNICODE
    $down.ki = $k1
    $up = New-Object Inp+INPUT; $up.type = 1
    $k2 = New-Object Inp+KEYBDINPUT; $k2.wVk = 0; $k2.wScan = [uint16][char]$ch; $k2.dwFlags = [Inp]::UNICODE -bor [Inp]::KEYUP
    $up.ki = $k2
    $null = [Inp]::SendInput(2, [Inp+INPUT[]]@($down, $up), [Runtime.InteropServices.Marshal]::SizeOf([type][Inp+INPUT]))
    Start-Sleep -Milliseconds 25
  }
  Write-Output ("typed {0} char(s)" -f $Type.Length)
}

if ($Look) {
  # Дробим на маленькие шаги: одна огромная дельта в играх часто обрезается
  # фильтром сглаживания или упирается в предел угла за один кадр.
  $d = Get-XY $Look
  $steps = 20
  for ($i = 0; $i -lt $steps; $i++) {
    [Inp]::mouse_event([Inp]::MOVE, [int]($d[0] / $steps), [int]($d[1] / $steps), 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 25
  }
  Write-Output ("look: dx={0} dy={1} za {2} shagov" -f $d[0], $d[1], $steps)
}

if ($Wheel -ne 0) {
  # One notch is 120. Send them one at a time: a single huge delta is often
  # collapsed into one step by the receiver.
  $notches = [Math]::Abs($Wheel)
  $sign = if ($Wheel -gt 0) { 120 } else { -120 }
  for ($i = 0; $i -lt $notches; $i++) {
    [Inp]::mouse_event([Inp]::WHEEL, 0, 0, $sign, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 90
  }
  Write-Output ("wheel: {0} notches of {1}" -f $notches, $sign)
}

if ($Key) {
  $vk = [byte](Invoke-Expression $Key)

  # VK_CONTROL 0x11 · VK_SHIFT 0x10 · VK_MENU (Alt) 0x12.
  # Held DOWN around the whole burst, not re-pressed per repeat: UE4SS reads the
  # modifier with GetAsyncKeyState at the moment the key goes down, so what it
  # needs is the modifier being down THEN - and a modifier that flaps up and
  # down between repeats is a race we would be inventing for ourselves.
  # LEFT-HAND SCAN CODES. Added 2026-09-13: Unreal decides LeftShift vs RightShift
  # by MapVirtualKey(scan code), so scan 0 can never be the game's LeftShift (Alt and
  # Ctrl pick their side by the extended-key bit instead). [NOT-TESTED as a cure]:
  # Shift+D did not sprint BEFORE this change - and still did not sprint AFTER it,
  # even with Shift pressed mid-run (speed 450, stamina untouched). The cause of the
  # missing sprint is therefore still open; these codes are only the correct form.
  # (RIGHT Alt is no way around "LeftAlt = dodge" in Conan: on this machine it is
  # AltGr, Windows adds LeftCtrl to it, and UE4SS then sees Ctrl+Alt.)
  $mods = @()
  if ($Ctrl)  { $mods += ,@([byte]0x11, [byte]0x1D) }
  if ($Shift) { $mods += ,@([byte]0x10, [byte]0x2A) }
  if ($Alt)   { $mods += ,@([byte]0x12, [byte]0x38) }

  foreach ($m in $mods) {
    [Inp]::keybd_event($m[0], $m[1], 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
  }
  try {
    # The key's SCAN code goes with it: with scan 0 Conan 3.0.1 ignored Q/E in the hub (2026-11-06 18:12, a 60 fps video: the tab never changed).
    # [NOT-TESTED] - the scan-code send is checked by the next hub run.
    $sc = [byte]([Inp]::MapVirtualKey([uint32]$vk, 0))
    for ($r = 0; $r -lt [Math]::Max(1, $Repeat); $r++) {
      [Inp]::keybd_event($vk, $sc, 0, [UIntPtr]::Zero)
      Start-Sleep -Milliseconds $HoldMs
      [Inp]::keybd_event($vk, $sc, [Inp]::KEYUP, [UIntPtr]::Zero)
      if ($Repeat -gt 1) { Start-Sleep -Milliseconds 40 }
    }
  } finally {
    # RELEASE IN A finally. A modifier left stuck down outlives this script and
    # poisons every window the owner touches next - Ctrl held turns his typing
    # into shortcuts. Releasing must survive an error in the loop above.
    [array]::Reverse($mods)
    foreach ($m in $mods) {
      [Inp]::keybd_event($m[0], $m[1], [Inp]::KEYUP, [UIntPtr]::Zero)
      Start-Sleep -Milliseconds 20
    }
  }

  $names = @()
  if ($Ctrl)  { $names += 'Ctrl' }
  if ($Shift) { $names += 'Shift' }
  if ($Alt)   { $names += 'Alt' }
  $prefix = if ($names.Count) { ($names -join '+') + '+' } else { '' }
  Write-Output ("key {0}0x{1:X2} pressed x{2}" -f $prefix, $vk, [Math]::Max(1, $Repeat))
}
