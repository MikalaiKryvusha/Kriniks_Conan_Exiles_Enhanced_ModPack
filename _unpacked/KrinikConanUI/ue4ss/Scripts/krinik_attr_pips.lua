--[[ krinik_attr_pips — KUMM plan 49 step 3: the perk pips of an attribute row follow the row's page (1–20, 21–40, …).
  Why Lua: the row (W_Attribute, our kit edit) pages by its member `Page`, but the pips are placed by the game's C++ at X = req / 20 × the bar width — a pip of a
  placeholder perk at 25 stood PAST the bar, on the right column (TC_conan_placeholder_perks_21_40_2026-11-10 P2, frame 11:42). Re-placing every pip needs a
  loop over the canvas children; the kit's graph API has no loop node (60 518 catalog names, no ForEach / macro call — plan 49 step 3 FORK), so the loop
  lives here, at the game's own events — HOUSE_RULES rule 8 (Lua UI only when the asset will not yield) and rule 24 (at the game's event, never a timer):
    * W_Attribute_C:PostPipsPlacedOnCanvas (post) — the C++ has just placed the pips: their X, Y and visibility are remembered as the ORIGINAL, then placed;
    * AttributeEntry:UpdatePipIcons (its POST callback — the first callback of a native hook is a pre-hook; the row's NATIVE parent) — runs BEFORE
      PostPipsPlacedOnCanvas at a placement (trace 12:3x: icons, then placed) and is the LAST step of every refresh of the row (UpdateView → UpdateModifiers → UpdatePipIcons in its EventGraph), the page
      arrows' clicks included (their click flows into the game's refresh signal; a click does NOT re-run the placement — remote count 2026-11-10 11:47:
      0 placements per click, 12 per window open). Not UpdateView: UpdatePipIcons sets every pip Visible after it — the first build hooked UpdateView and the
      stock pips came back on page 2 (TC P3, 12:1x, positions held, visibility lost).
  Placement on page p (allot = the row's MaxAttributePointAllotment, 20): a pip with lo < req ≤ lo + allot, lo = p × allot, keeps its original visibility at
  X = original X × (req − lo) / req (the C++ X is proportional to req); any other pip is Collapsed — the stock 1–20 pips (and the corruption pips, also ≤ 20)
  on page 1 only, placeholder perks 21–40 on page 2 only.
  Cost: the handlers run only when the attribute screen refreshes; os.clock sum and worst call logged at most once a minute (HOUSE_RULES rule 7).
  [NOT-TESTED]
]]

local MOD = "KrinikConanUI:AttrPips"
local ROW_CLASS = "/Game/UI/Inventory/Attributes/W_Attribute.W_Attribute_C"
local ROW_CLASS_NAME = "W_Attribute_C"
local PIP_ICONS = "/Script/ConanSandbox.AttributeEntry:UpdatePipIcons"   -- fires for every AttributeEntry; `timed` keeps W_Attribute_C only
local VISIBLE, COLLAPSED = 0, 1   -- ESlateVisibility
local DEFAULT_ALLOT = 20       -- W_Attribute.MaxAttributePointAllotment (CDO 20, plan 49 recon)
local OFFSCREEN_X = -100000    -- render translation of a pip of another page: drawn far left of any screen (the layout is untouched)
local STATS_EVERY_S = 60

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

-- row full name → { [pip full name] = { x, y, vis } } as the GAME made it. Rebuilt for a row at each C++ placement (dead pips leave — judge round 1, 2026-11-10).
-- Never our own values (judge round 1): X is taken only at the game's placement while the row is on page 0 (X ∝ req exactly: 5 → 214.5, 10 → 429.1,
-- 15 → 643.6, 20 → 858.2) or at a pip's first sight (untouched by us); a Collapsed visibility is never stored (Collapsed is ours, the game uses
-- Visible / Hidden — the corruption pips stand Hidden while the hero has no corruption).
local orig = {}
local stats = { calls = 0, sum = 0, worst = 0, at = nil }   -- the minute starts at the first call (from the load it fired at once)

local function each_pip(row, fn)
    local c = row.AttributeCanvas
    if not valid(c) then return end
    for i = 0, c:GetChildrenCount() - 1 do
        local pip = c:GetChildAt(i)
        if valid(pip) then
            local ok, req = pcall(function() return pip.AttributePointsRequired end)
            if ok and type(req) == "number" and req > 0 then fn(pip, req) end
        end
    end
end

