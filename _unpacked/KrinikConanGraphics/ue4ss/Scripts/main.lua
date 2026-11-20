--[==[===========================================================================
  KrinikConanGraphics 0.9.1 — графика сборки одним модом.
  `[OWNER]` «Может всё по графике Krinik сведём в один мод KrinikConanGraphics? а не размазывать "KrinikLingeringBlood"» ·
  «у нас и Engine.ini поставляется» · «оптимизированный» · «и по солнцу» · 2026-10-30 ≈12:5x.
  Состав: Lua-часть (этот файл) — разделы ниже; оптимизированный Engine.ini (дальности, тени, туман, DLSS, шаг солнца) —
  файл Engine.ini рядом, его раскатывает Deploy-ModPack.ps1 по полю engineIni манифеста.

  РАЗДЕЛ 1. Кровь на земле лежит до 5 минут, а не 3 секунды (до 2026-10-30 ≈12:50 — мод KrinikLingeringBlood).
  KUMM план 36 W28. `[OWNER]` «спрайты крови на земле которые - нужно чтобы держались на земле до 5 минут до
  исчезночения» · «чтобы земля, залитая кровью - долго была в крови» · «время настраивается ползунком в модах Krinik»
  · 2026-10-30 ≈10:59. Ползунок появится в окне «Моды Krinik» (W24); до него время — CFG.hold_s.
  Выключить — убрать enabled.txt.
  ============================================================================

  КАК УСТРОЕНО В ИГРЕ (байткод 3.0.1, BP_CollisionComponent.DoHandleHitFeedback, разбор kismet-trace 2026-10-30):
  на каждом ударе оружием по телу игра кладёт под цель пятно —
     SpawnDecalAtLocation(M_blood_ground_decal, …, LifeSpan 3.0)  →  SetFadeOut(0.0, 3.0, true).
  Жизнь компонента = задержка + длительность угасания, по её концу пятно уничтожается — родная кровь живёт 3 с
  (замер хуком: life=3.0, 40+ ударов каппы и Ночных ужасов, 2026-10-30 12:13–12:22).
  Материал пятна рисует его по DecalLifetimeOpacity (прозрачность × появление): полное пятно — только пока это число
  примерно от 0,45 до 0,9; при 1 (до начала угасания) — бледная тень, ниже 0,45 — ничего. Родное угасание за 3 с
  проводит число через это окно — пятно мелькает. Замеры кадрами пультом 2026-10-30: угасание (0, 30) — пятно видно
  с 4,5 по 16,5 с; (27, 3) — до 27 с бледная тень; появление с отрицательной задержкой держит число в окне.

  ЧТО ДЕЛАЕТ: сразу после родного SetFadeOut у пятна крови —
     SetFadeOut(hold_s − fade_s, fade_s)    — жизнь hold_s, исчезает за последние fade_s секунд;
     SetFadeIn(−start × ramp, ramp)         — число стартует с start и растёт на hold_s / ramp за жизнь.
  start 0,5 и рост 0,3 за жизнь держат число в окне (0,5 → 0,8): пятно полное всё время и медленно темнеет, как
  высыхающая кровь. Кадры 12:36 (жизнь 40 с, рост 0,175): старты 0,5 · 0,6 · 0,7 — полное пятно до 35 с, на 40 с
  нет; старт 0,8 к 30 с бледнеет (число дошло до 0,95).
  Чего нельзя (проверено): SetLifeSpan у компонента — не функция для Lua (закрытый метод движка; «attempt to call
  a TrivialObject»); LifeSpan в пред-хуке SpawnDecalAtLocation — UE4SS не передаёт изменённое значение в вызов.

  ЦЕНА: ни опроса, ни поиска по сцене — одно событие на пятно (родной SetFadeOut), внутри одно имя материала и
  два вызова. Сверх hold_cap пятен разом самое старое тает за полсекунды, новое живёт полный срок (видеокарта:
  сотни декалей в долгой схватке).
  Свой замер — сводка раз в минуту, если пятна были; каждое продлённое пятно — строка журнала (debug_log).

  [TESTED: 2026-10-30 · игра 3.0.1, удары крокодила по герою: пятно на кадрах сверху через 10 с, 1, 2, 3 мин и 4 мин 45 с, нет через
   5 мин 5 с; журнал — строка на каждое пятно · KUMM testcases/reports/2026-10-30_conan-lingering-blood.md]. Цена не измерена точнее:
   os.clock под Windows шагает по 1 мс (сводка «4 пятна, 1 мс» — это не граница (поправка 13:08: вызов в 0,9 мс может записаться как 0) — цена не измерена, замер — кейс G4).
  [NOT-TESTED] — потолок со сменой старых на новые (evict_oldest) и имя мода KrinikConanGraphics.
===========================================================================]==]

