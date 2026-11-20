-- hub-page-compare.lua — is OUR kept hub page of a tab stale against the game's own newborn page of the same tab? (KUMM bug 97 — the twin list)
-- Why (2026-11-14): KrinikConanUI's hub controller keeps one instance of seven tabs for the whole world session and hides the game's page that is born
-- fresh at every switch; «Путешествие» showed the data of its birth (bug 97). The other tabs are checked by the same method: show the tab, change the state
-- the way the player does, show the tab again, and compare both instances widget by widget — a difference is a stale page.
--   bash _config/pult.sh "lua _G.__hpc_tab=3; return dofile('D:/work/ai_sandbox/ConanExiles/_config/hub-page-compare.lua')"
-- _G.__hpc_tab — the controller's tab index: 2 Таланты · 3 Хар-ки · 5 Путешествие · 6 Клан · 7 Спутники · 8 Карта · 9 Базар.
-- Which instance is ours: the remote has its own Lua state (EXP-0438), so it goes by what the controller does on a shown tab — OUR page at render opacity 1
-- and SelfHitTestInvisible, the game's newborn at 0 and HitTestInvisible, both in the viewport; exactly 2 such candidates or a refusal (names printed).
-- v2 (2026-11-14 12:5x, judge round 2): a widget belongs to a page when its PARENT chain reaches the page — not when its name starts with the page's path:
-- list entries made with an owning player (`CreateWidget(pc, …)` — journey cards, followers, store tiles) are outered to the game instance and v1 dropped
-- them from both sides (tab 5 counted 64 widgets with 40 cards on it). The walk goes up by GetParent and, at the root of a nested user widget's tree, through
-- its WidgetTree to that user widget, then on by ITS parent. On the way: a Collapsed / Hidden ancestor, or a WidgetSwitcher whose active child is not on the
-- path, makes the widget «hidden branch» (not on screen whatever its own flag). Templates (`…_C:WidgetTree.…`) and defaults are skipped by name BEFORE any
-- property is read (EXP-0386). Compared per widget: TextBlock text + visibility, Button visibility + enabled, Image visibility + opacity — keyed by the path of
-- names from the page down (runtime numeric suffixes cut), as multisets.
-- GAP: brush, colour, progress and RichText are not compared (a look made by a tint alone — check by a frame pair); fields of one entry are separate lines, so
-- two entries that swapped values count as equal; a ListView entry with no UMG parent is not reached (the count of unreached widgets is printed).
-- [NOT-TESTED]
local SHORT = { [2] = 'W_FeatWindow_C', [3] = 'W_Attributes_C', [5] = 'W_NewJourneyWindow_C', [6] = 'W_GuildView_C', [7] = 'W_FollowersView_C',
  [8] = 'W_FullscreenMap_C', [9] = 'W_StoreWindow_C' }
local MAX_LINES = 12
local MAX_DEPTH = 64
local tab = _G.__hpc_tab; _G.__hpc_tab = nil
local cls = SHORT[tab or 0]
if not cls then return 'set _G.__hpc_tab to 2, 3, 5, 6, 7, 8 or 9' end

local function prefix(full) return (full:gsub('^%S+%s+', '')) end   -- «Class /Path.Obj» → the object path
local function live_name(full) return not (full:find('Default__', 1, true) or full:find('_C:WidgetTree', 1, true)) end

local ours, game, candidates = nil, nil, 0
for _, w in ipairs(FindAllOf(cls) or {}) do
    local okn, name = pcall(function() return w:GetFullName() end)
    if okn and live_name(name) then                   -- the name first, the properties after (EXP-0386; judge round 3)
        -- the roles by what the controller sets on a TAKEN tab: ours SelfHitTestInvisible (4) at opacity 1, the game's newborn HitTestInvisible (3) at
        -- opacity 0; a Collapsed page (ours before the controller took the tab) is no candidate — by opacity alone the roles swapped then (judge round 4)
        local ok, inv, op, vis = pcall(function() return w:IsInViewport(), w:GetRenderOpacity(), w:GetVisibility() end)
        if ok and inv and vis ~= 1 then
            candidates = candidates + 1
            if op > 0.5 and vis == 4 then ours = ours or prefix(name) elseif op <= 0.5 and vis == 3 then game = game or prefix(name) end
        end
    end
end
if candidates ~= 2 or not ours or not game then
    return string.format('tab %d: %d live candidates (want 2), ours=%s game=%s — show the tab in an open hub first', tab, candidates, tostring(ours), tostring(game))
end
local SWITCHER = StaticFindObject('/Script/UMG.WidgetSwitcher')
local PAGES = { [ours] = true, [game] = true }
local VIS = { [0] = 'vis', [1] = 'coll', [2] = 'hid', [3] = 'hti', [4] = 'shti' }
local HIDDEN = { [1] = true, [2] = true }
local function short(o) local ok, n = pcall(function() return o:GetFName():ToString() end); return ok and (n:gsub('_%d%d%d%d%d%d+', '')) or '?' end
local function path_of(o) local ok, f = pcall(function() return prefix(o:GetFullName()) end); return ok and f or nil end

