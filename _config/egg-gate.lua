-- egg-gate.lua — KUMM bug 82: the two gates krinik_pickup_prompt.lua checks BEFORE its probe, read in the same second at the egg stand (after egg-stand.lua):
-- the ContainerInfo module and any FloatingNames strip «on screen» (Transient, IsInViewport, IsVisible). Read-only. [NOT-TESTED]
local out = {}
local gui = FindFirstOf('GUIModuleController')
out[#out + 1] = 'ContainerInfo active: ' .. tostring(gui and gui:IsValid() and gui:IsModuleActive(FName('ContainerInfo')))
for _, n in ipairs({ 'W_DialogueNPCInfo', 'W_PlaceableInfo', 'W_SimpleInfo', 'W_ThrallInfo', 'W_DBNORevive' }) do
  for _, w in ipairs(FindAllOf(n .. '_C') or {}) do
    local f = w:GetFullName()
    if not f:find('Default__', 1, true) and f:find('Transient', 1, true) then
      local ok, s = pcall(function() return ('%s viewport=%s visible=%s'):format(n, tostring(w:IsInViewport()), tostring(w:IsVisible())) end)
      out[#out + 1] = ok and s or (n .. ' ?')
    end
  end
end
return table.concat(out, '\n')
