# game-front.ps1 -- bring the Conan game window to the foreground and PROVE it is there (ASCII-only: PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
#
# WHY (KUMM 2026-11-07 19:4x, KrinikConanLocomotion case M6): input.ps1 only ASSERTS focus and mouse-seq.ps1 sends to whatever window is in front -
# real Space presses meant for the game went to the owner's VS Code. Real input to the game goes: this script (exit 0 = the game IS the foreground
# window) -> mouse-seq.ps1 -> game-front.ps1 -Restore <hwnd printed here> to give the owner his window back.
# The owner-idle refusal (exit 5 while the owner typed) is REMOVED: the owner cancelled every busy-keyboard rule 2026-11-20 19:37 (KUMM HOUSE_RULES 30);
# dc79053 removed it from input.ps1 and mouse-seq.ps1 and missed this file (judge 2026-11-20 22:3x). -OwnerAsked stays accepted and does nothing now.
#
#   powershell -File game-front.ps1            # prints "front <prevHwnd>"; exit 0 game in front, 3 could not, 4 no game
#   powershell -File game-front.ps1 -Restore <hwnd>
# [TESTED: 2026-11-07 19:3x - three runs: the game came forward ("front <hwnd>", verified by GetForegroundWindow), -Restore gave the focus back]
param([string]$Restore = '', [switch]$OwnerAsked)
Add-Type -Namespace KG -Name W -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int c);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint f, System.UIntPtr e);
[DllImport("user32.dll")] public static extern bool IsIconic(System.IntPtr h);
'@
# MINIMIZED: SW_SHOW (5) leaves a minimized window minimized, and a minimized window can still BE the foreground window - the script said "front" while
# the game lay on the taskbar, and the next real click of mouse-seq.ps1 went to the owner's screen under the cursor (KUMM bug 85 run 2026-11-18 21:18,
# after the feedback collector minimized the game). A minimized game is RESTORED (SW_RESTORE 9) and "front" needs a game that is not minimized.
$SW_SHOW = 5; $SW_RESTORE = 9
if ($Restore) { [void][KG.W]::SetForegroundWindow([IntPtr][long]$Restore); Write-Output "restored $Restore"; exit 0 }
$g = Get-Process ConanSandbox-Win64-Shipping -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $g) { Write-Output 'no game window'; exit 4 }
$prev = [KG.W]::GetForegroundWindow()
for ($i = 0; $i -lt 5; $i++) {
  # a key tap unlocks SetForegroundWindow for a background process (the foreground-lock rule: the caller must have "received the last input").
  # F24 (0x87), not Alt: Alt lands in the owner's window first (VS Code opens its menu) and Alt is the game's dodge (2026-11-07 19:3x).
  [KG.W]::keybd_event(0x87, 0, 0, [UIntPtr]::Zero); [KG.W]::keybd_event(0x87, 0, 2, [UIntPtr]::Zero)
  $cmd = $SW_SHOW; if ([KG.W]::IsIconic($g.MainWindowHandle)) { $cmd = $SW_RESTORE }
  [void][KG.W]::ShowWindow($g.MainWindowHandle, $cmd)
  [void][KG.W]::SetForegroundWindow($g.MainWindowHandle)
  Start-Sleep -Milliseconds 250
  if ([KG.W]::GetForegroundWindow() -eq $g.MainWindowHandle -and -not [KG.W]::IsIconic($g.MainWindowHandle)) { Write-Output ("front {0}" -f [long]$prev); exit 0 }
}
Write-Output 'could not bring the game forward'; exit 3
