-- hero-funcs.lua — names of UFunctions on the hero and its quick bar that match a pattern (read-only; the remote's `funcs` fails on some classes).
-- Use: bash pult.sh "lua _G.__hf='Use|Equip|Hotbar|Shortcut'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/hero-funcs.lua')"
-- _G.__hf_obj='<class>' — scan the first object of that class instead (BP_PerkSystemComponent_C …).
-- [TESTED: 2026-11-08 · listed the hero's InpActEvt_* events and the perk component's AddBranchedPerk · KUMM report 2026-11-08_conan-attributes-uncapped-dead-shot.md]
local pat = _G.__hf or 'Use|Equip'
local p = FindFirstOf('PlayerController').Pawn
local out = {}
local function scan(obj, tag)
  if not obj or not obj:IsValid() then out[#out + 1] = tag .. ': none'; return end
  local cls = obj:GetClass()
  while cls and cls:IsValid() do
    cls:ForEachFunction(function(f)
      local n = f:GetFName():ToString()
      for alt in pat:gmatch('[^|]+') do if n:find(alt) then out[#out + 1] = tag .. '.' .. n; break end end
    end)
    cls = cls:GetSuperStruct()
  end
end
if _G.__hf_obj then scan(FindFirstOf(_G.__hf_obj), _G.__hf_obj) else
scan(p, 'hero')
scan(p.ShortcutBarInventory, 'bar')
end
return table.concat(out, ' ')