-- what the game made of this pip, updated from what is observable as the game's now; `trust_x` — the row is on page 0
local function observe(o, pip, trust_x)
    if trust_x or not o.x then
        local p = pip.Slot:GetPosition()
        o.x, o.y = p.X, p.Y
    end
    local v = pip:GetVisibility()
    if v ~= COLLAPSED then o.vis = v elseif o.vis == nil then o.vis = VISIBLE end
    return o
end

local function place(row, placed)
    local page = row.Page or 0
    local allot = row.MaxAttributePointAllotment
    if type(allot) ~= "number" or allot <= 0 then allot = DEFAULT_ALLOT end
    local lo = page * allot
    local rkey = row:GetFullName()
    local old = orig[rkey] or {}
    local mine = placed and {} or old                       -- a fresh C++ placement: keep only the pips alive now
    orig[rkey] = mine
    each_pip(row, function(pip, req)
        local key = pip:GetFullName()
        -- X is the game's only right after ITS placement on page 0 (page 0 moves no X: in-window X = the remembered one, the rest only translated); a plain
        -- refresh on page 0 after a visit to page 2 still shows OUR moved X of the placeholders
        local o = observe(old[key] or {}, pip, placed and page == 0)
        mine[key] = o
        if req > lo and req <= lo + allot then
            pip.Slot:SetPosition({ X = o.x * (req - lo) / req, Y = o.y })
            pip:SetRenderTranslation({ X = 0, Y = 0 })
            if pip:GetVisibility() ~= o.vis then pip:SetVisibility(o.vis) end
        else
            -- out of this page: collapsed AND drawn far off the screen by its render translation. The collapse was undone at first because the hook on the
            -- native UpdatePipIcons ran as a PRE-hook and the game's own pass set the pips Visible after it (trace 12:3x); the hook is a post-hook now. The
            -- render translation stays as the second guard: it changes no layout, carries the hit test, and the game never sets it on a pip (frame q5, 12:2x).
            -- A far SLOT position is no way: the canvas measures its children, and the whole «Хар-ки» page shrank to a speck in its ScaleBox (frame q4).
            pip:SetRenderTranslation({ X = OFFSCREEN_X, Y = 0 })
            if pip:GetVisibility() ~= COLLAPSED then pip:SetVisibility(COLLAPSED) end
        end
    end)
end

local function timed(why, row)
    -- the native UpdatePipIcons fires for every AttributeEntry: only our paged rows (judge round 1)
    if not valid(row) or row:GetClass():GetFName():ToString() ~= ROW_CLASS_NAME then return end
    local t0 = os.clock()
    local ok, err = pcall(function() place(row, why == "placed") end)
    local dt = (os.clock() - t0) * 1000
    if not ok then log("%s: ERROR %s", why, tostring(err)) end
    stats.at = stats.at or t0
    stats.calls, stats.sum = stats.calls + 1, stats.sum + dt
    if dt > stats.worst then stats.worst = dt end
    if os.clock() - stats.at >= STATS_EVERY_S then
        log("минута: вызовов %d, всего %.2f мс, худший %.2f мс", stats.calls, stats.sum, stats.worst)
        stats.calls, stats.sum, stats.worst, stats.at = 0, 0, 0, os.clock()
    end
end

-- UpdatePipIcons is the NATIVE parent's function (/Script/ConanSandbox.AttributeEntry) — «no UFunction» on the blueprint path (remote 12:06). On a native
-- UFunction the FIRST callback is a PRE-hook: the trace 12:3x read the pip Collapsed in it and Visible in the second one — UpdatePipIcons itself sets the pips'
-- visibility. So the work goes into the SECOND (post) callback, after the game's own pass (judge round 2, verified live). The native class exists from the
-- start, so this hook is set at load — the first window's placement is never missed (judge round 3); the blueprint event needs its class loaded first.
local ok2, e2 = pcall(RegisterHook, PIP_ICONS, function() end, function(self) timed("icons", self:get()) end)
log("hook UpdatePipIcons (post): %s", ok2 and "ok" or tostring(e2))

local hooked = false
NotifyOnNewObject(ROW_CLASS, function(w)
    if hooked or w:GetFullName():find("Default__", 1, true) then return end
    hooked = true
    ExecuteInGameThread(function()
        local ok1, e1 = pcall(RegisterHook, ROW_CLASS .. ":PostPipsPlacedOnCanvas", function(self) timed("placed", self:get()) end)
        log("hook PostPipsPlacedOnCanvas: %s", ok1 and "ok" or tostring(e1))
    end)
end)

log("loaded: the pips follow the row's page (hooks set at the first W_Attribute)")
