-- freeze-npcs.lua — freeze (not kill) every humanoid NPC and listed wildlife within RADIUS_M of the hero: CustomTimeDilation 0 — they stop moving, thinking and
-- animating, no death, no ragdoll, no loot, no XP banner. For measurements: a kill pass makes the game stutter while it processes the deaths.
--   bash pult.sh "lua _G.__fz={radius=600}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/freeze-npcs.lua')"     · _G.__fz={undo=true} — unfreeze all frozen
-- Why (KUMM 2026-11-09, `[OWNER]` 00:46 «там всё сильно тормозит, когда убиваешь мобов - нельзя в это время замерять» · «или просто не убивай, а всех замораживай
-- на месте»). Search as quiet-stand.lua (class-name prefixes over the live Characters).
--
-- Ссылки на замороженных НЕ хранятся (KUMM 2026-11-09 16:06:32 — падение игры, EXCEPTION_ACCESS_VIOLATION в UE4SS): прежняя версия копила их в _G.__frozen
-- через пять пляжей, игра выгружала далёких NPC, и undo писал CustomTimeDilation в освобождённые объекты — нативное падение, pcall его не ловит.
-- Теперь undo заново находит ЖИВЫХ персонажей с CustomTimeDilation == 0 и возвращает им 1; каждый объект проверяется IsValid() до чтения.
-- [NOT-TESTED]
local a = _G.__fz or {}
local RADIUS_M = a.radius or 600
local PREFIXES = { "HumanoidNPCCharacter", "BP_NPC_Wildlife_", "BP_NightTerrors_" }
_G.__frozen = nil -- the old stale list, if a previous version left one in this Lua state
local hero = FindFirstOf("BasePlayerChar_C")
local function wanted(x)
  local cn = x:GetClass():GetFName():ToString()
  for _, pre in ipairs(PREFIXES) do if cn:sub(1, #pre) == pre then return true end end
  return false
end
local function live_wanted(x)
  if not (x and x:IsValid()) or x == hero then return false end
  local okf, f = pcall(function() return x:GetFullName() end)
  return okf and not f:find("Default__", 1, true) and select(2, pcall(wanted, x)) == true
end
local n = 0
if a.undo then
  for _, x in ipairs(FindAllOf("Character") or {}) do
    if live_wanted(x) and x.CustomTimeDilation == 0.0 then x.CustomTimeDilation = 1.0; n = n + 1 end
  end
  return 'unfrozen ' .. n
end
local h = hero:K2_GetActorLocation()
for _, x in ipairs(FindAllOf("Character") or {}) do
  if live_wanted(x) then
    local ok, l = pcall(function() return x:K2_GetActorLocation() end)
    if ok and l and math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2 + (l.Z - h.Z) ^ 2) / 100 <= RADIUS_M then
      x.CustomTimeDilation = 0.0; n = n + 1
    end
  end
end
return string.format('frozen %d within %d m', n, RADIUS_M)
