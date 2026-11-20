-- thrall-ghost-probe.lua — KUMM plan 45 step 8a, cases G3/G4: the placement ghost of a character as the game builds it, read back.
-- Run:  bash pult.sh "lua _G.__tg={mode='list', max_m=80}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/thrall-ghost-probe.lua')"
--       bash pult.sh "lua _G.__tg={mode='move', name='<NPC FName>'}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/thrall-ghost-probe.lua')"
--       bash pult.sh "lua _G.__tg={mode='ghost'}; return dofile(…)"   -- the ghost actor now on screen and its scale
--       bash pult.sh "lua _G.__tg={mode='stop'}; return dofile(…)"
-- mode list: live humanoid NPCs within max_m — FName, class, distance, scale, boss tags (FuncomGenericLibrary.GetActorGameplayTags, the call
--   Bosses My New Besties makes). mode move: the hero's ThrallSystemComponent:StartMovingThrall(npc) — the game's own path into ShowThrallPlaceable.
-- Nothing is kept in _G between calls but the input table (a dead actor is destroyed later — EXP-0386 class).
-- [NOT-TESTED]
local a = _G.__tg or { mode = 'list', max_m = 80 }
local p = FindFirstOf('BasePlayerChar_C')
if not p or not p:IsValid() then return 'no hero' end
local sys = p.BP_ThrallSystemComponent
if a.mode == 'list' then
  local lib = StaticFindObject('/Script/ConanSandbox.Default__FuncomGenericLibrary')
  local tagcls = StaticFindObject('/Script/GameplayTags.Default__BlueprintGameplayTagLibrary')
  local h = p:K2_GetActorLocation()
  local out = {}
  for _, x in ipairs(FindAllOf('HumanoidNPCCharacter_C') or {}) do
    local fn = x:GetFullName()
    if not fn:find('Default__', 1, true) and not fn:find('_GEN_VARIABLE', 1, true) then
      local ok, l = pcall(function() return x:K2_GetActorLocation() end)
      if ok and l then
        local d = math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2 + (l.Z - h.Z) ^ 2) / 100
        if d <= (a.max_m or 80) then
          local s = x:GetActorScale3D()
          -- HasTag из Lua с FGameplayTag-параметром UE4SS не вызывает (стек «boolean false, table» — 2026-11-06 13:58): теги читаются перебором
          local tags = lib:GetActorGameplayTags(x)
          local mini, world = false, false
          local arr = tags.GameplayTags
          for i = 1, (arr and #arr or 0) do
            local e = arr[i]
            if e.get then e = e:get() end
            local tn = e.TagName:ToString()
            if tn == 'Npc.Boss.Miniboss' then mini = true end
            if tn == 'Npc.Boss.WorldBoss' then world = true end
          end
          out[#out + 1] = string.format('%s %s %.1fm scale %.2f mini=%s world=%s', x:GetFName():ToString(), x:GetClass():GetFName():ToString(), d, s.X,
            tostring(mini), tostring(world))
        end
      end
    end
  end
  return #out .. ' NPC: ' .. table.concat(out, ' | ')
elseif a.mode == 'move' then
  local t
  for _, x in ipairs(FindAllOf('HumanoidNPCCharacter_C') or {}) do
    if x:GetFName():ToString() == a.name then t = x end
  end
  if not t then return 'gone ' .. tostring(a.name) end
  sys:StartMovingThrall(t)
  return 'StartMovingThrall ' .. a.name .. ' · placing=' .. tostring(sys.IsPlacingThrall) .. ' mode=' .. tostring(sys.ThrallPlacementMode)
elseif a.mode == 'show' then
  -- Прямой вызов того, что проверяется (память «Проверять прямым вызовом метода»): ShowThrallPlaceable с ThrallInfo, где задан только ряд
  -- таблицы спавна — из него игра строит персонажа призрака. a.row — имя ряда SpawnDataTable (Aesir_Boss — босс, которого вербует BMNB).
  local r = sys:ShowThrallPlaceable({ SpawnTableId = FName(a.row), ThrallTemplateID = a.template or 0, ThrallItemID = 0, IsFemale = false })
  -- возврат — актёр призрака (BP ставит рост именно ему: SetActorScale3D(CallFunc_ShowThrallPlaceable_ReturnValue)); тип в UE4SS — проверяем pcall
  local info = 'ret ' .. type(r)
  local ok, s = pcall(function() return r:GetActorScale3D() end)
  local ok2, nm = pcall(function() return r:GetFullName() end)
  if ok and s then info = info .. string.format(' · ghost %s scale %.3f %.3f %.3f', ok2 and nm or '?', s.X, s.Y, s.Z) end
  return 'show ' .. a.row .. ' · ' .. info
elseif a.mode == 'hook' then
  -- Обработчик на BP-функцию срабатывает ПОСЛЕ её тела (карта игры, раздел о RegisterHook BP-функций): возврат — актёр призрака, уже с ростом,
  -- который поставил наш код. Пишет в _G.__tg_seen; ставится один раз за запуск игры.
  if not _G.__tg_hooked then
    RegisterHook('/Game/Systems/Thrall/BP_ThrallSystemComponent.BP_ThrallSystemComponent_C:ShowThrallPlaceable', function(self, info, ret)
      local rec = { n = (_G.__tg_seen and _G.__tg_seen.n or 0) + 1 }
      pcall(function() rec.row = info:get().SpawnTableId:ToString() end)
      pcall(function()
        local g = ret:get()
        rec.ghost = g:GetFullName()
        local s = g:GetActorScale3D()
        rec.scale = string.format('%.3f %.3f %.3f', s.X, s.Y, s.Z)
      end)
      _G.__tg_seen = rec
    end)
    -- рост ставит SetActorScale3D(призрак, …) внутри ShowThrallPlaceable; пишем вызовы только пока идёт OnUseItem (_G.__tg_rec)
    RegisterHook('/Script/Engine.Actor:SetActorScale3D', function(self, scale)
      if not _G.__tg_rec then return end
      local rec = { who = '?', v = '?' }
      pcall(function() rec.who = self:get():GetFullName() end)
      pcall(function() local s = scale:get(); rec.v = string.format('%.3f %.3f %.3f', s.X, s.Y, s.Z) end)
      _G.__tg_scales = _G.__tg_scales or {}
      table.insert(_G.__tg_scales, rec)
    end)
    _G.__tg_hooked = true
  end
  return 'hooked'
elseif a.mode == 'seen' then
  local r = _G.__tg_seen
  if not r then return 'nothing seen' end
  local sc = {}
  for _, x in ipairs(_G.__tg_scales or {}) do sc[#sc + 1] = x.who .. ' = ' .. x.v end
  return string.format('call #%d row=%s · SetActorScale3D during use: %d · %s', r.n, tostring(r.row), #sc, table.concat(sc, ' ; '))
elseif a.mode == 'use' then
  -- путь игрока: предмет-раб из сумки (exec SpawnItem 25002 1 — «XX_Barkeeper Thrall Item», ряд Tavern_Barkeeper) → GameItem.OnUseItem.
  -- a.row — подменить ряд спавна предмета до использования (Aesir_Boss — босс, которого вербует BMNB); без a.row — ряд предмета как есть.
  local it
  for _, x in ipairs(FindAllOf('ThrallItem') or {}) do
    if not x:GetFullName():find('Default__', 1, true) then it = x end
  end
  if not it then return 'no thrall item (exec MakeMeAdmin; exec SpawnItem 25002 1)' end
  if a.row then it.ThrallInfo.SpawnTableId = FName(a.row) end
  local pc = FindFirstOf('FunCombat_PlayerController_C')
  _G.__tg_scales = {}
  _G.__tg_rec = true
  it:OnUseItem(p, pc)
  _G.__tg_rec = false
  return 'used item row=' .. it.ThrallInfo.SpawnTableId:ToString() .. ' · placing=' .. tostring(sys.IsPlacingThrall) .. ' mode=' .. tostring(sys.ThrallPlacementMode)
elseif a.mode == 'ghost' then
  -- призраки — актёры с «Placeable» в имени класса рядом с героем
  local out = {}
  for _, cn in ipairs({ 'PlaceableThrall_C', 'BP_PlaceableThrall_C', 'ThrallPlaceable_C' }) do
    for _, g in ipairs(FindAllOf(cn) or {}) do
      local ok, s = pcall(function() return g:GetActorScale3D() end)
      if ok and s and not g:GetFullName():find('Default__', 1, true) then out[#out + 1] = string.format('%s %.3f', g:GetFName():ToString(), s.X) end
    end
  end
  return 'ghosts: ' .. table.concat(out, ' | ') .. ' · placing=' .. tostring(sys.IsPlacingThrall)
elseif a.mode == 'stop' then
  return 'stop ' .. tostring(sys:StopPlacingThrall())
end
return 'unknown mode'
