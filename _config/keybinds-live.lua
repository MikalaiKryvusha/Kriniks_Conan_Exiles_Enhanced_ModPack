-- keybinds-live.lua — the key bindings the RUNNING game LOADED (KUMM plan 53 step 14, cases K0 / K0c of TC_conan_owner_keybinds_310_2026-11-14.md).
-- Why (2026-11-14): the owner's Input.ini went into the 3.1.0 game as a file; this reads what the game made of it — the merged config, the InputSettings
-- default object's ActionMappings — for the six actions the owner edited plus Jump (an unedited control). What it does NOT prove: that a key acts. The
-- merged config can say «Key=None» while something else still reacts to the key (EXP-0098: in 2.1.1 the chat still opened) — a binding is proven only by the
-- real key on video (cases K1–K7, the defaults control K2c). (The judge of 2026-11-14 caught the first header overclaiming «the bindings the game uses».)
--   bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/keybinds-live.lua')"
-- Read-only: changes nothing. Prints «Action=key,key | …» (a long press marked «(long)») and the row count.
-- [TESTED: 2026-11-14 · the 3.1.0 game: with the owner's Input.ini — his six keys (K0); with the file moved away — the defaults C / LeftAlt / Enter /
--  Subtract / Multiply (K0c) — KUMM testcases/reports/2026-11-14_conan-owner-keybinds-310.md; the «(long)» mark added after, not run]
local want = { 'CrouchMode', 'DodgeActionV2', 'SecondaryActionV2', 'GlobalChat', 'GuildChat', 'VicinityChat', 'Jump' }
local wanted = {}
for _, n in ipairs(want) do wanted[n:lower()] = n end

local s = StaticFindObject('/Script/Engine.Default__InputSettings')
if not (s and s:IsValid()) then return 'no Default__InputSettings' end
local keys, rows = {}, 0
s.ActionMappings:ForEach(function(_, e)
    local m = e:get()
    rows = rows + 1
    local n = wanted[m.ActionName:ToString():lower()]   -- FName: the case of a name is not part of it
    if n then
        local mods = {}                                  -- Shift+Ctrl+Alt+Cmd+Key, in that order
        for _, f in ipairs({ { 'bShift', 'Shift' }, { 'bCtrl', 'Ctrl' }, { 'bAlt', 'Alt' }, { 'bCmd', 'Cmd' } }) do if m[f[1]] then mods[#mods + 1] = f[2] end end
        mods[#mods + 1] = m.Key.KeyName:ToString()
        local k = table.concat(mods, '+')
        if m.bLongPress then k = k .. '(long)' end
        keys[n] = (keys[n] and (keys[n] .. ',') or '') .. k
    end
end)
local parts = { 'rows=' .. rows }
for _, n in ipairs(want) do parts[#parts + 1] = n .. '=' .. (keys[n] or '-') end
return table.concat(parts, ' | ')
