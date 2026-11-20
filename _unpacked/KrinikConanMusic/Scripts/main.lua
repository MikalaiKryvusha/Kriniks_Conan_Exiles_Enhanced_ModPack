-- KrinikConanMusic — своя музыка игрока в папках по сценам игры (KUMM plan 46).
-- [OWNER] 2026-11-06 17:25 «да, я хотел бы мод музыки» · «можно взять за основу наработки мода по Palworld».
--
-- Как устроено. Эта половина только узнаёт сцену и пишет State\state.json; играет отдельная программа player\krinik_music_player.exe
-- (декодирование mp3/ogg/flac на игровом потоке съело бы весь бюджет 1 мс на все моды — MASTER_PLAN). Схема «детектор на Lua -> state.json ->
-- проигрыватель» взята у Palworld «Area specific background Music» (Nexus 4679); State\ лежит вне Scripts\ — UE4SS перезагружает мод,
-- когда в Scripts\ меняется файл (их урок).
--
-- Откуда сцена (разведка 2026-11-06, games/ConanExiles/mods/KrinikConanMusic.md):
--   * музыка мест — актор BP_SoundStage_C: AudioComponents[1..2] — музыкальная группа (2 слота, кроссфейд), звучащий слот — тот, у которого
--     AudioInfo[i].State == 1 и FadeVolume больше; имя его звука (Music_Area_Middle …) -> сцена по scenes.lua (генерируется из таблиц игры);
--   * бой — компонент героя BP_AC_AudioController_C: PlayingCombatMusicThreatLevel (0 — вне боя), хук на UpdateCombatMusicStateWithNewActor.
-- Чтение — раз в секунду, два свойства двух уже найденных объектов (не поиск по сцене); поиск объекта — только при входе в мир.
-- Родная музыка глушится по ЕЁ звуковому классу (Soundstage_2d_Music, MusicCombat, MusicCombat_Boss) и только пока наша папка сцены не пуста.
-- [NOT-TESTED]

local MOD = "KrinikConanMusic"
local function log(msg) print(string.format("[%s] %s\n", MOD, msg)) end

-- ---------- пути ----------
local function script_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then src = src:sub(2) end
    return src:match("(.*[/\\])") or ""
end
local SCRIPTS = script_dir()
local MODDIR = SCRIPTS:gsub("[/\\]+$", ""):match("^(.*)[/\\][Ss]cripts$") or SCRIPTS
local STATE = MODDIR .. "\\State"
local PLAYER_EXE = MODDIR .. "\\player\\krinik_music_player.exe"
package.path = SCRIPTS .. "?.lua;" .. package.path
local SCENES = require("scenes")

-- ---------- настройки (config.lua в папке мода; нет файла — значения по умолчанию) ----------
local CFG = { volume = 0.8, combat = true, places = true }
do
    local ok, user = pcall(dofile, MODDIR .. "\\config.lua")
    if ok and type(user) == "table" then for k, v in pairs(user) do CFG[k] = v end end
end

-- ---------- самозамер (HOUSE_RULES правило 7: сумма и худший вызов в журнал раз в минуту) ----------
-- os.clock — процессорное время процесса (у игры много потоков, оно бежит быстрее часов): «минута» отмеряется os.time, длительность вызова — os.clock
-- (2026-11-06 18:08: «минута: 9 вызовов» при цикле раз в секунду — минута по os.clock).
local cost_sum, cost_worst, cost_calls, cost_since = 0, 0, 0, os.time()
local function measured(fn)
    return function(...)
        local t = os.clock()
        fn(...)
        local d = (os.clock() - t) * 1000
        cost_sum = cost_sum + d; cost_calls = cost_calls + 1; if d > cost_worst then cost_worst = d end
        if os.time() - cost_since >= 60 then
            log(string.format("минута: %d вызовов, всего %.3f мс, худший %.3f мс", cost_calls, cost_sum, cost_worst))
            cost_sum, cost_worst, cost_calls, cost_since = 0, 0, 0, os.time()
        end
    end
end

