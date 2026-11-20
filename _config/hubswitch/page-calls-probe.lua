-- page-calls-probe.lua — which blueprint functions of the heavy hub pages run when a page is SHOWN (KUMM plan 48: the content is rebuilt on every show).
-- Arm AFTER every tab was visited once (the page classes are loaded then). Hooks every UFunction of the 4 page classes, logs «[pagecalls] swN Class:Fn»
-- for 600 ms after each CarouselWindow:OnChildActivated (each name once per switch). Read-only.
-- Run: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/hubswitch/page-calls-probe.lua')"  [NOT-TESTED]
if _G.__pagecalls then return 'already armed' end
_G.__pagecalls = true
local PAGES = {
    '/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C',
    '/Game/UI/Inventory/CraftingGUI.CraftingGUI_C',
    '/Game/UI/Inventory/Attributes/W_Attributes.W_Attributes_C',
    '/Game/UI/Widgets/Map/W_FullscreenMap.W_FullscreenMap_C',
}
local function L(m) print('[pagecalls] ' .. m .. string.char(10)) end
local on, sw, seen = false, 0, {}
RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    if on then return end
    sw = sw + 1; on = true; seen = {}
    ExecuteInGameThreadWithDelay(600, function() on = false end)
end)
local hooked, failed = 0, 0
for _, path in ipairs(PAGES) do
    local cls = StaticFindObject(path)
    if not (cls and cls:IsValid()) then L('not loaded: ' .. path) else   -- StaticFindObject returns an empty wrapper, not nil (23:39)
        local short = path:match('%.([%w_]+)$')
        cls:ForEachFunction(function(f)
            local fn = f:GetFName():ToString()
            local ok = pcall(function()
                RegisterHook(path .. ':' .. fn, function()
                    if on and not seen[short .. fn] then seen[short .. fn] = true; L(string.format('sw%d %s:%s', sw, short, fn)) end
                end)
            end)
            if ok then hooked = hooked + 1 else failed = failed + 1 end
        end)
    end
end
return string.format('armed; hooked %d functions, failed %d', hooked, failed)