-- ------------------------------------------------------------------ настройки
local CFG = {
    hold_s    = 300.0,  -- «до 5 минут» — слово владельца; шкала — окно «Моды Krinik» (W24)
    hold_cap  = 200,    -- [AI] пятен с продлением разом; цену сотни декалей мерить (бюджет 1 мс процессора, видеокарта)
    fade_s    = 3.0,    -- исчезает за столько же, сколько родная кровь угасает
    evict_fade_s = 0.5, -- [AI] старое пятно сверх потолка тает за полсекунды, не пропадает щелчком
    start     = 0.5,    -- число материала в начале жизни: окно полного пятна ≈0,45–0,9 (кадры 12:36)
    rise      = 0.3,    -- рост числа за всю жизнь: 0,5 → 0,8, внутри окна
    summary_s = 60.0,
    debug_log = true,   -- строка на каждое пятно: журнал — глаза агента (слово владельца о подробных журналах модов)
}

local TAG = "[KrinikConanGraphics] "
local BLOOD_MATERIAL = "M_blood_ground_decal"
local HOOK = "/Script/Engine.DecalComponent:SetFadeOut"

local function log(fmt, ...) print(TAG .. fmt:format(...) .. "\n") end

-- Шкала «Сколько лежит кровь на земле» окна «Моды Krinik'а» (KUMM план 38 этап 2, решение FORK шага 3): общее хранилище
-- <игра>\ConanSandbox\Saved\KrinikSettings.lua (ключ gfx_blood, секунды; нет ключа — свои 300 с). Читается при загрузке; после «Сохранить» окно
-- поднимает общий номер KrinikSettingsVersion (ModRef:SetSharedVariable), а этот мод сверяет номер на каждом пятне — без своего таймера.
-- Не короче угасания: hold_s − fade_s уходит в SetFadeOut задержкой (опись настроек, GFX:103). [TESTED: 2026-10-31 · 60 с после «Сохранить», 300 с после сброса — KUMM testcases/reports/2026-10-31_conan-hub-phase2-first-batch.md, G1]
local HOLD_DEFAULT = CFG.hold_s
local SRC = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/", "\\")
local STORE = (SRC:match("^(.*)\\ConanSandbox\\Binaries\\") or "") .. "\\ConanSandbox\\Saved\\KrinikSettings.lua"
local seen_version = nil

local function read_store(why)
    local v = nil
    local chunk = loadfile(STORE)
    if chunk then
        local ok, t = pcall(chunk)
        if ok and type(t) == "table" and type(t.gfx_blood) == "number" then v = t.gfx_blood end
    end
    CFG.hold_s = math.max(CFG.fade_s + 1.0, v or HOLD_DEFAULT)
    log("кровь лежит %.0f с (%s, %s)", CFG.hold_s, v and "окно «Моды Krinik'а»" or "своё значение", why)
end

local function settings_check()
    local ok, v = pcall(function() return ModRef:GetSharedVariable("KrinikSettingsVersion") end)
    if ok and v ~= nil and v ~= seen_version then
        seen_version = v
        read_store("номер настроек " .. tostring(v))
    end
end
read_store("загрузка")

-- Лежащие пятна по порядку появления: { путь объекта, срок }. Ссылку на объект не храним: пятно, ушедшее само, движок
-- уничтожает, и вызов на устаревшей ссылке роняет игру (урок стенда 2026-10-28 — убитое существо в _G). По пути объект
-- ищется заново (StaticFindObject) и только пока его срок не вышел.
local held = {}
local stat_n, stat_evicted, stat_sum, stat_worst, stat_since = 0, 0, 0.0, 0.0, os.clock()

