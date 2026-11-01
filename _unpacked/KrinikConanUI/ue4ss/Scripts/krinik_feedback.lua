--[[
  KrinikConanUI:Feedback — табличка «ОТЗЫВ» под нашим логотипом в главном меню и в меню паузы: щелчок собирает журналы игры и отчёты о
  падениях в zip на рабочий стол, показывает его в Проводнике и открывает письмо автору (KUMM план 36 W37).

  Слово владельца 2026-10-31 00:37–01:04: «кнопку к нашему лого сможем добавить, типа Обратная связь … и собирала с компа игрока логи» ·
  «чтобы они легко могли мне на почтку отправлять логи и крешлитику» · «высота 40 принята» · «и на меню паузы ESC тоже нужна будет кнопка отзыва».

  Табличка — кнопка Btn_KrinikFeedback в ките (kit-conanui-edit.py, W37): вид при наведении и нажатии рисует сама кнопка (стиль из двух текстур).
  Щелчок — привязка к левой кнопке мыши (RegisterKeyBind): на нажатие, в игровом потоке, раздел ищет живое меню и спрашивает IsHovered у кнопки.
  Почему не события виджета: хуки на UserWidget:OnMouseButtonDown / OnMouseMove не вызывались ни разу (прогон 2026-10-31 01:16, курсор над
  табличкой, IsHovered = true по пульту); привязка к ЛКМ проверена пультом 01:17 — над табличкой true, мимо false.
  ЛКМ — это и удар в бою, поэтому на щелчке нет поиска по сцене: меню запоминаются по событию создания (NotifyOnNewObject, шаблоны Default__
  отброшены), щелчок спрашивает только их — IsVisible и IsHovered, несколько вызовов (правило дома 7).

  Сборщик — feedback/collect_report.ps1 этого мода (копия _config/player-report/collect_report.ps1), запуск через start: игра не ждёт его.
  [NOT-TESTED]
]]

local MOD = "KrinikConanUI:Feedback"
local MENU_CLASSES = {
    "/Game/UI/Widgets/MainMenu/W_MainMenu_MainMenu.W_MainMenu_MainMenu_C",
    "/Game/UI/HUD/W_IngameMenu.W_IngameMenu_C",
}
local BTN = "Btn_KrinikFeedback"
local DEBOUNCE_S = 5                 -- второй щелчок раньше — не второй архив
local PIPE_CLOSE_MS = 3000           -- труба io.popen закрывается, когда cmd давно вышел

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end

-- Папка мода и папка игры — от пути этого файла: …\ConanSandbox\Binaries\Win64\ue4ss\Mods\KrinikConanUI\Scripts\krinik_feedback.lua
local SRC = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/", "\\")
local MOD_DIR = SRC:match("^(.*)\\Scripts\\[^\\]+$") or ""
local GAME_DIR = MOD_DIR:match("^(.*)\\ConanSandbox\\Binaries\\") or ""
local COLLECTOR = MOD_DIR .. "\\feedback\\collect_report.ps1"

local last_click = -DEBOUNCE_S
local menus = {}                     -- живые меню, запомненные при создании: { menu, button }

local function valid(o) return o ~= nil and o:IsValid() end

for _, path in ipairs(MENU_CLASSES) do
    NotifyOnNewObject(path, function(m)
        if m:GetFullName():find("Default__", 1, true) then return end   -- шаблон класса, не меню на экране
        -- дерево виджета достраивается не в кадр создания; задержка — в игровом потоке (ExecuteWithDelay — класс падений UE4SS,
        -- check-lua-game-thread.py поймал его здесь 2026-10-31)
        ExecuteInGameThreadWithDelay(500, function()
            if not valid(m) then return end
            local ok, b = pcall(function() return m:GetWidgetFromName(FName(BTN)) end)
            if ok and valid(b) then
                for i = #menus, 1, -1 do if not valid(menus[i].menu) then table.remove(menus, i) end end
                table.insert(menus, { menu = m, button = b })
                log("menu %s remembered (%d live)", m:GetClass():GetFName():ToString(), #menus)
            end
        end)
    end)
end

-- Кнопка под курсором в одном из запомненных живых меню — или nil.
local function hovered_button()
    for _, e in ipairs(menus) do
        if valid(e.menu) and valid(e.button) and e.menu:IsVisible() and e.button:IsHovered() then
            return e.button, e.menu:GetClass():GetFName():ToString()
        end
    end
end

local function on_click()
    local t0 = os.clock()
    local b, cls = hovered_button()
    if b then
        if os.time() - last_click < DEBOUNCE_S then
            log("click ignored (debounce)")
        else
            last_click = os.time()
            local cmd = ('start "" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%s" -GameDir "%s" -Feedback'):format(COLLECTOR, GAME_DIR)
            log("click in %s -> %s", cls, cmd)
            -- os.execute ждал cmd.exe и держал игровой поток 63 мс (прогон 2026-10-31 01:32); io.popen возвращается сразу, а трубу
            -- закрываем позже — к тому времени cmd уже отдал запуск start и вышел, close не ждёт
            local ok, p = pcall(io.popen, cmd)
            if ok and p then
                ExecuteInGameThreadWithDelay(PIPE_CLOSE_MS, function() pcall(function() p:close() end) end)
            else
                log("collector start failed: %s", tostring(p))
            end
        end
    end
    local dt = (os.clock() - t0) * 1000.0
    if dt > 1.0 then log("slow click check: %.3f ms", dt) end
end

RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function() ExecuteInGameThread(on_click) end)

log("ready: mod %s, game %s", MOD_DIR, GAME_DIR)
