-- input-bindings-probe.lua — KUMM wall jump (KrinikConanLocomotion `krinik_wall_jump`): which of the hero's jump input events is the PRESS and which the RELEASE.
-- The compiled blueprint keeps its input bindings in the class's `DynamicBindingObjects` → `InputActionDelegateBinding.InputActionDelegateBindings`
-- (UE: FBlueprintInputActionDelegateBinding — InputActionName, InputKeyEvent 0 Pressed · 1 Released · 2 Repeat · 3 DoubleClick, FunctionNameToBind).
-- `_G.__ibp_filter` — a plain substring of the action name (default 'Jump'); read-only, two named class objects (the hero, the combat base). Usage:
--   bash pult.sh "lua _G.__ibp_filter='Jump'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/input-bindings-probe.lua')"
-- [TESTED: 2026-11-14 16:3x · Jump: event 0 → _26, event 1 → _27; 'Action' → Dodge _35, Primary _9 / _10, Special _7 / _8, Secondary _5 / _6 ·
--  KUMM testcases/reports/2026-11-14_conan-wall-jump-press-order-and-real-space.md]
local filter = _G.__ibp_filter or 'Jump'
local out = {}
for _, path in ipairs({ '/Game/Characters/BasePlayerChar.BasePlayerChar_C', '/Game/Characters/BaseBPCombat.BaseBPCombat_C' }) do
    local cls = StaticFindObject(path)
    if not (cls and cls:IsValid()) then
        out[#out + 1] = path .. ': class not found'
    else
        local ok, err = pcall(function()
            local objs = cls.DynamicBindingObjects
            local n = 0
            objs:ForEach(function(_, o)
                local b = o:get()
                n = n + 1
                local cn = b:GetClass():GetFName():ToString()
                if cn == 'InputActionDelegateBinding' then
                    b.InputActionDelegateBindings:ForEach(function(_, e)
                        local r = e:get()
                        local name = r.InputActionName:ToString()
                        if name:find(filter, 1, true) then
                            out[#out + 1] = string.format('%s: %s event %d -> %s', path:match('%.(.+)$'), name, r.InputKeyEvent, r.FunctionNameToBind:ToString())
                        end
                    end)
                end
            end)
            out[#out + 1] = string.format('%s: %d binding objects', path:match('%.(.+)$'), n)
        end)
        if not ok then out[#out + 1] = path .. ': ' .. tostring(err) end
    end
end
return table.concat(out, ' | ')
