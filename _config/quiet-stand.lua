-- quiet-stand.lua — a stand free of interference (HOUSE_RULES rule 11.2/11.6): kill every living humanoid NPC and every listed wildlife within RADIUS_M of the
-- hero, then report how many living ones remain. Run it right before a recording, again if «left» is not 0:
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/quiet-stand.lua')"
-- Born 2026-11-02 11:20 after `[OWNER]` «героя ебашат, а ты видео пишешь блять» · «отвратительно по-прежнему тестовое окружение настраиваешь»: the oasis respawns
-- humanoid fighters and crocodiles; only crocodiles were removed before the clip. Searches by concrete classes (never the ancestor BaseBPCombat_C — EXP-0386).
-- [TESTED: 2026-11-02 14:13 · the prefix pass killed 3 Night Terrors and an imp the old list missed; 0 characters left within 40 m · KUMM bugs/75 «Third try»]
local RADIUS_M = _G.__qs_radius or 60
-- 2026-11-02 14:13: a Night Terror and a wolf stood over the hero after a quiet stand (KUMM bug 75, third stand try) - the list of four classes missed them;
-- now ONE pass over the live Characters, matched by class-name prefix (templates skipped).
local PREFIXES = { "HumanoidNPCCharacter_C", "BP_NPC_Wildlife_", "BP_NightTerrors_" }
local hero = FindFirstOf("BasePlayerChar_C")
local h = hero:K2_GetActorLocation()
local killed, left = {}, 0
local function wanted(x)
    local cn = x:GetClass():GetFName():ToString()
    for _, pre in ipairs(PREFIXES) do if cn:sub(1, #pre) == pre then return true end end
    return false
end
do
    for _, x in ipairs(FindAllOf("Character") or {}) do
        local okf, f = pcall(function() return x:GetFullName() end)
        if okf and x ~= hero and not f:find("Default__", 1, true) and not f:find(":WidgetTree", 1, true) and select(2, pcall(wanted, x)) == true then
            local ok, l = pcall(function() return x:K2_GetActorLocation() end)
            local alive = true   -- unknown counts as ALIVE: a probe that cannot read it must not report a quiet stand
            pcall(function() if x:IsDead() then alive = false end end)
            if ok and l and alive and math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2 + (l.Z - h.Z) ^ 2) / 100 <= RADIUS_M then
                local k = pcall(function() x:KillCharacter(0, FText(""), hero, {}, 0.0, hero) end)
                if k then killed[#killed + 1] = x:GetFName():ToString() else left = left + 1 end
            end
        end
    end
end
return string.format("killed %d within %d m: %s · left alive %d", #killed, RADIUS_M, table.concat(killed, ", "), left)