-- up from w to a page: returns page path, key (names from the page down), hidden flag — or nil when no page is reached
local function climb(w)
    local names, hidden, cur = { short(w) }, false, w
    for _ = 1, MAX_DEPTH do
        local okp, p = pcall(function() return cur:GetParent() end)
        if not (okp and p and p:IsValid()) then
            -- no panel parent: only the ATTACHED root of a widget tree goes on to the tree's user widget; a released pool entry or a widget taken off by
            -- RemoveFromParent keeps the tree as its outer but is not on screen (judge round 3) — it is not counted
            local ok2, tree = pcall(function() return cur:GetOuter() end)
            local ok4, root = pcall(function() return tree.RootWidget end)
            if not (ok2 and ok4 and root and root:IsValid() and path_of(root) == path_of(cur)) then return nil end
            local ok3, uw = pcall(function() return tree:GetOuter() end)
            if not (ok3 and uw and uw:IsValid()) then return nil end
            p = uw
        else
            local okc, isw = pcall(function() return p:IsA(SWITCHER) end)
            if okc and isw then
                local oka, act = pcall(function() return p:GetActiveWidget() end)
                if oka and act and act:IsValid() and path_of(act) ~= path_of(cur) then hidden = true end
            end
        end
        local pp = path_of(p)
        if pp and PAGES[pp] then
            local key = {}
            for k = #names, 1, -1 do key[#key + 1] = names[k] end
            return pp, table.concat(key, '/'), hidden
        end
        local okv, v = pcall(function() return p:GetVisibility() end)
        if okv and HIDDEN[v] then hidden = true end
        names[#names + 1] = short(p)
        cur = p
    end
    return nil
end

local bag = { [ours] = {}, [game] = {} }
local reached, unreached = 0, 0
-- The probe's own control: _G.__hpc_poison = true sets the first shown TextBlock of a NESTED entry (4+ names deep — a card, a row) of the GAME's newborn
-- page to «PROBE» for the read — that page is thrown away at the next switch, while SetText on OUR kept page would unbind a designer text binding for
-- the rest of the session (judge round 3); the text is put back after; the result must show that one line on each side.
local poison = _G.__hpc_poison; _G.__hpc_poison = nil
local poisoned = nil
local function scan(class, kind, value_of)
    for _, w in ipairs(FindAllOf(class) or {}) do
        local okn, full = pcall(function() return w:GetFullName() end)
        if okn and live_name(full) then
            local page, key, hidden = climb(w)
            if page then
                reached = reached + 1
                if poison and not poisoned and kind == 'T' and page == game and not hidden and select(2, key:gsub('/', '')) >= 3
                    and (poison == true or key:find(poison, 1, true)) then   -- a string = a part of the key (a list entry's class)
                    local okt, txt = pcall(function() return w:GetText():ToString() end)
                    if okt and txt ~= '' then poisoned = { w, txt, key }; pcall(function() w:SetText(FText('PROBE')) end) end
                end
                local ok, v = pcall(value_of, w)
                local line = kind .. ' ' .. key .. ' = ' .. (hidden and 'hidden branch' or (ok and v or '?'))
                bag[page][line] = (bag[page][line] or 0) + 1
            else
                unreached = unreached + 1
            end
        end
    end
end
local scanned, scan_err = pcall(function()           -- the restore below runs even when a scan throws
    scan('TextBlock', 'T', function(t) return (VIS[t:GetVisibility()] or '?') .. ' «' .. t:GetText():ToString() .. '»' end)
    scan('Button', 'B', function(b) return (VIS[b:GetVisibility()] or '?') .. (b:GetIsEnabled() and ' on' or ' off') end)
    scan('Image', 'I', function(im) return (VIS[im:GetVisibility()] or '?') .. string.format(' %.2f', im:GetRenderOpacity()) end)
end)
if poisoned then pcall(function() poisoned[1]:SetText(FText(poisoned[2])) end) end
if not scanned then return 'scan failed: ' .. tostring(scan_err) end
local a, b = bag[ours], bag[game]
local function count(t) local n = 0; for _, c in pairs(t) do n = n + c end; return n end
local function minus(x, y)
    local out = {}
    for line, c in pairs(x) do local d = c - (y[line] or 0); if d > 0 then out[#out + 1] = (d > 1 and (d .. '× ') or '') .. line end end
    table.sort(out)
    return out
end
local only_a, only_b = minus(a, b), minus(b, a)
local parts = { string.format('tab %d %s: ours %d widgets, game %d; only ours %d, only game %d (candidates %d; ours …%s, game …%s; live widgets not under either page %d)',
    tab, cls, count(a), count(b), #only_a, #only_b, candidates, ours:sub(-12), game:sub(-12), unreached) }
for k = 1, math.min(MAX_LINES, #only_a) do parts[#parts + 1] = '  OURS ' .. only_a[k] end
for k = 1, math.min(MAX_LINES, #only_b) do parts[#parts + 1] = '  GAME ' .. only_b[k] end
return table.concat(parts, '\n')
