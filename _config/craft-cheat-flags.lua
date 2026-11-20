-- craft-cheat-flags.lua — READ-ONLY (KUMM bug 94): why does the hero craft instantly on the owner's new world? Lists the boolean and number properties of the
-- hero (BasePlayerChar_C) and his controller (FunCombat_PlayerController_C), walking each class up to Object, whose names hold Craft, Cheat, Free, Admin, God
-- or Instant — an admin flag left on in the save is the first hypothesis.
-- Use: bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/craft-cheat-flags.lua')"
-- Other words (2026-11-14, KUMM plan 53 step 14 — the hero's weight): set _G.__ccf_words = { 'encumb' } before the dofile; the global is cleared at once
-- (the remote keeps one Lua state — a word list left set would silently narrow the next default run) and the words are compared lower-cased.
-- GAP: only the hero's and the controller's own number / bool properties — components and object references are not walked, so «no matching property»
-- is not proof that the game keeps no such value (it may live in a component).
-- [NOT-TESTED]
local WORDS = _G.__ccf_words or { 'craft', 'cheat', 'free', 'admin', 'god', 'instant' }
_G.__ccf_words = nil
for k, w in ipairs(WORDS) do WORDS[k] = w:lower() end
local function hit(n) n = n:lower(); for _, w in ipairs(WORDS) do if n:find(w, 1, true) then return true end end end
local out = {}
for _, cls in ipairs({ 'BasePlayerChar_C', 'FunCombat_PlayerController_C' }) do
  local o = FindFirstOf(cls)
  if o and o:IsValid() then
    local c = o:GetClass()
    while c and c:IsValid() and c:GetFName():ToString() ~= 'Object' do
      c:ForEachProperty(function(pr)
        local n = pr:GetFName():ToString()
        if hit(n) then
          local ok, v = pcall(function() return o[n] end)
          if ok and (type(v) == 'boolean' or type(v) == 'number') then out[#out + 1] = cls .. '.' .. n .. '=' .. tostring(v) end
        end
      end)
      local ok, sup = pcall(function() return c:GetSuperStruct() end)
      c = ok and sup or nil
    end
  else
    out[#out + 1] = cls .. ' not found'
  end
end
return #out > 0 and table.concat(out, ' | ') or 'no matching property'
