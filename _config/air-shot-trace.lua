-- air-shot-trace.lua — samples the hero for a real bow shot in a jump (KUMM Locomotion case M6): every 30 ms for 4.5 s — height, falling flag,
-- and the number of live ProjectileMovementComponents (a released arrow adds one). Start it, do the real input, then read _G.__ast.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/air-shot-trace.lua')"          -- start
--   bash pult.sh "lua return table.concat(_G.__ast or {}, ' ')"                                              -- read: t:z:falling:projectiles
-- [NOT-TESTED]
_G.__ast = {}
local hero = FindFirstOf('BasePlayerChar_C')
local t0 = os.clock()
local n = 0
LoopAsync(30, function()
    n = n + 1
    local ok, s = pcall(function()
        local z = hero:K2_GetActorLocation().Z
        local f = hero.CharacterMovement:IsFalling()
        local p = 0
        for _, c in ipairs(FindAllOf('ProjectileMovementComponent') or {}) do
            if c:IsValid() and not c:GetFullName():find('Default__', 1, true) then p = p + 1 end
        end
        return string.format('%d:%.0f:%s:%d', math.floor((os.clock() - t0) * 1000), z, f and 'F' or 'g', p)
    end)
    _G.__ast[#_G.__ast + 1] = ok and s or 'err'
    return n >= 150
end)
return 'air-shot trace started'
