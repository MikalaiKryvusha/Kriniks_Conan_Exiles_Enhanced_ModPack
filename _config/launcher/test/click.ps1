# click.ps1 - presses a button of a running Krinik launcher, or reads and answers its message box (KUMM plan 54).
# No real mouse or keyboard: the button gets BM_CLICK by PostMessage, so the owner's input and focus are untouched (HOUSE_RULES rule 30).
#   powershell -File click.ps1 -ProcessId <pid> -Name <caption> [-Index n]   press the launcher button with this caption (UI Automation); several with
#                                                                             one caption (the two "Chto novogo") are counted left to right from 0.
#                                                                             The buttons reach UI Automation as panes named by their text - the WinForms
#                                                                             Name does not (probe 2026-11-17 15:08). The caption comes in argv from
#                                                                             node (UTF-16), never typed into this file.
#   powershell -File click.ps1 -ProcessId <pid> -Dialog -Out <file> [-Press 6|first]   read the message box into <file> (UTF-8: title, text, then
#                                                                             "defbutton=<id>" - the default button, 0 unknown) and
#                                                                             press its button by id (1 OK, 2 Cancel, 6 Yes, 7 No; first - OK or
#                                                                             Cancel, whichever the box has). The box is read by plain Win32 (class
#                                                                             #32770, its text is item 65535): UI Automation showed only its title (S2).
# Exit: 0 done, 3 not found before -TimeoutSec. ASCII-only on purpose: Windows PowerShell 5.1 reads a BOM-less script as ANSI.
# [NOT-TESTED]
#   powershell -File click.ps1 -ProcessId <pid> -Close                         post WM_SYSCOMMAND SC_CLOSE to the launcher window (the player's Alt+F4)
#   powershell -File click.ps1 -ProcessId <pid> -Title -Out <file>            write the launcher window's title (the taskbar and Alt+Tab text) into
#                                                                             <file>, UTF-8 (the judge 2026-11-18, round 2, finding 3: the title pairs
#                                                                             the build with its game, and the log does not carry it).
# -Key <vk>: post WM_KEYDOWN / WM_KEYUP of that virtual key to the element found by -Name instead of BM_CLICK (the copies list, KUMM plans/57).
# Elements count as present when their window is visible (IsWindowVisible): the frames stand keeps the launcher window off-screen, and UI Automation
# calls every element of an off-screen window IsOffscreen.
param([int]$ProcessId, [string]$Name, [int]$Index = 0, [switch]$Dialog, [switch]$Close, [switch]$Title, [string]$Press, [string]$Out, [int]$TimeoutSec = 20, [int]$Key = 0)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class KrinikW {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr d, int id);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    // The box's default button: the one whose style is BS_DEFPUSHBUTTON (epic 55 B7 - the previous-bundle delete box must default to "No").
    public static int DefaultButton(IntPtr box) {
        foreach (int id in new[] { 1, 2, 6, 7 }) {
            IntPtr b = GetDlgItem(box, id);
            if (b != IntPtr.Zero && (GetWindowLong(b, -16) & 0x0F) == 1) return id;
        }
        return 0;
    }
    public static IntPtr FindDialog(uint pid) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            uint p; GetWindowThreadProcessId(h, out p);
            if (p != pid || !IsWindowVisible(h)) return true;
            var c = new StringBuilder(64); GetClassName(h, c, 64);
            if (c.ToString() != "#32770") return true;
            found = h; return false;
        }, IntPtr.Zero);
        return found;
    }
    public static string Text(IntPtr h) { var s = new StringBuilder(8192); GetWindowText(h, s, 8192); return s.ToString(); }
}
'@
$BM_CLICK = 0x00F5
$MESSAGE_ITEM = 0xFFFF
$deadline = (Get-Date).AddSeconds($TimeoutSec)

while ((Get-Date) -lt $deadline) {
    if ($Dialog) {
        $box = [KrinikW]::FindDialog([uint32]$ProcessId)
        if ($box -ne [IntPtr]::Zero) {
            $lines = @([KrinikW]::Text($box), [KrinikW]::Text([KrinikW]::GetDlgItem($box, $MESSAGE_ITEM)), "defbutton=$([KrinikW]::DefaultButton($box))")
            if ($Out) { [System.IO.File]::WriteAllLines($Out, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false))) }
            if ($Press) {
                $ids = if ($Press -eq 'first') { @(1, 2) } else { @([int]$Press) }
                $button = [IntPtr]::Zero
                foreach ($i in $ids) { $button = [KrinikW]::GetDlgItem($box, $i); if ($button -ne [IntPtr]::Zero) { break } }
                if ($button -eq [IntPtr]::Zero) { throw "the box has no button $Press" }
                [void][KrinikW]::PostMessage($button, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
            }
            Write-Host "dialog read"
            exit 0
        }
    }
    else {
        $AE = [System.Windows.Automation.AutomationElement]
        $byPid = New-Object System.Windows.Automation.PropertyCondition($AE::ProcessIdProperty, $ProcessId)
        if ($Title) {
            $w = $AE::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $byPid)
            if ($w) {
                [System.IO.File]::WriteAllText($Out, $w.Current.Name, (New-Object System.Text.UTF8Encoding($false)))
                Write-Host "title read"
                exit 0
            }
        }
        elseif ($Close) {
            $w = $AE::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $byPid)
            if ($w) {
                # WM_SYSCOMMAND SC_CLOSE - what Alt+F4 and the system X send: WinForms reports it as UserClosing. A bare WM_CLOSE from outside is
                # TaskManagerClosing (stand 2026-11-17 22:06), not the player's path.
                [void][KrinikW]::PostMessage([IntPtr]$w.Current.NativeWindowHandle, 0x0112, [IntPtr]0xF060, [IntPtr]::Zero)
                Write-Host "SC_CLOSE posted"
                exit 0
            }
        }
        else {
        foreach ($w in $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $byPid)) {
            $found = @($w.FindAll([System.Windows.Automation.TreeScope]::Descendants,
                (New-Object System.Windows.Automation.PropertyCondition($AE::NameProperty, $Name))) |
                Where-Object { $_.Current.IsEnabled -and [KrinikW]::IsWindowVisible([IntPtr]$_.Current.NativeWindowHandle) } | Sort-Object { $_.Current.BoundingRectangle.X })
            if ($found.Count -gt $Index) {
                $hw = [IntPtr]$found[$Index].Current.NativeWindowHandle
                if ($Key) { [void][KrinikW]::PostMessage($hw, 0x0100, [IntPtr]$Key, [IntPtr]1); [void][KrinikW]::PostMessage($hw, 0x0101, [IntPtr]$Key, [IntPtr]0xC0000001) }
                else { [void][KrinikW]::PostMessage($hw, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) }
                Write-Host "pressed #$Index of $($found.Count)"
                exit 0
            }
        }
        }
    }
    Start-Sleep -Milliseconds 250
}
Write-Host "not found before $TimeoutSec s: $(if ($Dialog) { 'dialog' } else { "button #$Index" })"
exit 3
