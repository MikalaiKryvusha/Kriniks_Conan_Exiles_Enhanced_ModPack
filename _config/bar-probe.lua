-- One-off probe (2026-10-29, KUMM bug 64 item 17 class A): switch the hub tab, then for 12 short steps on the game thread log every visible
-- bottom-bar button: its desired width, its label width, and its hotkey icon's parts. A chain of one-shot delayed calls ends by itself.
-- (GeneralText:GetText is not reachable from the remote — "TrivialObject", 21:4x — so texts are not read.)
local VIS = { [0] = 'V', 'C', 'H', 'hti', 'shti' }
local t0 = os.clock()
local function vis(w) local ok, v = pcall(function() return w:GetVisibility() end); return ok and (VIS[v] or tostring(v)) or '?' end
local function width(w) local ok, v = pcall(function() return w:GetDesiredSize().X end); return ok and string.format('%.1f', v) or '?' end
local function snap(step)
  local rows = {}
  for _, b in ipairs(FindAllOf('WBP_ButtonBase_C') or {}) do
    local ok, line = pcall(function()
      local full = b:GetFullName()
      if not full:find('WBP_ButtonBar', 1, true) then return nil end
      if not b:IsVisible() then return nil end
      local h = b.HotkeyIcon
      return string.format('%s btn=%s lbl=%s key=%s name=%s prim=%s/%s wo=%.1f sec=%s img=%s', full:match('[^.]+$'), width(b), width(b.TxtLabel),
        width(h), vis(h.TextBlockBindingName), vis(h.SizeBoxPrimaryIcon), width(h.SizeBoxPrimaryIcon), h.SizeBoxPrimaryIcon.WidthOverride,
        vis(h.SizeBoxSecondaryIcon), width(h.ImagePrimary))
    end)
    if ok and line then rows[#rows + 1] = line elseif not ok then rows[#rows + 1] = 'ERR ' .. tostring(line) end
  end
  print(string.format('[barprobe] step %d +%.0f ms: %d rows', step, (os.clock() - t0) * 1000, #rows))
  for i, r in ipairs(rows) do if i <= 8 then print('[barprobe]   ' .. r) end end
end
local function chain(step)
  snap(step)
  if step < 12 then ExecuteInGameThreadWithDelay(8, function() chain(step + 1) end) end
end
ExecuteInGameThread(function()
  -- BARPROBE_DIR = 'Prev' before dofile goes left (the carousel does not wrap: Next on «Базар» does nothing)
  local c = FindFirstOf('W_Carousel_C')
  if BARPROBE_DIR == 'Prev' then c:PrevCarouselWindow() else c:NextCarouselWindow() end
  chain(0)
end)
return 'probe armed'
