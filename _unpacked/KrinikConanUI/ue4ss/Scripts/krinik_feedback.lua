--[[
  KrinikConanUI:Feedback — табличка «ОТЗЫВ» под нашим логотипом в главном меню и в меню паузы: щелчок собирает журналы игры и отчёты о
  падениях в zip на рабочий стол, показывает его в Проводнике и открывает письмо автору (KUMM план 36 W37).

  Слово владельца 2026-10-31 00:37–01:04: «кнопку к нашему лого сможем добавить, типа Обратная связь … и собирала с компа игрока логи» ·
  «чтобы они легко могли мне на почтку отправлять логи и крешлитику» · «высота 40 принята» · «и на меню паузы ESC тоже нужна будет кнопка отзыва».

  Табличка — кнопка Btn_KrinikFeedback в ките (kit-conanui-edit.py, W37): вид при наведении и нажатии рисует сама кнопка (стиль из двух текстур).
  Щелчок — событие самой кнопки: kit-krinik-click-events.py связал в блюпринте меню её OnClicked с нашим событием KrinikFeedbackClicked, а раздел
  перехватывает это событие (RegisterHook) в игровом потоке, только на настоящий щелчок по табличке. До 2026-11-18 щелчок ловила привязка к левой
  кнопке мыши (RegisterKeyBind): её Lua шёл в потоке цикла событий UE4SS одновременно с Lua этого мода в игровом потоке, а это класс падения бага 85
  (KUMM bugs/85; ЛКМ — каждый удар в бою). Перехват ставится при первом рождении меню своего класса: класс меню грузится вместе с меню.

  Сборщик — feedback/collect_report.ps1 этого мода (копия _config/player-report/collect_report.ps1), запуск через start: игра не ждёт его.
  [NOT-TESTED]
]]

local MOD = "KrinikConanUI:Feedback"
local MENU_CLASSES = {
    "/Game/UI/Widgets/MainMenu/W_MainMenu_MainMenu.W_MainMenu_MainMenu_C",
    "/Game/UI/HUD/W_IngameMenu.W_IngameMenu_C",
}
local EVENT = "KrinikFeedbackClicked"   -- the menu blueprint's custom event bound to Btn_KrinikFeedback.OnClicked (kit-krinik-click-events.py)
local DEBOUNCE_S = 5                 -- второй щелчок раньше — не второй архив
local PIPE_CLOSE_MS = 3000           -- труба io.popen закрывается, когда cmd давно вышел

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end

-- Папка мода и папка игры — от пути этого файла: …\ConanSandbox\Binaries\Win64\ue4ss\Mods\KrinikConanUI\Scripts\krinik_feedback.lua
local SRC = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/", "\\")
local MOD_DIR = SRC:match("^(.*)\\Scripts\\[^\\]+$") or ""
local GAME_DIR = MOD_DIR:match("^(.*)\\ConanSandbox\\Binaries\\") or ""
local COLLECTOR = MOD_DIR .. "\\feedback\\collect_report.ps1"

local last_click = -DEBOUNCE_S
local hooked = {}                    -- путь класса меню → перехват его KrinikFeedbackClicked поставлен (один раз на класс)

local function on_click(cls)
    local t0 = os.clock()
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
    local dt = (os.clock() - t0) * 1000.0
    if dt > 1.0 then log("slow click: %.3f ms", dt) end
end

for _, path in ipairs(MENU_CLASSES) do
    NotifyOnNewObject(path, function(m)
        if hooked[path] or m:GetFullName():find("Default__", 1, true) then return end   -- шаблон класса — не меню на экране
        hooked[path] = true
        ExecuteInGameThread(function()
            local cls = path:match("%.([^.]+)$")
            local ok, e = pcall(RegisterHook, path .. ":" .. EVENT, function()
                -- перехват идёт в игровом потоке внутри разбора щелчка Slate; сборщик запускается на следующем заходе игрового потока
                ExecuteInGameThread(function()
                    local ok2, e2 = pcall(on_click, cls)
                    if not ok2 then log("click failed: %s", tostring(e2)) end
                end)
            end)
            log("menu %s: hook %s %s", cls, EVENT, ok and "set" or ("NOT set: " .. tostring(e)))
        end)
    end)
end

log("ready: mod %s, game %s", MOD_DIR, GAME_DIR)
