-- KrinikMenuProbe — одноразовый зонд главного меню (KUMM plans/33, 2026-10-25).
-- [NOT-TESTED]
-- Заказ владельца 2026-10-25: «вот это убрать» — пустая рамка с орнаментом справа
-- в главном меню 3.0.1. Угадывать класс нельзя (docs/06), поэтому зонд ТОЛЬКО ЧИТАЕТ:
-- через 25 с после старта выписывает каждый живой UserWidget — класс, полный путь
-- (по нему видно, внутри какого окна он живёт) и видимость. Ничего не создаёт и ничего
-- не меняет. Отчёт — menu-report.txt рядом с папкой Scripts. После чтения — удалить мод.

local REPORT = "ue4ss/Mods/KrinikMenuProbe/menu-report.txt"
local DELAY_MS = 25000

local VIS = { [0] = "Visible", [1] = "Collapsed", [2] = "Hidden",
              [3] = "HitTestInvisible", [4] = "SelfHitTestInvisible" }

local function dump()
    local lines = {}
    local widgets = nil
    local ok, err = pcall(function() widgets = FindAllOf("UserWidget") end)
    if not ok or not widgets then
        lines[#lines + 1] = "FindAllOf(UserWidget) failed: " .. tostring(err)
    else
        lines[#lines + 1] = ("live UserWidgets: %d"):format(#widgets)
        for _, w in ipairs(widgets) do
            local full, vis, inview = "?", "?", "?"
            pcall(function() full = w:GetFullName() end)
            pcall(function() vis = VIS[w:GetVisibility()] or tostring(w:GetVisibility()) end)
            pcall(function() inview = tostring(w:IsInViewport()) end)
            lines[#lines + 1] = ("%-18s viewport=%-5s %s"):format(vis, inview, full)
        end
    end
    local f = io.open(REPORT, "w")
    if f then
        f:write(table.concat(lines, "\n"), "\n")
        f:close()
        print(("[KrinikMenuProbe] отчёт записан: %d строк\n"):format(#lines))
    else
        print("[KrinikMenuProbe] не смог открыть " .. REPORT .. "\n")
    end
end

-- ОПЫТ 2 (2026-10-25 09:30) — сворачивание окна очереди уведомлений WBP_QueuedNotificationWindow_C — УБРАН 2026-10-31: гипотеза
-- опровергнута в тот же день (рамка осталась, план 33 п. 11), а сворачивание шесть дней срабатывало при каждом запуске игры
-- владельца. Зонд снова только читает.
-- Задержка — в игровом потоке: ExecuteWithDelay зовёт из рабочего потока UE4SS, это класс падений (check-lua-game-thread.py).
ExecuteInGameThreadWithDelay(DELAY_MS, function()
    dump()
end)
print("[KrinikMenuProbe] загружен, отчёт через 25 с\n")
