-- equip-hook-probe.lua — KUMM plan 52 step 3 recon (remote, read-only counters): which hero / combat UFunctions fire when the bow is taken up or put away.
--   pult.sh "lua return dofile('…/equip-hook-probe.lua')"                 -- first call: registers post-hooks once; every call returns the counters
--   pult.sh "lua _G.__ehp_reset = true; return dofile('…/equip-hook-probe.lua')"  -- zero the counters
-- A hook that fails to register is reported, never fatal. Counters live in _G.__ehp for the life of the game process. [NOT-TESTED]
local FNS = {
    '/Game/Characters/BasePlayerChar.BasePlayerChar_C:ToggleWieldWeapon',
    '/Game/Characters/BasePlayerChar.BasePlayerChar_C:OnWeaponEquip',
    '/Game/Characters/BasePlayerChar.BasePlayerChar_C:OnWeaponUnequip',
    '/Game/Characters/BasePlayerChar.BasePlayerChar_C:Unwield If During Combat',
    '/Game/Characters/BaseBPCombat.BaseBPCombat_C:ItemEquipEnd',
    '/Game/Characters/BaseBPCombat.BaseBPCombat_C:ItemEquipDo',
    '/Game/Characters/BaseBPCombat.BaseBPCombat_C:Handle Auto Wield Sheathe',
    '/Game/Characters/BaseBPCombat.BaseBPCombat_C:WeaponEquipped',
    '/Game/Characters/BaseBPCombat.BaseBPCombat_C:WeaponUnequipped',
    '/Game/Characters/BaseBPCombat.BaseBPCombat_C:MulticastItemEquip',
}
_G.__ehp = _G.__ehp or { n = {}, err = {}, last = '' }
local S = _G.__ehp
if _G.__ehp_reset then S.n = {}; S.last = ''; _G.__ehp_reset = nil end
if S.registered ~= 2 then
    S.registered = 2; S.err = {}
    for _, path in ipairs(FNS) do
        local short = path:match(':(.+)$')
        local ok, e = pcall(RegisterHook, path, function()
            S.n[short] = (S.n[short] or 0) + 1
            S.last = short .. ' @' .. string.format('%.2f', os.clock())
        end)
        if not ok then S.err[#S.err + 1] = short .. ': ' .. tostring(e):sub(1, 80) end
    end
end
local out = {}
for _, path in ipairs(FNS) do local short = path:match(':(.+)$'); out[#out + 1] = short .. ' ' .. (S.n[short] or 0) end
return table.concat(out, ' · ') .. (#S.err > 0 and ('\nnot hooked: ' .. table.concat(S.err, ' | ')) or '') .. '\nlast: ' .. S.last
