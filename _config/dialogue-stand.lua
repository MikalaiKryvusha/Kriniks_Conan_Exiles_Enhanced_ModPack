-- dialogue-stand.lua — the stand for a talk with an NPC (KUMM issue #3, case D1 of testcases/TC_conan_hub_game_pages_map_journey_2026-11-20.md;
-- the «talk to an NPC» row of the play matrix testcases/TC_conan_play_matrix.md).
--   bash pult.sh "lua _G.__ds_mode='find'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/dialogue-stand.lua')"
-- _G.__ds_mode:
--   'find'  — the nearest live BP_HumanoidDialogueNPC_C (several live in the world, one 4.5 km off — take the NEAREST): name, distance, place;
--   'place' — the hero 2 m from that NPC on the hero's own side, the view turned to the NPC (the talk prompt shows only within ≈ 3 m);
--   'speed' — the world's pace now: the global time dilation, the time of day, the open dialogue window, the NPC's place.
-- Matching by the FULL NAME before any method call on an actor (EXP-0386/0387: a method on a non-matching object can fault).
-- [NOT-TESTED]
local MODE = _G.__ds_mode or "find"
local NPC_CLASS = _G.__ds_class or "BP_HumanoidDialogueNPC_C"   -- e.g. BP_HumanoidDialogueNPC_Sorcerer_Companion_C (a talker with reply options)
local FAR = _G.__ds_far
-- one call only: _G survives between remote calls, and a class or a far permission left from an earlier call carried the hero 4.5 km on 2026-11-20 20:43
-- (judge round 2026-11-20 21:14)
_G.__ds_class, _G.__ds_far = nil, nil
local STAND_OFF_CM = 200        -- 2 m: inside the ≈ 3 m reach of the talk prompt
local MAXD_M = 5000
local PLACE_MAX_M = 300         -- «place» refuses a farther talker unless _G.__ds_far is set (2026-11-20 20:43: a surprise 4.5 km trip into corruption)

local p = FindFirstOf("BasePlayerChar_C")
local pc = FindFirstOf("FunCombat_PlayerController_C")
if not (p and p:IsValid() and pc and pc:IsValid()) then return "no hero / controller" end
local h = p:K2_GetActorLocation()

local function nearest()
    local best, bd, bl
    -- FindAllOf of the class: no walk over every Actor (judge round 1). It returns SUBCLASSES too — on 2026-11-20 20:43 the corrupted sorcerer companion
    -- (BP_HumanoidDialogueNPC_Sorcerer_Companion_C, 4.5 km) was the only one loaded at world entry and «place» carried the heroine into its corruption plant.
    -- So the full name must START with the class name: the exact class only.
    for _, x in ipairs(FindAllOf(NPC_CLASS) or {}) do
        local f = x:GetFullName()
        if f:sub(1, #NPC_CLASS + 1) == NPC_CLASS .. " " and not f:find("Default__", 1, true) then
            local ok, l = pcall(function() return x:K2_GetActorLocation() end)
            if ok and l then
                local d = math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2 + (l.Z - h.Z) ^ 2) / 100
                if d <= MAXD_M and (not bd or d < bd) then best, bd, bl = x, d, l end
            end
        end
    end
    return best, bd, bl
end

if MODE == "find" then
    local n, d, l = nearest()
    if not n then return "no " .. NPC_CLASS .. " within " .. MAXD_M .. " m" end
    return string.format("%s at %.1f m, place (%.0f, %.0f, %.0f); hero (%.0f, %.0f, %.0f)", n:GetFName():ToString(), d, l.X, l.Y, l.Z, h.X, h.Y, h.Z)
end

if MODE == "place" then
    local n, d, l = nearest()
    if not n then return "no " .. NPC_CLASS end
    -- a stand never carries the hero across the map by surprise: farther than PLACE_MAX_M only with _G.__ds_far = true
    if d > PLACE_MAX_M and not FAR then
        return string.format("REFUSED: the nearest %s is %.0f m away (more than %d m) — set _G.__ds_far = true to go there", NPC_CLASS, d, PLACE_MAX_M)
    end
    local dx, dy = h.X - l.X, h.Y - l.Y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then dx, dy, len = 1, 0, 1 end
    local tx, ty = l.X + dx / len * STAND_OFF_CM, l.Y + dy / len * STAND_OFF_CM
    local yaw = math.deg(math.atan(l.Y - ty, l.X - tx))
    local moved = p:K2_TeleportTo({ X = tx, Y = ty, Z = l.Z + 20 }, { Pitch = 0.0, Yaw = yaw, Roll = 0.0 })
    pc:SetControlRotation({ Pitch = -5.0, Yaw = yaw, Roll = 0.0 })
    return string.format("teleport %s: hero 2 m from %s (was %.1f m), yaw %.1f", tostring(moved), n:GetFName():ToString(), d, yaw)
end

if MODE == "speed" then
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local dil = "?"
    pcall(function() dil = ("%.4f"):format(gs:GetGlobalTimeDilation(pc)) end)
    local tod = "?"
    local tm = FindFirstOf("BP_TimeOfDayManager_C")
    if tm and tm:IsValid() then pcall(function() tod = ("%.4f"):format(tm:GetTimeOfDay()) end) end
    local gm = FindFirstOf("GUIModuleController")
    local dlg = "?"
    -- the game's two NPC talk windows (live DT_UIModuleTable 2026-11-20): the oasis campfire talk opens the second one
    if gm and gm:IsValid() then pcall(function()
        dlg = tostring(gm:IsModuleActive(FName("NPCDialogueWindow")) or gm:IsModuleActive(FName("NPCDialogueWindow2")))
    end) end
    -- the NPC is found again on every call: a reference kept between remote calls is a raw pointer that dies when the NPC streams out (judge round 1)
    local n, _, l = nearest()
    local npl = n and string.format("%s (%.0f, %.0f, %.0f)", n:GetFName():ToString(), l.X, l.Y, l.Z) or "no npc"
    return string.format("clock %.3f · dilation %s · time of day %s · dialogue open %s · npc %s", os.clock(), dil, tod, dlg, npl)
end

return "unknown mode " .. tostring(MODE)
