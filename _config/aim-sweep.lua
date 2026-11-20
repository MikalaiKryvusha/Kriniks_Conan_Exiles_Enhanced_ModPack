-- aim-sweep.lua — aim at what the GAME says it targets, not by arithmetic (KUMM bug 75; `[OWNER]` 2026-11-03 20:38 «когда ты нахуй нормально сможешь уже
-- игрой управлять? видеть, куда ты идешь, куда смотришь»). The view steps through pitch × yaw around its current direction, one step per STEP_MS on the game
-- thread; after each step the game's own answer is read — the module ContainerInfo (the corpse / container strip with the quick-loot window) active in
-- GUIModuleController — and the sweep STOPS on the first «yes», keeping that view. The game must hold the focus meanwhile (the strip shows only then) —
-- run it while `mouse-seq.ps1 -Seq "wait:<ms>"` holds the game in front. Result: _G.__aim_sweep = 'hit pitch P yaw Y' | 'miss' (read it by a second call).
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/aim-sweep.lua')"
-- _G.__as_target (default 'ContainerInfo') — another module to look for. [NOT-TESTED]
local STEP_MS = _G.__as_step_ms or 300   -- 120 ms missed twice: the game updates its interaction target slower (20:5x)
local PITCH = _G.__as_pitch or { -6, -3, 0, 3, 6, 9, 12, 15, 18 }   -- degrees around the start pitch
local YAW = _G.__as_yaw or { 0, -3, 3, -6, 6 }
local pc = FindFirstOf("FunCombat_PlayerController_C")
local gui = FindFirstOf("GUIModuleController")
local target = FName(_G.__as_target or "ContainerInfo")
local r0 = pc:GetControlRotation()
local p0 = r0.Pitch > 180 and r0.Pitch - 360 or r0.Pitch
local y0 = r0.Yaw
local steps = {}
for _, dy in ipairs(YAW) do for _, dp in ipairs(PITCH) do steps[#steps + 1] = { p0 + dp, y0 + dy } end end
_G.__aim_sweep = "running"
local i = 0
-- The game's answer: the module flag, or any live game-made strip WBP_ContainerInfo_C in the viewport and visible (20:4x: the module flag alone gave «miss»).
local function game_targets()
    if gui:IsModuleActive(target) then return true end
    for _, w in ipairs(FindAllOf("WBP_ContainerInfo_C") or {}) do
        local f = w:GetFullName()
        if not f:find("Default__", 1, true) and f:find("Transient", 1, true) and w ~= _G.__stripOpen then
            local ok, on = pcall(function() return w:IsInViewport() and w:IsVisible() end)
            if ok and on then return true end
        end
    end
    return false
end
local function step()
    if game_targets() then
        local r = pc:GetControlRotation()
        _G.__aim_sweep = string.format("hit pitch %.1f yaw %.1f (step %d of %d)", r.Pitch > 180 and r.Pitch - 360 or r.Pitch, r.Yaw, i, #steps)
        return
    end
    i = i + 1
    if i > #steps then pc:SetControlRotation({ Pitch = p0, Yaw = y0, Roll = 0.0 }); _G.__aim_sweep = "miss"; return end
    pc:SetControlRotation({ Pitch = steps[i][1], Yaw = steps[i][2], Roll = 0.0 })
    ExecuteInGameThreadWithDelay(STEP_MS, step)
end
step()
return "sweep started: " .. #steps .. " steps"
