# esc-when-idle.ps1 -- wait until the owner has not touched mouse/keyboard for -Min seconds, press Esc in the game, give the foreground back.
#
# ASCII-ONLY: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI.
#
# WHY (2026-10-29, KUMM plans/34 W16 retest). The in-game menu (W_IngameMenu_C) exists only after a REAL Esc; the remote cannot create it, and
# re-entry tests need it (Esc -> remote "call W_IngameMenu_C_<N> CloseAndReturnToMainMenu" -> enter-world-remote.sh). Real input needs the game in
# front, which takes the owner's screen - so the press waits for his input idle (wait-input-idle.ps1) and hands the window back at once.
#
#   .\esc-when-idle.ps1                 # idle 5 s, wait up to 180 s
#   .\esc-when-idle.ps1 -Min 10
# [TESTED: 2026-10-29 15:37 - idle 5 s, Esc raised the game, foreground returned to the owner's window; W_IngameMenu_C_2147453746 appeared;
#  report KUMM testcases/reports/2026-10-29_conan-quick-batch-xp-locomotion-fps.md (the scratch copy); this file 15:4x with the game closed:
#  neighbours found by its own folder, input.ps1 refused - "no window for process" - no key sent]
#   .\esc-when-idle.ps1 -Key 0x4D       # any virtual key the same way (0x4D = M, the fullscreen map) - 2026-10-29
param([int]$Min = 5, [int]$MaxWait = 180, [string]$Key = '0x1B')
Add-Type @'
using System; using System.Runtime.InteropServices;
public class EscFg { [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
'@
$cfg = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$cfg\wait-input-idle.ps1" -Min $Min -MaxWait $MaxWait
$owner = [EscFg]::GetForegroundWindow()
& "$cfg\input.ps1" -Key $Key
Start-Sleep -Milliseconds 400
$null = [EscFg]::SetForegroundWindow($owner)
Write-Output ("key {0} sent; foreground returned to 0x{1:X}" -f $Key, $owner.ToInt64())
