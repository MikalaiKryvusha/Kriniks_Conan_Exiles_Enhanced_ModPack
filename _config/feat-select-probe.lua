-- feat-select-probe.lua — KUMM bug 101 item 4 (2026-11-14): when does the «Таланты» page get its selected-feat card?
-- Logs `[FSP]` lines into UE4SS.log: every `FeatWindow:SlotFeatSelectionChanged` (the page it fired on + the state of every live feat page), then a switch
-- by the native `CarouselWindow:SetCarouselIndex(_G.__fsp_tab or 1)` and 40 ticks of samples. A page's state: opacity, visibility, in viewport, the card's
-- `FeatNameView` text. Remote: `pult.sh "lua _G.__fsp_tab=1; return dofile('D:/work/ai_sandbox/ConanExiles/_config/feat-select-probe.lua')"` (the hub open).
-- Read-only on the game except the one switch. [NOT-TESTED]
local P = _G.__fsp or {}
_G.__fsp = P
local TICKS = 40

local function short(n) return (n or ''):match('([%w_]+)$') or tostring(n) end
local function card(w)
    local ok, t = pcall(function() return w.FeatNameView:GetText():ToString() end)
    return ok and t or '?'
end
local function pages()
    local out = {}
    for _, w in ipairs(FindAllOf('W_FeatWindow_C') or {}) do
        local ok, s = pcall(function()
            local n = w:GetFullName()
            if n:find('Default__', 1, true) then return nil end
            return string.format('%s op=%.2f vis=%d vp=%s card=[%s]', short(n), w:GetRenderOpacity(), w:GetVisibility(), tostring(w:IsInViewport()), card(w))
        end)
        if ok and s then out[#out + 1] = s end
    end
    for _, w in ipairs(FindAllOf('CraftingGUI_C') or {}) do        -- «Снаряжение»: when does the game's inventory page leave the screen?
        local ok, s = pcall(function()
            local n = w:GetFullName()
            if n:find('Default__', 1, true) then return nil end
            return string.format('GEAR %s op=%.2f vis=%d vp=%s', short(n):sub(-5), w:GetRenderOpacity(), w:GetVisibility(), tostring(w:IsInViewport()))
        end)
        if ok and s then out[#out + 1] = s end
    end
    return table.concat(out, ' | ')
end
local function log(fmt, ...) print('[FSP] ' .. string.format(fmt, ...) .. '\n') end

if not P.hooked then
    P.hooked = true
    RegisterHook('/Script/ConanSandbox.FeatWindow:SlotFeatSelectionChanged', function(self)
        local ok, n = pcall(function() return self:get():GetFullName() end)
        log('%.3f select on %s :: %s', os.clock(), ok and short(n) or '?', pages())
    end)
end
-- every other native handler of the window: counted per page, printed with each tick sample (per-item ones fire hundreds of times)
local OTHER = { 'SlotCategoryTabToggled', 'SlotFilterItem', 'SlotDimItem', 'SlotIntStatChanged', 'FeatItemAdded', 'SlotSearchTextChanged', 'SlotNextCategory',
    'SlotPrevCategory', 'SlotFeatClicked', 'SlotFeatInvoked', 'SlotCompareItems', 'ScrollRecipeView', 'SwitchPanelFocus' }
P.counts = P.counts or {}
if not P.hooked2 then
    P.hooked2 = true
    for _, fn in ipairs(OTHER) do
        pcall(RegisterHook, '/Script/ConanSandbox.FeatWindow:' .. fn, function(self)
            local ok, n = pcall(function() return short(self:get():GetFullName()) end)
            local k = fn .. '@' .. (ok and n:sub(-4) or '?')
            P.counts[k] = (P.counts[k] or 0) + 1
        end)
    end
end
local function counts()
    local t = {}
    for k, v in pairs(P.counts) do t[#t + 1] = k .. '=' .. v end
    table.sort(t)
    P.counts = {}
    return table.concat(t, ' ')
end

local car = nil
for _, w in ipairs(FindAllOf('W_Carousel_C') or {}) do
    local ok, live = pcall(function() return w:IsInViewport() end)
    if ok and live then car = w end
end
if not car then return 'no live carousel (open the hub first)' end
local tab = _G.__fsp_tab or 1
P.counts = {}                                        -- this run's counts only (judge 15:43)
log('%.3f switch to %d :: %s', os.clock(), tab, pages())
car:SetCarouselIndex(tab)
local n = 0
local function sample()
    ExecuteInGameThreadWithDelay(1, function()
        n = n + 1
        log('%.3f tick %d :: %s :: %s', os.clock(), n, pages(), counts())
        if n < TICKS then sample() end
    end)
end
sample()
return 'switched to ' .. tab