-- ---------- state.json ----------
-- Переход сцены не делается одним вызовом: 2026-11-06 19:17 вызов с переходом стоил 2–3 мс (журнал + глушение + запись + чтение файла).
-- Решение — в своей секунде, запись state.json — в следующей (pending_body), перечитывание папок — ещё в следующей (inv_due).
local seq = 0
local last_written = ""
local pending_body = nil
local function write_state(scene, chain, active)
    local parts = {}
    for i, f in ipairs(chain) do parts[i] = '"' .. f .. '"' end
    local body = string.format('{"seq":%d,"scene":"%s","folders":[%s],"volume":%.3f,"active":%s,"quit":false}',
        seq + 1, scene, table.concat(parts, ","), CFG.volume, tostring(active))
    local key = body:gsub('"seq":%d+,', "")
    if key == last_written then return end
    seq = seq + 1; last_written = key
    pending_body = body
end
local function flush_state()
    local body = pending_body; pending_body = nil
    local tmp, dst = STATE .. "\\state.json.tmp", STATE .. "\\state.json"
    local f = io.open(tmp, "w")
    if not f then log("не могу записать " .. tmp); return end
    f:write(body); f:close()
    os.remove(dst)
    local ok, err = os.rename(tmp, dst)
    if not ok then log("не переименовал state.json: " .. tostring(err)) end
end

-- player.json: сколько треков в каждой папке (проигрыватель пересчитывает раз в 5 с)
-- Чтение файла на игровом потоке — самое дорогое в цикле (2026-11-06 18:20: 18–20 мс за минуту, 0.3 мс на вызов): раз в 5 с, проигрыватель и
-- сам пересчитывает папки не чаще.
local inv_cache, inv_at, inv_due = {}, -100, true
-- решение берёт то, что уже прочитано; чтение файла — отдельной секундой (refresh_inventory), по смене сцены и раз в 30 с
local function inventory(force)
    if force or os.time() - inv_at >= 30 then inv_due = true end
    return inv_cache
end
local function refresh_inventory()
    inv_due = false; inv_at = os.time()
    local f = io.open(STATE .. "\\player.json", "r")
    if not f then return end
    local s = f:read("*a"); f:close()
    local inv = {}
    local block = s:match('"inventory":{(.-)}')
    if block then for k, v in block:gmatch('"([%w_]+)":(%d+)') do inv[k] = tonumber(v) end end
    inv_cache = inv
end
local function chain_has_tracks(chain, inv)
    for _, f in ipairs(chain) do if (inv[f] or 0) > 0 then return true end end
    return false
end

