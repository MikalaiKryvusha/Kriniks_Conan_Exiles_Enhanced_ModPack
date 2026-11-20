-- stand-keeper.lua — the in-game half of stand-keeper.sh (HOUSE_RULES rule 11): a UE4SS timer that runs quiet-stand.lua every _G.__sk_period_ms and prints
-- one `[stand-keeper]` line per pass to UE4SS.log. One timer per game session; a second start only updates radius / flag (the loop reads them each pass).
-- Stop: _G.__stand_keeper_on = false (the loop ends on its next pass).
-- [TESTED: 2026-11-07 · started 16:49:21, first pass 16:49:41 in UE4SS.log «killed 36 within 600 m … left alive 0» (two camp bosses among them), `last` read it back]
_G.__stand_keeper_on = true
if _G.__stand_keeper_loop then
    return 'stand-keeper already running: ' .. tostring(_G.__qs_radius) .. ' m'
end
_G.__stand_keeper_loop = true
LoopAsync(_G.__sk_period_ms or 20000, function()
    if not _G.__stand_keeper_on then
        _G.__stand_keeper_loop = nil
        print('[stand-keeper] stopped\n')
        return true
    end
    ExecuteInGameThread(function()
        local ok, r = pcall(dofile, 'D:/work/ai_sandbox/ConanExiles/_config/quiet-stand.lua')
        _G.__stand_keeper_last = os.date('%H:%M:%S') .. ' ' .. tostring(r)
        print('[stand-keeper] ' .. _G.__stand_keeper_last .. '\n')
    end)
    return false
end)
return 'stand-keeper on: ' .. tostring(_G.__qs_radius) .. ' m every ' .. tostring((_G.__sk_period_ms or 20000) / 1000) .. ' s'
