-- KrinikAgentRemote — пульт агента для Конана (KUMM plans/33, 2026-10-25).
-- [NOT-TESTED]
-- Слово владельца 2026-10-25: «снимай в бекграунде скриншоты и там взаимодействуй» · «чтобы я мог
-- в браузере работать, а ты с игрой». Захват экрана (capture.ps1) снимает то, что впереди, а
-- щелчок input.ps1 поднимает игру поверх окон владельца. Пульт делает то же изнутри игры:
-- агент пишет строку в cmd.txt, мод раз в 500 мс её забирает и исполняет на игровом потоке.
--
-- Команды (одна строка — одна команда):
--   shot                 кадр игры штатной командой движка HighResShot 1 → Saved/Screenshots
--   exec <команда>       любая консольная команда движка
--   collapse <Класс>     свернуть живые виджеты класса (только экземпляры из /Engine/Transient)
--   dump <подстрока>     все живые элементы интерфейса с подстрокой в пути → dump.txt
--   hide <конец пути>    свернуть элемент с точным окончанием пути
--   funcs <конец пути>   методы класса элемента и его предков (до UserWidget) → dump.txt
--   props <Класс>        простые свойства (числа, флаги, строки) живого объекта класса → dump.txt; читать
--                        свойства ТОЛЬКО так: перебор всех свойств через `lua` уронил игру 2026-10-25 20:25
--   lua <код>            исполнить кусок Lua на игровом потоке; что вернёт — строкой в result.txt
--                        (2026-10-25: зародыш KrinikConanHarness — пробы HUD без перезапуска игры)
--   call <конец пути> <Метод>   вызвать метод без аргументов (кнопка меню — её обработчик нажатия;
--                        2026-10-25: войти в мир из меню, когда ни ключ -continuesession, ни `open` не сработали)
-- Ответ — строка в done.txt: «<номер> ok|fail <команда>», чтобы агент знал, что исполнено.

local DIR = "ue4ss/Mods/KrinikAgentRemote/"
local CMD = DIR .. "cmd.txt"
local DONE = DIR .. "done.txt"
local POLL_MS = 500
local seq = 0

local function log(s) print("[KrinikAgentRemote] " .. s .. "\n") end

local function answer(ok, cmd)
    seq = seq + 1
    local f = io.open(DONE, "a")
    if f then
        f:write(("%d %s %s\n"):format(seq, ok and "ok" or "fail", cmd))
        f:close()
    end
end

local function console(line)
    local pc = FindFirstOf("PlayerController")
    local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    if not pc or not pc:IsValid() or not ksl or not ksl:IsValid() then return false end
    ksl:ExecuteConsoleCommand(pc, line, pc)
    return true
end

local function collapse(class)
    local n = 0
    for _, w in ipairs(FindAllOf(class) or {}) do
        local full = ""
        pcall(function() full = w:GetFullName() end)
        if full:find("Transient", 1, true) then
            w:SetVisibility(1)
            n = n + 1
        end
    end
    log(("свёрнуто %s: %d"):format(class, n))
    return n > 0
end

-- Все живые элементы интерфейса (UWidget, не только UserWidget), чей путь содержит подстроку:
-- класс, видимость, путь. Нужен, когда искомое - картинка или рамка внутри окна, а не окно.
local VIS = { [0] = "Visible", [1] = "Collapsed", [2] = "Hidden",
              [3] = "HitTestInvisible", [4] = "SelfHitTestInvisible" }