-- ---------- родная музыка: глушение по звуковому классу ----------
local CLASS_PATH = {
    stage = { "/Game/Sound/Mixes_Classes/Soundstage_2d_Music.Soundstage_2d_Music" },
    combat = { "/Game/Sound/Mixes_Classes/MusicCombat.MusicCombat", "/Game/Sound/Mixes_Classes/MusicCombat_Boss.MusicCombat_Boss" },
    death = { "/Game/Sound/Mixes_Classes/MusicDeath.MusicDeath" },
}
-- строки журнала одного вызова копятся и печатаются ОДНОЙ строкой в конце (печать в журнал UE4SS — тоже стоимость кадра)
local msgs = {}
local function note(s) msgs[#msgs + 1] = s end
local original_volume = {}
local muted = { stage = false, combat = false, death = false }
local class_obj = {}   -- звуковой класс ищется один раз (2026-11-06 19:08: худший вызов 2 мс приходился на переключение глушения)
local function sound_class(path)
    local sc = class_obj[path]
    if sc == nil or not sc:IsValid() then sc = StaticFindObject(path); class_obj[path] = sc end
    return sc
end
local function set_muted(kind, on)
    if muted[kind] == on then return end
    for _, path in ipairs(CLASS_PATH[kind]) do
        local sc = sound_class(path)
        if sc and sc:IsValid() then
            if original_volume[path] == nil then original_volume[path] = sc.Properties.Volume end
            sc.Properties.Volume = on and 0.0 or original_volume[path]
        else
            log("звуковой класс не найден: " .. path)
        end
    end
    muted[kind] = on
    note((on and "глушу" or "возвращаю") .. " родную музыку: " .. kind)
end

-- ---------- объекты игры ----------
local stage, audio = nil, nil
local function valid(o) return o ~= nil and o:IsValid() end

-- Объекты приходят СОБЫТИЕМ появления (NotifyOnNewObject), а не поиском по сцене каждую секунду: 2026-11-06 18:08 поиск FindFirstOf, пока мира
-- нет, стоил до 24 мс за вызов (правило 7). Один FindFirstOf — только при загрузке мода, на случай уже идущего мира.
local hook_set = false
local update_measured -- объявлен ниже
local function set_hook()
    if hook_set then return end
    local ok, err = pcall(RegisterHook,
        "/Game/Characters/BP_AC_AudioController.BP_AC_AudioController_C:UpdateCombatMusicStateWithNewActor",
        function() end, function() update_measured(true) end)
    hook_set = ok
    log(ok and "хук боя поставлен" or ("хук боя не поставлен: " .. tostring(err)))
end
local function take_stage(s) if valid(s) then stage = s; log("сцена звука: " .. s:GetFullName()) end end
local function take_audio(a) if valid(a) then audio = a; log("боевая музыка героя: " .. a:GetFullName()); set_hook() end end
NotifyOnNewObject("/Game/Systems/Audio/BP_SoundStage.BP_SoundStage_C", take_stage)
NotifyOnNewObject("/Game/Characters/BP_AC_AudioController.BP_AC_AudioController_C", take_audio)
take_stage(FindFirstOf("BP_SoundStage_C"))
take_audio(FindFirstOf("BP_AC_AudioController_C"))

-- звучащий трек музыкальной группы сцены (слоты 1–2)
local function stage_cue()
    if not valid(stage) then return nil end
    local best, best_vol = nil, -1
    for i = 1, 2 do
        local info = stage.AudioInfo[i]
        local comp = stage.AudioComponents[i]
        -- State: 0 — молчит, 1 — нарастает, 2 — звучит (видно в игре 2026-11-06 17:57 и 18:09)
        if info and valid(comp) and info.State ~= 0 and info.FadeVolume > best_vol then
            local snd = comp.Sound
            if valid(snd) then best = snd:GetFName():ToString(); best_vol = info.FadeVolume end
        end
    end
    return best
end

-- Бой — пока список нападающих AggroList не пуст; ступень — PlayingCombatMusicThreatLevel. Сам уровень после боя НЕ сбрасывается
-- (2026-11-06 19:00: вдали от врагов он оставался 2 минутами, и наш боевой тон играл 40 минут без боя); AggroList — 1 у босса, 0 в 150 м от него.
local function threat_level()
    if not valid(audio) then return 0 end
    if #audio.AggroList == 0 then return 0 end
    return audio.PlayingCombatMusicThreatLevel or 0
end

-- ---------- решение ----------
local last_cue, last_level, last_scene = nil, -1, nil
local last_seen_cue, last_seen_level = false, -1
-- Чтение свойств через UE4SS — около 0.03 мс на обращение, за вызов их дюжина: 2026-11-06 19:12 замер 17 мс в минуту, ~0.28 мс на вызов.
-- Поэтому секунды чередуются: в чётную читается сцена, в нечётную — бой (каждое раз в 2 с); хук начала боя читает бой сразу (from_hook).
local tick = 0
local cur_cue, cur_level = nil, 0
local hero_dead = false
local function update(from_hook)
    if from_hook ~= true then                    -- одна отложенная работа на секунду, и в эту секунду больше ничего
        if pending_body then flush_state(); return end
        if inv_due then refresh_inventory(); return end
    end
    tick = tick + 1
    if from_hook == true or tick % 2 == 1 then cur_level = threat_level() end
    if from_hook ~= true and tick % 2 == 0 then cur_cue = stage_cue() end
    local cue, level = cur_cue, cur_level
    if cue ~= last_cue then note("музыка места: " .. tostring(cue)); last_cue = cue end
    if level ~= last_level then note("угроза боя: " .. tostring(level)); last_level = level end

    -- Две сцены живут параллельно, как и в игре: музыка места и боевая. Каждую родную глушим, только если в НАШЕЙ папке этой сцены есть треки;
    -- в бою играет боевая папка, а если она пуста — тишина у нас, и звучит боевая музыка игры.
    -- папки перечитываются при смене сцены (cue или боя) и раз в 30 с — так новые треки подхватываются, а файл не читается каждую секунду
    local inv = inventory(cue ~= last_seen_cue or level ~= last_seen_level)
    last_seen_cue, last_seen_level = cue, level
    local place = ""
    if CFG.places and cue then
        place = SCENES.CUE[cue]
        if place == nil then place = SCENES.UNKNOWN_CUE_SCENE end
    end
    local place_chain = (place ~= "" and SCENES.CHAIN[place]) or {}
    local fight = (CFG.combat and level > 0) and (SCENES.COMBAT_TIER[level] or "combat") or ""
    local fight_chain = (fight ~= "" and SCENES.CHAIN[fight]) or {}
    set_muted("stage", chain_has_tracks(place_chain, inv))
    set_muted("combat", fight ~= "" and chain_has_tracks(fight_chain, inv))
    -- смерть важнее боя и места: от DeathMusic до ClientOnRespawned контроллера игрока (хуки ниже)
    local death_chain = (CFG.death ~= false and hero_dead) and SCENES.CHAIN.death or {}
    set_muted("death", hero_dead and chain_has_tracks(death_chain, inv))
    local scene, chain = place, place_chain
    if fight ~= "" then scene, chain = fight, fight_chain end
    if hero_dead and CFG.death ~= false then scene, chain = "death", death_chain end
    local ours = chain_has_tracks(chain, inv)
    if scene ~= last_scene then note("сцена: " .. (scene ~= "" and scene or "тишина") .. (ours and "" or " (своих треков нет — играет игра)")); last_scene = scene end
    write_state(scene, chain, valid(stage))
    if #msgs > 0 then log(table.concat(msgs, " · ")); msgs = {} end
end
update_measured = measured(update)

-- ---------- запуск ----------
os.execute('mkdir "' .. STATE .. '" 2>nul')
write_state("", {}, false)
flush_state()   -- при загрузке — сразу: проигрыватель стартует следующей строкой
do
    -- start "" запускает проигрыватель отдельно и сразу возвращает управление; проигрыватель сам находит игру и выходит вместе с ней
    local cmd = 'start "" "' .. PLAYER_EXE .. '" "' .. MODDIR .. '"'
    os.execute(cmd)
    log("проигрыватель запущен: " .. PLAYER_EXE)
end

-- Только отложенные действия ИГРОВОГО потока: LoopAsync/ExecuteWithDelay + ExecuteInGameThread роняли игру (два потока на одно состояние Lua,
-- страж _config/check-lua-game-thread.py, 2026-10-28). Хук боя ставится, когда появился компонент героя (set_hook выше).
-- ⛔ Не перезагружать мод через Ctrl+R: у этого цикла нет остановки, горячая перезагрузка добавит второй (урок мода камеры, EXP-0062).
-- Смерть: блюпринт-контроллер игрока FunCombat_PlayerController — DeathMusic включает музыку смерти, ClientOnRespawned — возрождение
-- (экспорт ассета 2026-11-06). Класс грузится вместе с контроллером — хуки ставятся при его появлении.
local death_hooks = false
local function set_death_hooks()
    if death_hooks then return end
    local base = "/Game/Systems/FunCombat_PlayerController.FunCombat_PlayerController_C:"
    local ok1 = pcall(RegisterHook, base .. "DeathMusic", function() end, function() hero_dead = true; update_measured(true) end)
    local ok2 = pcall(RegisterHook, base .. "ClientOnRespawned", function() end, function() hero_dead = false; update_measured(true) end)
    death_hooks = ok1 and ok2
    log("хуки смерти: " .. tostring(ok1) .. " / " .. tostring(ok2))
end
NotifyOnNewObject("/Game/Systems/FunCombat_PlayerController.FunCombat_PlayerController_C", function() set_death_hooks() end)
set_death_hooks()

LoopInGameThreadWithDelay(1000, function()
    update_measured()
    return false
end)

do local n = 0; for _ in pairs(SCENES.CHAIN) do n = n + 1 end; log("загружен, папок в таблице: " .. n) end
