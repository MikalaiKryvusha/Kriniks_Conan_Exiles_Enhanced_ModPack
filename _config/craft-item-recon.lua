-- craft-item-recon.lua — queue N items of a recipe in the hero's crafting queue and read the queued items RIGHT AWAY: each item object's class, its float
-- and int stats (the duration / progress of a craft is expected there — bug 94), so the field that holds «how long» is found by reading.
-- Use: bash _config/pult.sh "lua _G.__ci={recipe=14000, n=2, ing=14001, ing_n=3}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/craft-item-recon.lua')"
-- Changes the save (ingredients added, items crafted) — saves are the agent's (HOUSE_RULES rule 6). [NOT-TESTED]
local a = _G.__ci or {}
local recipe, n, ing, ing_n = a.recipe or 14000, a.n or 2, a.ing or 14001, a.ing_n or 3
local p = FindAllOf('BasePlayerChar_C')[1]
local me = p:GetFullName():match('[^.]+$')
local bp, q, rm
for _, x in ipairs(FindAllOf('ItemInventory') or {}) do
  if x:IsValid() and x:GetFullName():find(me, 1, true) then
    local nm = x:GetFName():ToString()
    if nm == 'BackpackInventory' then bp = x elseif nm == 'CraftingQueue' then q = x elseif nm == 'RecipeManager' then rm = x end
  end
end
if not (bp and q and rm) then return 'inventories not found' end
bp:AddItemTemplate(ing, -1, FName('None'), n * ing_n + ing_n, false, 100.0, 0.0)
local r = rm:GetItemByTemplateID(recipe, 0)
local k = 0
for i = 1, n do if q:CraftItems(r) then k = k + 1 end end
local out = { 'queued ' .. k .. ' mult ' .. tostring(q.CraftTimeMultiplier) .. ' items in queue ' .. tostring(q.ItemList:GetArrayNum()) }
local list = q.ItemList
for i = 1, list:GetArrayNum() do
  local it = list[i]
  local ok, s = pcall(function()
    local o = it:get()
    local parts = { o:GetClass():GetFName():ToString() }
    o:GetClass():ForEachProperty(function(pr)
      local pn = pr:GetFName():ToString()
      local okv, v = pcall(function() return o[pn] end)
      if okv and (type(v) == 'number' or type(v) == 'boolean') then parts[#parts + 1] = pn .. '=' .. tostring(v) end
      if okv and type(v) == 'userdata' then
        local okA, nA = pcall(function() return v:GetArrayNum() end)
        if okA and type(nA) == 'number' then parts[#parts + 1] = pn .. '#' .. nA end
      end
    end)
    return table.concat(parts, ' ')
  end)
  out[#out + 1] = 'item ' .. i .. ': ' .. (ok and s or ('ERR ' .. tostring(s)))
end
return table.concat(out, '\n')