local function dump(sub)
    local lines = {}
    for _, w in ipairs(FindAllOf("Widget") or {}) do
        local full = ""
        pcall(function() full = w:GetFullName() end)
        if full:find(sub, 1, true) then
            local vis = "?"
            pcall(function() vis = VIS[w:GetVisibility()] or tostring(w:GetVisibility()) end)
            lines[#lines + 1] = ("%-20s %s"):format(vis, full)
        end
    end
    local f = io.open(DIR .. "dump.txt", "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
    log(("dump %s: %d"):format(sub, #lines))
    return true
end

-- Свернуть ОДИН элемент по точному окончанию пути (напр. "WidgetTree_2147482043.SomeImage").
-- Для деления пополам: свернул - снял кадр - посмотрел.
local function hide_path(tail)
    local n = 0
    for _, w in ipairs(FindAllOf("Widget") or {}) do
        local full = ""
        pcall(function() full = w:GetFullName() end)
        if full:sub(-#tail) == tail then
            w:SetVisibility(1)
            n = n + 1
        end
    end
    log(("hide %s: %d"):format(tail, n))
    return n > 0
end

local function find_widget(tail)
    for _, w in ipairs(FindAllOf("Widget") or {}) do
        local full = ""
        pcall(function() full = w:GetFullName() end)
        if full:sub(-#tail) == tail then return w end
    end
    return nil
end

-- Прямой вызов метода вместо щелчка мышью: щелчок поднял бы игру поверх окна владельца.
local function funcs(tail)
    local o = find_widget(tail)
    if not o then return false end
    local lines = {}
    local cls = o:GetClass()
    while cls and cls:IsValid() do
        local cname = cls:GetFName():ToString()
        cls:ForEachFunction(function(f) lines[#lines + 1] = cname .. "::" .. f:GetFName():ToString() end)
        if cname == "UserWidget" then break end
        cls = cls:GetSuperStruct()
    end
    local f = io.open(DIR .. "dump.txt", "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
    log(("funcs %s: %d"):format(tail, #lines))
    return true
end

-- call <конец пути> <Метод> [конец пути элемента-параметра]: обработчик кнопки меню ждёт саму кнопку
-- («UFunction expected 1 parameters, received 0», 2026-10-25)
local function call(rest)
    local tail, fn, argtail = rest:match("^(%S+)%s+(%S+)%s*(%S*)$")
    if not tail then return false end
    local o = find_widget(tail)
    if not o then return false end
    if argtail ~= "" then
        local a = find_widget(argtail)
        if not a then return false end
        o[fn](o, a)
    else
        o[fn](o)
    end
    log(("call %s %s"):format(tail, fn))
    return true
end

-- props <Класс>: простые свойства первого живого объекта класса и его предков → dump.txt.
-- [NOT-TESTED]
-- Оплачено 2026-10-25 20:25: `lua` с ForEachProperty и чтением o[имя] у КАЖДОГО свойства объектов засад уронил игру
-- (EXCEPTION_ACCESS_VIOLATION reading 0x10 внутри UE4SS: свойство-делегат или слабый указатель с пустым значением; pcall
-- нативное падение не ловит). Здесь тип свойства проверяется ДО чтения: читаются только числа, флаги, строки и имена.
local SIMPLE = { FloatProperty = true, DoubleProperty = true, IntProperty = true, Int64Property = true, ByteProperty = true,
                 BoolProperty = true, StrProperty = true, NameProperty = true, UInt32Property = true, Int16Property = true }
local function props(class)
    local o = FindFirstOf(class)
    if not o or not o:IsValid() then return false end
    local lines = { o:GetFullName() }
    local cls = o:GetClass()
    while cls and cls:IsValid() do
        local cname = cls:GetFName():ToString()
        cls:ForEachProperty(function(p)
            local ptype = p:GetClass():GetFName():ToString()
            local nm = p:GetFName():ToString()
            if SIMPLE[ptype] then
                local ok, v = pcall(function() return o[nm] end)
                if ok and type(v) == "userdata" then pcall(function() v = v:ToString() end) end
                lines[#lines + 1] = ("%s::%s (%s) = %s"):format(cname, nm, ptype, ok and tostring(v) or "?")
            else
                lines[#lines + 1] = ("%s::%s (%s) — не читаю"):format(cname, nm, ptype)
            end
        end)
        if cname == "Actor" or cname == "ActorComponent" or cname == "Object" then break end
        cls = cls:GetSuperStruct()
    end
    local f = io.open(DIR .. "dump.txt", "w")
    if not f then return false end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
    log(("props %s: %d"):format(class, #lines - 1))
    return true
end

-- find <слово|слово…>: актёры мира с таким словом в имени → dump.txt (имя, позиция, курс). Только актёры и только IsValid:
-- поиск арок перебором 8 тысяч StaticMeshComponent и вызовом метода у пустой модели уронил игру 2026-10-25 21:14 (EXP-0330).
-- [NOT-TESTED]
local FIND_CAP = 400
local function find(words)
    local pats = {}
    for w in words:lower():gmatch("[^|]+") do pats[#pats + 1] = w end
    local lines, n = {}, 0
    for _, a in ipairs(FindAllOf("Actor") or {}) do
        if a:IsValid() then
            n = n + 1
            local name = a:GetFName():ToString()
            local low = name:lower()
            for _, p in ipairs(pats) do
                if low:find(p, 1, true) then
                    local l, r = a:K2_GetActorLocation(), a:K2_GetActorRotation()
                    lines[#lines + 1] = ("%s @ %.0f,%.0f,%.0f yaw=%.1f"):format(name, l.X, l.Y, l.Z, r.Yaw)
                    break
                end
            end
            if #lines >= FIND_CAP then break end
        end
    end
    local f = io.open(DIR .. "dump.txt", "w")
    if not f then return false end
    f:write(("актёров %d, найдено %d\n"):format(n, #lines), table.concat(lines, "\n"), "\n")
    f:close()
    log(("find %s: %d из %d"):format(words, #lines, n))
    return true
end

-- Кусок Lua от агента: окружение — глобальное (FindAllOf, StaticFindObject …) плюс find_widget и log.
-- @guard no-component-sweep
-- THREAT:         агентский перебор компонентов с вызовом метода у пустого объекта роняет игру нативно (pcall не ловит)
-- PROVED-AGAINST: команда 2026-10-26 09:23 `FindAllOf('WidgetComponent')` + `w:GetOwner():GetClass()` — падение 0x10 в UE4SS у владельца
--                 в игре (третий раз класса EXP-0330: 25.10 20:25, 21:14)
-- GAP:            перебор актёров с цепочкой вызовов без IsValid страж не видит; FindFirstOf по компоненту пропускает
-- ON-REAL-PATH:   NOT YET
local COMPONENT_SWEEP = "FindAllOf%s*%(%s*['\"][%w_]*Component[%w_]*['\"]"
-- @guard no-table-delegate
-- THREAT:         делегат, переданный в UFunction таблицей Lua ({ Object = …, FunctionName = … }), роняет UE4SS нативно через 1,5 с (pcall не ловит)
-- PROVED-AGAINST: KUMM bugs/118 — семь падений 2026-11-22 15:48–17:45 и два повтора 19:28, 19:31 (один с выключенным модом камеры): проба
--                 .work/tmp/esc_listen.lua, ListenForInputAction(FName("Escape"), 0, true, { Object = root, FunctionName = FName(…) }); EXP-0613
-- GAP:            видит вызов метода `:ListenForInputAction(` (любой: делегат из Lua другим способом, чем таблицей, сюда не подать — судья 2026-11-22,
--                 находка 2: таблица в переменной проходила старый шаблон) в команде и в файлах, которые команда грузит через dofile (формы `dofile('…')`,
--                 `dofile "…"`, `dofile[[…]]`); вызов через точку `obj.ListenForInputAction(obj, …)`, loadfile и dofile внутри загруженного файла не видит;
--                 строку-комментарий без двоеточия перед именем не трогает
-- ON-REAL-PATH:   YES 2026-11-22 19:53 (прежний шаблон) — G1 команда пробы отклонена, игра жива; G2 «lua return 1+1» → 2; G3 dofile open-tab.lua
--                 исполнен (KUMM bugs/118); нынешний шаблон — G4–G11 на Lua 5.4 (lupa) 2026-11-22 20:2x и в игре 20:25: проба по файлу отклонена,
--                 делегат в переменной отклонён в команде, «lua return 1+1» → 2, игра жива
local LISTEN_CALL = ":%s*ListenForInputAction%s*%("
-- @guard no-nil-interactable (2026-11-22 20:57, KUMM bugs/84 case M2): `npc:InteractableActivate(nil, hero, 0, false)` on a BP_HumanoidDialogueNPC_C crashed the
-- game natively (access violation 0x412fd716, stack 56 frames — crash-forensics.py named the command at once); the same call with nil passed on dungeon teleport
-- triggers. A nil Component is not what the game passes there. GAP: only the literal «InteractableActivate(nil» is seen. ON-REAL-PATH: YES — Lua 5.4 cases
-- G12 / G13, live at the main menu 2026-11-22 21:00 (the command refused, «lua return 1+1» → 2, the game alive).
local NIL_ACTIVATE = ":%s*InteractableActivate%s*%(%s*nil"
local function refuse_table_delegate(text, where)
    if text and text:find(LISTEN_CALL) then
        error("отказ: ListenForInputAction из Lua роняет UE4SS нативно (" .. where .. ") — KUMM bugs/118, EXP-0613")
    end
    if text and text:find(NIL_ACTIVATE) then
        error("отказ: InteractableActivate с пустым компонентом уронил игру на собеседнике (" .. where .. ") — KUMM bugs/84, M2")
    end
end
local DOFILE_FORMS = { "dofile%s*%(?%s*'([^']+)'", 'dofile%s*%(?%s*"([^"]+)"', "dofile%s*%(?%s*%[%[(.-)%]%]" }
local function lua_chunk(code)
    if code:find(COMPONENT_SWEEP) then
        error("отказ: перебор компонентов (FindAllOf по классу …Component) ронял игру трижды — EXP-0330; ищи через актёра и IsValid")
    end
    refuse_table_delegate(code, "в команде")
    -- файл, который команда грузит через dofile('…'), проверяется тем же правилом: проба bugs/118 жила в файле, а не в строке команды
    for _, form in ipairs(DOFILE_FORMS) do
        for path in code:gmatch(form) do
            local f = io.open(path, "r")
            if f then
                local body = f:read("*a") or ""
                f:close()
                refuse_table_delegate(body, path)
            end
        end
    end
    local env = setmetatable({ find_widget = find_widget, log = log }, { __index = _G })
    local fn, err = load(code, "agent", "t", env)
    if not fn then error(err) end
    local out = fn()
    local f = io.open(DIR .. "result.txt", "w")
    if f then
        f:write(tostring(out), "\n")
        f:close()
    end
    return true
end

local function run(cmd)
    local verb, rest = cmd:match("^(%S+)%s*(.*)$")
    local ok, res = false, nil
    if verb == "shot" then
        ok, res = pcall(console, "HighResShot 1")
    elseif verb == "exec" and rest ~= "" then
        ok, res = pcall(console, rest)
    elseif verb == "collapse" and rest ~= "" then
        ok, res = pcall(collapse, rest)
    elseif verb == "dump" and rest ~= "" then
        ok, res = pcall(dump, rest)
    elseif verb == "hide" and rest ~= "" then
        ok, res = pcall(hide_path, rest)
    elseif verb == "funcs" and rest ~= "" then
        ok, res = pcall(funcs, rest)
    elseif verb == "call" and rest ~= "" then
        ok, res = pcall(call, rest)
    elseif verb == "find" and rest ~= "" then
        ok, res = pcall(find, rest)
    elseif verb == "props" and rest ~= "" then
        ok, res = pcall(props, rest)
    elseif verb == "lua" and rest ~= "" then
        ok, res = pcall(lua_chunk, rest)
    else
        log("не понял команду: " .. cmd)
    end
    -- Текст ошибки — в журнал: 2026-10-25 три вызова `call` пришли «fail» без причины, хотя первый сработал
    if not ok then log("ошибка: " .. tostring(res)) end
    ok = ok and res == true
    log((ok and "исполнено: " or "НЕ исполнено: ") .. cmd)
    answer(ok, cmd)
end

LoopInGameThreadWithDelay(POLL_MS, function() pcall(function()   -- ошибка тела не останавливает цикл игрового потока
    local f = io.open(CMD, "r")
    if not f then return false end
    local text = f:read("*a") or ""
    f:close()
    os.remove(CMD)
    for line in text:gmatch("[^\r\n]+") do
        local cmd = line:match("^%s*(.-)%s*$")
        if cmd ~= "" then ExecuteInGameThread(function() run(cmd) end) end
    end
    return false
end) end)
log("загружен, жду команд в " .. CMD)
