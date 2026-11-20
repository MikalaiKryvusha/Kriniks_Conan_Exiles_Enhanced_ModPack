-- talk-read.lua — the open NPC talk as text: the NPC's current line (the subtitle renderer) and every reply button with its index and label
-- (KUMM plan 60 skills, case D2 of issue #3). Read-only.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/talk-read.lua')"
-- With _G.__tr_pick = <n> it CHOOSES reply n through the window's own handler `W_NPCDialogue2_C:HandleButtonClicked(Button)` (the function the click's
-- bound event calls — it acts only when the talk is ready for the player's input) and then reads again; `_G.__tr_pick` is cleared after use.
-- [NOT-TESTED]
local function live(cls)
    local out = {}
    for _, w in ipairs(FindAllOf(cls) or {}) do
        local f = w:GetFullName()
        if not f:find("Default__", 1, true) and not f:find(":WidgetTree.", 1, true) then out[#out + 1] = w end
    end
    return out
end
local win = live("W_NPCDialogue2_C")[1]
if not win then return "no talk window open" end
local buttons = {}
for _, b in ipairs(live("WBP_ButtonDialogue_C")) do
    local vis = b:GetVisibility()
    if vis ~= 1 and vis ~= 2 then buttons[#buttons + 1] = b end      -- 1 Collapsed, 2 Hidden
end
local pick = _G.__tr_pick
_G.__tr_pick = nil
local picked = ""
if pick then
    local b = buttons[pick]
    if not b then return "no reply " .. tostring(pick) .. " (there are " .. #buttons .. ")" end
    picked = "picked " .. pick .. " «" .. b:GetLabel():ToString() .. "» · "
    win:HandleButtonClicked(b)
end
local line = "?"
pcall(function()
    local r = win:GetWidgetFromName(FName("W_SubtitleRenderer"))
    local texts = {}
    for _, t in ipairs(FindAllOf("TextBlock") or {}) do
        local f = t:GetFullName()
        if f:find(r:GetFName():ToString(), 1, true) and t:GetVisibility() ~= 1 then
            local s = t:GetText():ToString()
            if s ~= "" then texts[#texts + 1] = s end
        end
    end
    line = table.concat(texts, " / ")
end)
local labels = {}
for i, b in ipairs(buttons) do labels[#labels + 1] = i .. ") " .. b:GetLabel():ToString() end
local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
local dil = gs:GetGlobalTimeDilation(FindFirstOf("PlayerController"))
return string.format("%sdilation %.4f · NPC: %s · replies: %s", picked, dil, line, table.concat(labels, " | "))
