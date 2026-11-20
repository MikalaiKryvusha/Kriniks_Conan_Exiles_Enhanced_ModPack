--[[
  KrinikConanUI:Click — a module (not a section; required by the sections) that gives our runtime widgets a mouse press on the GAME thread (KUMM bugs/85).

  Why: a UE4SS RegisterKeyBind callback runs Lua on UE4SS's event-loop thread while the mod's game-thread Lua runs — one lua_State, no lock — and that
  crashed the game twice (bug 85). Lua cannot bind a blueprint delegate, and a Lua-made FLX button (WBP_ButtonBase) stays dead to a press (spike S11 of
  2026-10-30; checked again 2026-11-18 20:22 — a Lua-made button with the Escape shortcut never pressed, with the GameInstance and with the window as its
  owner), so the kit makes two plain UserWidgets (_config/devkit/kit-krinik-click-events.py):
    * W_KrinikClickWrap — an Overlay put AROUND a runtime-made widget; the preview of a left press calls KrinikPreview and returns Unhandled (the press
      goes on to the children). The section then routes the press by IsHovered, as the key bind did (IsHovered works on Lua-made widgets).
    * W_KrinikClickCatcher — a transparent Visible canvas; a left press on it calls KrinikMouseDown and is Handled (the press outside a list).
  One RegisterHook per class (set on the first widget made); its context is the widget, and the handler registered for its address runs on the next
  game-thread pass (outside Slate's routing of the press).

  API: C.wrap() → a new W_KrinikClickWrap (its Overlay root: C.content(w)); C.catcher() → a new W_KrinikClickCatcher; C.on(w, fn(w)) → a token;
  C.off(token).
  A handler is keyed by the widget's address and carries the widget's full name; a press runs it only for the widget it was set for. C.off takes the
  token C.on returned and removes the entry only while it is still that token — the old widget is never asked anything: a freed address comes back for
  a new widget after a world re-entry, and asking the old pointer named the NEW widget or read freed memory (judge 2026-11-18 round 2 finding 3;
  2026-11-20 bug 85 round 3 finding 1). [NOT-TESTED]
]]

local C = {}
local MOD = "KrinikConanUI:Click"
local PKG = "/Game/Mods/KrinikConanUI/"
local CLASSES = {
    wrap = { path = PKG .. "W_KrinikClickWrap.W_KrinikClickWrap_C", event = "KrinikPreview" },
    catcher = { path = PKG .. "W_KrinikClickCatcher.W_KrinikClickCatcher_C", event = "KrinikMouseDown" },
}

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local handlers = {}      -- widget address → the token { fn = fn(widget), name = the widget's full name, addr = the address }
local loaded = {}        -- kind → UClass
local hooked = {}        -- kind → true once its RegisterHook stands

local function class_of(kind)
    if valid(loaded[kind]) then return loaded[kind] end
    local path = CLASSES[kind].path
    local c = StaticFindObject(path)
    if not valid(c) then
        -- UE4SS LoadAsset takes the full object path «Pkg.Obj»; the live-confirmed form for a mod blueprint is the ASSET «Pkg.Name» (KrinikConanArchery,
        -- judge 2026-11-18 R8), the class «Pkg.Name_C» is the second try
        pcall(function() LoadAsset((path:gsub("_C$", ""))) end)
        c = StaticFindObject(path)
        if not valid(c) then pcall(function() LoadAsset(path) end); c = StaticFindObject(path) end
    end
    if not valid(c) then log("class not found: %s", path); return nil end
    loaded[kind] = c
    return c
end

local function hook(kind)
    if hooked[kind] then return end
    hooked[kind] = true
    local spec = CLASSES[kind]
    local ok, e = pcall(RegisterHook, spec.path .. ":" .. spec.event, function(ctx)
        local w = nil
        pcall(function() w = ctx:get() end)
        if not valid(w) then return end
        local h = handlers[w:GetAddress()]
        if not h or h.name ~= w:GetFullName() then return end
        local fn = h.fn
        ExecuteInGameThread(function()
            local ok2, e2 = pcall(fn, w)
            if not ok2 then log("%s handler failed: %s", spec.event, tostring(e2)) end
        end)
    end)
    log("hook %s:%s %s", kind, spec.event, ok and "set" or ("NOT set: " .. tostring(e)))
end

local function create(kind)
    local c = class_of(kind)
    if not c then return nil end
    local pc = FindFirstOf("PlayerController")
    local w = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary"):Create(pc, c, pc)
    if not valid(w) then log("Create %s failed", kind); return nil end
    hook(kind)
    return w
end

function C.wrap() return create("wrap") end
function C.catcher() return create("catcher") end
function C.content(w)
    local root = nil
    pcall(function() root = w.WidgetTree.RootWidget end)
    return root
end
-- C.on returns the entry it registered (a token); C.off takes that token and removes the entry only if it is still the one at its address — compared by
-- identity, with no call on the old widget. A Lua reference to a widget is a raw pointer: after a world re-entry the old catcher's address can hold the NEW
-- button wrap, so «valid(old) and old:GetFullName() == entry.name» was true for the new widget and its handler was erased (the mods button dead after one
-- press); and with the address freed, GetFullName read freed memory — the crash class of bug 85 (judge 2026-11-20, bug 85 round 3, finding 1). [NOT-TESTED]
function C.on(w, fn)
    if not valid(w) then return nil end
    local a = w:GetAddress()
    local h = { fn = fn, name = w:GetFullName(), addr = a }
    handlers[a] = h
    return h
end
function C.off(token)
    if token and handlers[token.addr] == token then handlers[token.addr] = nil end
end

return C
