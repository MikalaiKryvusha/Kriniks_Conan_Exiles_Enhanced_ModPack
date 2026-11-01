-- ui_check.lua — замер интерфейса на открытом экране: английский текст в видимых полях, с модом-владельцем поля.
-- [NOT-TESTED]
-- Слово владельца 2026-10-26 (KUMM bugs/64): «тут осталось без переводов» · «видишь как много косяков? и я их за 5 минут нашёл. А это ТЫ
-- должен находить такое». Глаз на кадре пропускает английскую строку среди русских; проход по живым полям — нет.
-- Как: каждый видимый (вместе с родителями) TextBlock/RichTextBlock экземпляра игры; текст с латинским словом из 3+ букв и без кириллицы
-- (клавиши, числа, координаты, имена моделей вида «NPC_…» отсеиваются) → строка «АНГЛ <мод> «текст» <путь виджета>».
-- Владелец — первый внешний объект, чей класс лежит в /Game/Mods/<мод>/, иначе vanilla.
-- Опробовано и отброшено 2026-10-26: наложения по прямоугольникам — GetCachedGeometry в UE4SS приходит нулями (у FGeometry нет полей
-- отражения), координат не достать.
-- Запуск пультом: lua return dofile([[<папка мода>/Scripts/ui_check.lua]])

local function owner_of(w)
    local o = w
    for _ = 1, 40 do
        local ok, outer = pcall(function() return o:GetOuter() end)
        if not ok or not outer or not outer:IsValid() then break end
        local cp = ""
        pcall(function() cp = outer:GetClass():GetFullName() end)
        local mod = cp:match("/Game/Mods/([^/]+)/")
        if mod then return mod end
        o = outer
    end
    return "vanilla"
end

-- виден ли виджет вместе со всеми родителями и внешними пользовательскими виджетами
local function shown(w)
    local p = w
    for _ = 1, 80 do
        if not p or not p:IsValid() then return true end
        local isw = false
        pcall(function() isw = p:IsA(StaticFindObject("/Script/UMG.Widget")) end)
        if not isw then return true end
        local ok, vis = pcall(function() return p:IsVisible() end)
        if not ok or not vis then return false end
        local nxt = nil
        pcall(function() nxt = p:GetParent() end)
        if not nxt or not nxt:IsValid() then
            -- корень дерева: WidgetTree → внешний UserWidget
            pcall(function() nxt = p:GetOuter():GetOuter() end)
        end
        if nxt == p then return true end
        p = nxt
    end
    return true
end

local KEYS = { F1 = true, F2 = true, Shift = true, Esc = true, Ctrl = true, Alt = true, Tab = true, LMB = true, RMB = true,
               OK = true, Ok = true, DLC = true, FPS = true, XP = true, HP = true, ms = true }

local function english(txt)
    if txt:find("[\208\209]") then return false end          -- кириллица в UTF-8 (байты D0/D1) — уже переведено
    local words = 0
    for wd in txt:gmatch("%a%a%a+") do
        if not KEYS[wd] then words = words + 1 end
    end
    if words == 0 then return false end
    if txt:match("^[%w_]+_[%w_]+$") then return false end    -- служебное имя вида NPC_Charred_Remains
    return true
end

local out, seen, total = {}, {}, 0
for _, cls in ipairs({ "TextBlock", "RichTextBlock" }) do
    for _, w in ipairs(FindAllOf(cls) or {}) do
        if w:IsValid() then
            local full = ""
            pcall(function() full = w:GetFullName() end)
            if full:find("/Engine/Transient", 1, true) then
                local txt = ""
                pcall(function() txt = w:GetText():ToString() end)
                if txt:match("%S") and shown(w) then
                    total = total + 1
                    if english(txt) then
                        local mod = owner_of(w)
                        local one = txt:gsub("[\r\n]+", " "):sub(1, 90)
                        local k = mod .. "|" .. one
                        if not seen[k] then
                            seen[k] = true
                            out[#out + 1] = ("АНГЛ %s «%s»  %s"):format(mod, one, full:match("[^%.]+%.[^%.]+$") or full)
                        end
                    end
                end
            end
        end
    end
end
table.sort(out)
table.insert(out, 1, ("видимых полей с текстом: %d · английских: %d"):format(total, #out))
return table.concat(out, "\n")
