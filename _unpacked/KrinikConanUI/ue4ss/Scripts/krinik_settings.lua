--[[
  KrinikConanUI:Settings — the ONE settings store of our mods (KUMM plans/38_epic38_phase2_krinik_hub_window.md, step 3; FORK decided there:
  one file outside every mod folder, so a redeploy of a mod cannot wipe the player's choices).

  File: <game>\ConanSandbox\Saved\KrinikSettings.lua — a plain Lua table `return { key = value, … }`, keys sorted, written ONLY by the hub
  (krinik_mod_settings, «Сохранить»), read once at load by every mod that has rows. A key absent from the file means «the mod's own default».
  Sections of KrinikConanUI share this Lua state: they `require` this module, read S.get(key, default) at the moment they already read the
  constant, and may subscribe with S.on_change(fn(changed)) to apply a saved value at once (no timer — the hub's «Сохранить» is the event).
  Other mods (separate Lua states) read the file themselves at load; their live apply goes through a shared version number (plan 38 step 3).
  [TESTED: 2026-10-31 · desk test _config/tests/test_krinik_settings.lua + live game: written by «Сохранить», read after a restart · KUMM testcases/reports/2026-10-31_conan-hub-phase2-first-batch.md]
]]

local S = { values = {}, listeners = {} }

local SRC = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/", "\\")
local GAME_DIR = SRC:match("^(.*)\\ConanSandbox\\Binaries\\") or ""
S.PATH = GAME_DIR .. "\\ConanSandbox\\Saved\\KrinikSettings.lua"

local function log(fmt, ...) print(("[KrinikConanUI:Settings] " .. fmt .. "\n"):format(...)) end

function S.load()
    local chunk = loadfile(S.PATH)
    if not chunk then
        S.values = {}
        log("no store yet (%s) — every mod keeps its own defaults", S.PATH)
        return S.values
    end
    local ok, t = pcall(chunk)
    S.values = (ok and type(t) == "table") and t or {}
    local n = 0
    for _ in pairs(S.values) do n = n + 1 end
    log("store read: %d keys from %s%s", n, S.PATH, ok and "" or (" (BROKEN: " .. tostring(t) .. ")"))
    return S.values
end

function S.get(key, default)
    local v = S.values[key]
    if v == nil then return default end
    return v
end

local function literal(v)
    if type(v) == "boolean" then return tostring(v) end
    if type(v) == "number" then return ("%.6g"):format(v) end
    return ("%q"):format(tostring(v))
end

-- changes: { key = value | false-for-delete via S.DEFAULT }; writes the whole file (sorted keys — a diff-able, stable file), then tells the listeners
S.DEFAULT = {}
function S.save(changes)
    local changed = {}
    for k, v in pairs(changes) do
        local new = v
        if v == S.DEFAULT then new = nil end   -- not `and v or nil`: a saved false would turn into nil (desk test 2026-10-31 20:3x)
        if S.values[k] ~= new then S.values[k] = new; changed[k] = new == nil and S.DEFAULT or new end
    end
    local keys = {}
    for k in pairs(S.values) do keys[#keys + 1] = k end
    table.sort(keys)
    local lines = { "-- KrinikSettings: the player's choices in «Моды Krinik'а» (written by the game; delete the file to return every mod to its defaults)", "return {" }
    for _, k in ipairs(keys) do lines[#lines + 1] = ("    [%q] = %s,"):format(k, literal(S.values[k])) end
    lines[#lines + 1] = "}"
    local f, err = io.open(S.PATH, "w")
    if not f then log("store NOT written: %s", tostring(err)); return false end
    f:write(table.concat(lines, "\n"), "\n")
    f:close()
    local n = 0
    for _ in pairs(changed) do n = n + 1 end
    -- the other mods (own Lua states) learn of the change by a shared number they compare at a moment they already run (plan 38 step 3)
    S.version = (S.version or os.time()) + 1
    pcall(function() ModRef:SetSharedVariable("KrinikSettingsVersion", S.version) end)
    log("store written: %d keys, %d changed; version %d", #keys, n, S.version)
    for _, fn in ipairs(S.listeners) do
        local ok, e = pcall(fn, changed)
        if not ok then log("listener failed: %s", tostring(e)) end
    end
    return true
end

function S.on_change(fn) S.listeners[#S.listeners + 1] = fn end

S.load()
return S
