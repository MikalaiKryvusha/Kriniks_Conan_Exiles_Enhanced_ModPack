-- quickloot-trace.lua — the order and timing of the quick-loot panel's native slots around an F take (KUMM bug 75: the selection rim jumps).
-- Registers post-hooks once (kept in _G.__qlt) on QuickLootPanel: SlotTakeOne, SlotItemAddedOrRemoved, SlotItemSelectionChanged, SlotCycleSelectionNext/Prev,
-- SlotNavigateUp/Down; each call is logged «[QLT] <ms since the first> <slot>» into UE4SS.log. Read-only: no call, no write.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/quickloot-trace.lua')"   then a real F; then grep '\[QLT\]' UE4SS.log
-- [NOT-TESTED]
if _G.__qlt then _G.__qlt.t0 = nil; return "already hooked; the clock reset" end
_G.__qlt = { t0 = nil }
local names = { "SlotTakeOne", "SlotItemAddedOrRemoved", "SlotItemSelectionChanged", "SlotCycleSelectionNext", "SlotCycleSelectionPrev",
    "SlotNavigateUp", "SlotNavigateDown" }
local ok_n = 0
for _, n in ipairs(names) do
    local ok = pcall(function()
        RegisterHook("/Script/ConanSandbox.QuickLootPanel:" .. n, function()
            local now = os.clock()
            if not _G.__qlt.t0 then _G.__qlt.t0 = now end
            print(string.format("[QLT] %7.1f ms %s\n", (now - _G.__qlt.t0) * 1000.0, n))
        end)
    end)
    if ok then ok_n = ok_n + 1 end
end
return string.format("hooked %d of %d", ok_n, #names)
