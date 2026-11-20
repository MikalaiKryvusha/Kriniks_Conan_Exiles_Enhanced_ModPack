-- close-hub.lua — close the inventory hub by the remote the way the game itself closes it (KUMM bug 102, 2026-11-14).
-- Why: the native Tab that OPENS the inventory adds one IgnoreMoveInput and one IgnoreLookInput to the PlayerController; the Tab that closes it removes them.
-- `GUIModuleController:ActivateModule(FName('Inventory'), false, false)` closes the module but removes neither, and leaves the hub carousel alive — after a
-- real-Tab open and that remote close the hero stood frozen (no walk, no jump, no look; bug 102 E1 / E3), and the next real Tab CLOSED the leftover carousel
-- instead of opening the hub. The game's own `ForceDeactivateFullscreenModules()` closes EVERY fullscreen module (the hub, our settings window, containers,
-- traders) and releases the input within ≈ 1 s (17:3x: flags set right after the call, clear 1 s later).
-- After CHECK_MS the tool reports the flags, the inventory module and the carousels in the viewport; it resets the two ignores ONLY when they were set before
-- the call, are still set, and the inventory module is not active again (a hub reopened by a real Tab in that second keeps its own ignores). The reset
-- clears every ignore on the controller. `ToggleModule(FName('Inventory'))` does nothing (the Tab action is native).
-- Usage: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/hubswitch/close-hub.lua')" ; 2 s later: bash pult.sh "lua return _G.__close_hub.text"
-- Judge 2026-11-14 17:4x: the callback re-checks the controller and runs under pcall; a fresh result table per call; 'pending' set before any early return.
-- [NOT-TESTED] this version (the 17:36 version ran: «before: move true look true · 1 s after the force-close: move false look false · no reset needed»)
local CHECK_MS = 1500                                -- the release was seen at 1 s; a margin, so the fallback reset is not mistaken for the main path (judge round 5)
local R = { text = 'pending' }
_G.__close_hub = R
local pc = FindFirstOf('PlayerController')
local gc = FindFirstOf('GUIModuleController')
if not (pc and pc:IsValid() and gc and gc:IsValid()) then R.text = 'no controller'; return R.text end
local function flags() return pc:IsMoveInputIgnored(), pc:IsLookInputIgnored() end
local function carousels()
    local n = 0
    for _, c in ipairs(FindAllOf('CarouselWindow') or {}) do
        if c:IsValid() and not c:GetFullName():find('Default__', 1, true) and c:IsInViewport() then n = n + 1 end
    end
    return n
end
local okf, m0, l0 = pcall(flags)
if not okf then R.text = 'flags read failed: ' .. tostring(m0); return R.text end
local ok, err = pcall(function() gc:ForceDeactivateFullscreenModules() end)
if not ok then R.text = 'ForceDeactivateFullscreenModules failed: ' .. tostring(err); return R.text end
ExecuteInGameThreadWithDelay(CHECK_MS, function()
    local ok2, err2 = pcall(function()
        if not pc:IsValid() then R.text = 'controller gone'; return end
        local m1, l1 = flags()
        local hubs = carousels()                     -- for the report only: a properly closed hub's carousel stays in the viewport too (E1, 17:32)
        local reopened = gc:IsValid() and gc:IsModuleActive(FName('Inventory'))
        local reset = (m0 or l0) and (m1 or l1) and not reopened
        if reset then pc:ResetIgnoreMoveInput(); pc:ResetIgnoreLookInput() end
        local m2, l2 = flags()
        R.text = string.format('before: move %s look %s · %d ms after the force-close: move %s look %s, inventory module %s, carousels in viewport %d · %s',
            tostring(m0), tostring(l0), CHECK_MS, tostring(m1), tostring(l1), reopened and 'ACTIVE (reopened)' or 'closed', hubs,
            reset and string.format('reset → move %s look %s', tostring(m2), tostring(l2)) or 'no reset')
    end)
    if not ok2 then R.text = 'check failed: ' .. tostring(err2) end
end)
return 'closing; read _G.__close_hub.text in 2 s'
