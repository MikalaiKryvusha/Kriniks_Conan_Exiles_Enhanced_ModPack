-- page-births-probe.lua — with the tab windows kept (KrinikHubPersistTest), what a page RE-CREATES on each show (KUMM plan 48). Read-only.
-- On every CarouselWindow:OnChildActivated: counts UserWidget births by class for 600 ms and logs the top classes; once, lists the UFunctions of the
-- native WindowRoot (the tab windows' parent) — the candidates for «refresh on show». Log prefix «[pagebirths]».
-- Run: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/hubswitch/page-births-probe.lua')"  [NOT-TESTED]
if _G.__pagebirths then return 'already armed' end
_G.__pagebirths = true
local function L(m) print('[pagebirths] ' .. m .. string.char(10)) end
local counting, counts, sw = false, {}, 0
NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    if not counting then return end
    local ok, c = pcall(function() return w:GetClass():GetFName():ToString() end)
    c = ok and c or '?'
    counts[c] = (counts[c] or 0) + 1
end)
RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    if counting then return end
    sw = sw + 1
    counting, counts = true, {}
    local n = sw
    ExecuteInGameThreadWithDelay(600, function()
        counting = false
        local list, total = {}, 0
        for c, k in pairs(counts) do list[#list + 1] = { c, k }; total = total + k end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local parts = {}
        for i = 1, math.min(10, #list) do parts[#parts + 1] = list[i][1] .. '=' .. list[i][2] end
        L(string.format('sw%d births %d: %s', n, total, table.concat(parts, ' ')))
    end)
end)
local fns = {}
local wr = StaticFindObject('/Script/ConanSandbox.WindowRoot')
if wr then wr:ForEachFunction(function(f) fns[#fns + 1] = f:GetFName():ToString() end) end
L('WindowRoot functions: ' .. table.concat(fns, ' '))
return 'armed; WindowRoot functions ' .. #fns
