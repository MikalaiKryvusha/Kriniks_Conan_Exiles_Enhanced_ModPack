# post-key.ps1 - the BACKGROUND twin of input.ps1 for single keys (KUMM bug 85, HOUSE_RULES rule 16.2): posts WM_KEYDOWN + WM_KEYUP straight into the
# game's window message queue (PostMessage), so the game gets the key while the owner keeps his own window and keyboard - no SendInput, no focus change.
#   powershell -File post-key.ps1 -Key Escape|Tab|Enter|I [-GamePid <game pid>] [-HoldMs 60]
# Exit 0 - posted; 2 - no game window; 3 - unknown key.
# Whether the game ACTS on a posted key in the background is the caller's observation (a remote read after it), never this script's claim.
# [NOT-TESTED]
param(
    [Parameter(Mandatory = $true)][string]$Key,
    [int]$GamePid = 0,
    [int]$HoldMs = 60
)
$ErrorActionPreference = 'Stop'
$KEYS = @{
    'Escape' = @(0x1B, 0x01)
    'Tab'    = @(0x09, 0x0F)
    'Enter'  = @(0x0D, 0x1C)
    'I'      = @(0x49, 0x17)
}
if ($KEYS.ContainsKey($Key)) {
    $vk = $KEYS[$Key][0]; $scan = $KEYS[$Key][1]
} else {
    Write-Output "unknown key: $Key (known: $($KEYS.Keys -join ', '))"
    exit 3
}
if ($GamePid -eq 0) {
    $p = Get-Process -Name 'ConanSandbox-Win64-Shipping' -ErrorAction SilentlyContinue | Select-Object -First 1
} else {
    $p = Get-Process -Id $GamePid -ErrorAction SilentlyContinue
}
if (-not $p -or $p.MainWindowHandle -eq [IntPtr]::Zero) {
    Write-Output 'no game window'
    exit 2
}
Add-Type -Namespace KrinikPostKey -Name W -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool PostMessageW(System.IntPtr h, uint m, System.IntPtr w, System.IntPtr l);
'@
$WM_KEYDOWN = 0x0100
$WM_KEYUP = 0x0101
$down = 1 -bor ($scan -shl 16)
$up = $down -bor (1 -shl 30) -bor ([int64]1 -shl 31)
$h = $p.MainWindowHandle
$ok1 = [KrinikPostKey.W]::PostMessageW($h, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr]$down)
Start-Sleep -Milliseconds $HoldMs
$ok2 = [KrinikPostKey.W]::PostMessageW($h, $WM_KEYUP, [IntPtr]$vk, [IntPtr][int64]$up)
Write-Output ("posted {0} (vk 0x{1:X2}) to pid {2} window 0x{3:X}: down {4}, up {5}" -f $Key, $vk, $p.Id, [int64]$h, $ok1, $ok2)
exit 0