local function drop_expired(now)
    local alive = {}
    for _, h in ipairs(held) do if h.t > now then alive[#alive + 1] = h end end
    held = alive
end

local busy = false   -- наш собственный SetFadeOut не должен попасть в обработчик второй раз

-- Потолок: `[OWNER]` «Нужно старые убирать, а новые чтобы жили 5 минут» · 2026-10-30 ≈12:5x — самое старое пятно тает за
-- evict_fade_s, новое живёт полный срок.
local function evict_oldest()
    local h = table.remove(held, 1)
    local o = StaticFindObject(h.path)
    if o and o:IsValid() then
        busy = true
        local ok, err = pcall(function() o:SetFadeOut(0.0, CFG.evict_fade_s, true) end)
        busy = false
        if not ok then log("не убрал старое пятно: %s", tostring(err)) end
    end
    stat_evicted = stat_evicted + 1
end

local function on_fade_out(self)
    if busy then return end
    local t0 = os.clock()
    local c = self:get()
    local m = ""
    pcall(function() m = c:GetDecalMaterial():GetFName():ToString() end)
    if m ~= BLOOD_MATERIAL then return end
    settings_check()
    drop_expired(t0)
    while #held >= CFG.hold_cap do evict_oldest() end
    local ramp = CFG.hold_s / CFG.rise
    busy = true
    local ok, err = pcall(function()
        c:SetFadeOut(CFG.hold_s - CFG.fade_s, CFG.fade_s, true)
        c:SetFadeIn(-CFG.start * ramp, ramp)
    end)
    busy = false
    if ok then
        held[#held + 1] = { path = c:GetFullName():gsub("^%S+ ", ""), t = t0 + CFG.hold_s }
        stat_n = stat_n + 1
        if CFG.debug_log then log("пятно %s: лежит %.0f с, лежит всего %d", c:GetFName():ToString(), CFG.hold_s, #held) end
    else
        log("не продлил пятно: %s", tostring(err))
    end
    local ms = (os.clock() - t0) * 1000.0
    stat_sum, stat_worst = stat_sum + ms, math.max(stat_worst, ms)
    if t0 - stat_since >= CFG.summary_s then
        log("за минуту пятен продлено %d, старых убрано по потолку %d (%d), своё время %.3f мс, худшее %.3f мс",
            stat_n, stat_evicted, CFG.hold_cap, stat_sum, stat_worst)
        stat_n, stat_evicted, stat_sum, stat_worst, stat_since = 0, 0, 0.0, 0.0, t0
    end
end

-- Пост-обработчик: родной SetFadeOut уже поставил угасание и свою жизнь 3 с — наша жизнь ложится поверх.
local ok, err = pcall(function() RegisterHook(HOOK, function() end, on_fade_out) end)
if ok then
    log("загружен: кровь на земле лежит %.0f с (родная — 3 с), потолок %d пятен", CFG.hold_s, CFG.hold_cap)
else
    log("хук %s не поставлен: %s", HOOK, tostring(err))
end

--[==[ РАЗДЕЛ 2. Стрела, попавшая во врага, тоже оставляет кровь на земле (KUMM план 36 W30).
  `[OWNER]` «Стрелы её не кладут - странно. Можем сделать, чтобы стрела. попадающая во врага - тоже кровь на жемлю давала?» · 2026-10-30 ≈12:5x.
  Игра кладёт пятно только на удар оружием (DoHandleHitFeedback); попадание снаряда идёт через BP_CollisionComponent.TakeProjectileDamage
  (AttackData, Combo, ActortoDamage, Instigator Controller, Damage Causer, Attacker Community, HitResult, bLocked) — пятна там нет.
  Родное пятно (перехват SpawnDecalAtLocation, удары босса 2026-10-30 23:50): размер (32, 67…95, 67…95), поворот Pitch −90 и случайный Yaw, жизнь 3 с.
  ЧТО ДЕЛАЕТ: после TakeProjectileDamage по персонажу (не по постройке, не в блок) — такое же пятно под ногами цели, затем родной
  SetFadeOut(0, 3): раздел 1 сам продлит его до hold_s. Без трассы к земле: пятно проецируется сверху вниз на глубину DEPTH.
  Одно событие на попадание, без опроса. [NOT-TESTED]
]==]
local ARROW = {
    hook = "/Game/Systems/Combat/BP_CollisionComponent.BP_CollisionComponent_C:TakeProjectileDamage",
    material = "/Game/Effects/blood/M_blood_ground_decal.M_blood_ground_decal",   -- пульт 2026-10-30 23:5x (класс Material); не загружен — поиск по имени
    depth = 64.0,          -- [AI] родные 32; вдвое глубже — склон под целью не обрезает пятно
    size_min = 67.0, size_max = 95.0,   -- как у родного (замер 23:50)
    life = 3.0,
}
local blood_mat, character_class
local function arrow_blood(target, blocked)
    if blocked then return end
    if not (target and target:IsValid()) then return end
    character_class = character_class or StaticFindObject("/Script/Engine.Character")
    if not target:IsA(character_class) then return end
    if not blood_mat then
        blood_mat = StaticFindObject(ARROW.material)
        if not blood_mat then
            for _, m in ipairs(FindAllOf("MaterialInstanceConstant") or {}) do
                if m:GetFName():ToString() == BLOOD_MATERIAL then blood_mat = m; break end
            end
        end
        if not blood_mat then
            for _, m in ipairs(FindAllOf("Material") or {}) do
                if m:GetFName():ToString() == BLOOD_MATERIAL then blood_mat = m; break end
            end
        end
        if not blood_mat then log("стрела: материал %s не найден — пятна не будет", BLOOD_MATERIAL); blood_mat = false; return end
    end
    if blood_mat == false then return end
    local loc = target:K2_GetActorLocation()
    local half = 90.0
    pcall(function() half = target.CapsuleComponent:GetScaledCapsuleHalfHeight() end)
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local y = ARROW.size_min + math.random() * (ARROW.size_max - ARROW.size_min)
    local z = ARROW.size_min + math.random() * (ARROW.size_max - ARROW.size_min)
    local d = gs:SpawnDecalAtLocation(target, blood_mat, { X = ARROW.depth, Y = y, Z = z },
        { X = loc.X, Y = loc.Y, Z = loc.Z - half }, { Pitch = -90.0, Yaw = math.random() * 360.0, Roll = 0.0 }, ARROW.life)
    if d and d:IsValid() then
        d:SetFadeOut(0.0, ARROW.life, true)   -- раздел 1 поймает этот вызов и продлит пятно
        if CFG.debug_log then log("стрела: пятно под %s", target:GetFName():ToString()) end
    end
end
-- Перехват функции блюпринта ставится, когда её класс загружен: при загрузке мода его ещё нет («no UFunction with the specified name was
-- found», 2026-10-30 23:51). Поэтому — по рождению первого BP_CollisionComponent_C, один раз (событие, не опрос).
local arrow_hooked = false
local function hook_arrow()
    if arrow_hooked then return end
    arrow_hooked = true
    -- Работа — в ПРЕ-перехвате: пост-перехват этой функции блюпринта не вызывался (прогон 2026-10-31 08:06: пробный перехват пультом — «pre»
    -- есть, «post» нет; кейс A2b). Цель и флаг блока известны уже до вызова, пятну всё равно, до или после урона.
    local ok2, err2 = pcall(function()
        RegisterHook(ARROW.hook, function(self, attackData, combo, actorToDamage, instigator, causer, community, hitResult, bLocked)
            local okh, e = pcall(arrow_blood, actorToDamage:get(), bLocked:get())
            if not okh then log("стрела: ошибка %s", tostring(e)) end
        end)
    end)
    log("раздел 2 (кровь от стрел): %s", ok2 and "перехват TakeProjectileDamage встал" or ("перехват НЕ встал: " .. tostring(err2)))
end
NotifyOnNewObject("/Game/Systems/Combat/BP_CollisionComponent.BP_CollisionComponent_C", function()
    if not arrow_hooked then ExecuteInGameThread(hook_arrow) end
end)
log("раздел 2 (кровь от стрел): перехват встанет при первом BP_CollisionComponent")
