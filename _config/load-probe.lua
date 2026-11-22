-- load_probe.lua — a light twin of tp_widget_probe.lua (bug 79, R21a / R21b, 2026-11-22 20:xx): starts a load and samples the world time behind it.
-- _G.__lp_mode: 'tp' — the admin `TeleportPlayer X Y Z`; 'set' — K2_SetActorLocation of the heroine to X Y Z (a dungeon entrance trigger teleports her).
-- _G.__lp_x/_y/_z — the point; _G.__lp_module — a module opened BEFORE the action and left open (a waystone map 'WSEMap' stays open through its travel).
-- Every 100 ms (50 samples): IsFullscreenGUIActive, GetGlobalTimeDilation, the heroine's Z, live / in-viewport W_IngameLoadingScreen_C. No widget sweep.
-- Six answers (EFFICIENT_CODE §1): a one-shot probe of 5 s, never shipped. Result: load_probe.txt beside it; _G.__lp_done = true when written.
local OUT = [[D:/work/ai_sandbox/KUMM/.work/tmp/load_probe.txt]]
local MODE = _G.__lp_mode or "tp"
local X, Y, Z = _G.__lp_x or -253750, _G.__lp_y or 18150, _G.__lp_z or 3000
local SAMPLES, STEP_MS = 50, 100
local lines = {}
local function add(s) lines[#lines + 1] = s end
local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
local gmc = FindFirstOf("GUIModuleController")
local pc = FindFirstOf("FunCombat_PlayerController_C")
if not (gs and ksl and gmc and pc and gs:IsValid() and ksl:IsValid() and gmc:IsValid() and pc:IsValid()) then return "probe: a core object is missing" end
local function loading()
    local live, up = 0, 0
    for _, w in ipairs(FindAllOf("W_IngameLoadingScreen_C") or {}) do
        local okn, fn = pcall(function() return w:GetFullName() end)
        if okn and fn and not fn:find("Default__", 1, true) and not fn:find(":WidgetTree.", 1, true) then
            live = live + 1
            local ok, u = pcall(function() return w:IsInViewport() end)
            if ok and u then up = up + 1 end
        end
    end
    return live, up
end
local t0 = os.clock()
local function sample(i, no_chain)
    local fs, td, z = "?", "?", "?"
    pcall(function() fs = tostring(gmc:IsFullscreenGUIActive()) end)
    pcall(function() td = ("%.4f"):format(gs:GetGlobalTimeDilation(pc)) end)
    pcall(function() local p = pc:K2_GetPawn(); if p and p:IsValid() then z = ("%.0f"):format(p:K2_GetActorLocation().Z) end end)
    local live, up = loading()
    add(("#%02d t=%4.0fms fs=%s tdil=%s z=%s ld=%d/%d"):format(i, (os.clock() - t0) * 1000, fs, td, z, up, live))
    if no_chain then return end   -- the baseline sample: the chain starts once, after the action (two chains doubled every sample, 2026-11-22 20:06)
    if i < SAMPLES then
        ExecuteInGameThreadWithDelay(STEP_MS, function() local ok, e = pcall(sample, i + 1); if not ok then add("sample error: " .. tostring(e)) end end)
    else
        local f = io.open(OUT, "w")
        if f then f:write(table.concat(lines, "\n"), "\n"); f:close() end
        _G.__lp_done = true
    end
end
_G.__lp_done = false
if _G.__lp_module then
    local ok, e = pcall(function() gmc:ActivateModule(FName(_G.__lp_module), true, false) end)
    add(("module %s opened: %s"):format(_G.__lp_module, ok and "ok" or tostring(e)))
end
sample(0, true)
-- (the mode 'activate' — the trigger's InteractableActivate with a nil component — was removed 2026-11-22 21:0x: it did nothing on the Dregs triggers, which teleport
-- on overlap, and the same call crashed the game on a dialogue NPC; the remote refuses it now — guard no-nil-interactable)
if MODE == "set" then
    local ok, e = pcall(function() pc:K2_GetPawn():K2_SetActorLocation({ X = X, Y = Y, Z = Z }, false, {}, true) end)
    add(("set location %d %d %d: %s at t=%.0fms"):format(X, Y, Z, ok and "ok" or tostring(e), (os.clock() - t0) * 1000))
else
    ksl:ExecuteConsoleCommand(pc, ("TeleportPlayer %d %d %d"):format(X, Y, Z), pc)
    add(("teleport sent: %d %d %d at t=%.0fms"):format(X, Y, Z, (os.clock() - t0) * 1000))
end
ExecuteInGameThreadWithDelay(STEP_MS, function() local ok, e = pcall(sample, 1); if not ok then add("sample error: " .. tostring(e)) end end)
return "probe started (" .. MODE .. "): " .. SAMPLES .. " samples every " .. STEP_MS .. " ms"
