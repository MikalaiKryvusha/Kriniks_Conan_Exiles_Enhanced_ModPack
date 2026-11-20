-- sprint-probe.lua — read what the game says about sprinting right now (KUMM Locomotion notes, «Sprint + bow»).
-- Why (2026-11-08): the bytecode of BaseBPCombat::EvaluateMovement_Sprint = TrySprint AND K2_CanSprint AND NOT InSubstate(18) has no attack
-- test; the refusal while drawing a bow is suspected in the NATIVE K2_CanSprint. This probe calls it and prints the hero's substates, so a
-- run with the bow drawn and one without tell whether K2_CanSprint flips.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/sprint-probe.lua')"
-- One unproven read per call (EXP-0488): the substate list is read with pcall and printed as a string.
-- [NOT-TESTED]
local p = FindFirstOf('FunCombat_PlayerController_C').Pawn
local out = {}
local ok_can, err_can = pcall(function() p:K2_CanSprint(out) end)
local parts = {}
parts[#parts + 1] = 'K2_CanSprint=' .. (ok_can and tostring(out.Value) or ('ERR ' .. tostring(err_can)))
parts[#parts + 1] = 'bTrySprint=' .. tostring(p.bTrySprint)
local mv = p.CharacterMovement
if mv and mv:IsValid() then parts[#parts + 1] = string.format('MaxWalkSpeed=%.1f', mv.MaxWalkSpeed) end
local subs = {}
for s = 0, 40 do
    local o = {}
    local ok = pcall(function() p:InSubstate(s, o) end)
    if ok and o.Success then subs[#subs + 1] = tostring(s) end
end
parts[#parts + 1] = 'substates=' .. table.concat(subs, ',')
return table.concat(parts, ' | ')
