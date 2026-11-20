-- craft-queue-recon.lua — READ-ONLY recon of the hero's crafting queue (KUMM bug 94: items started in the hub finish at once after the close).
-- Lists the queue object's class, its functions (name filter optional) and its properties with their current values (numbers, bools, names; arrays —
-- their length), so the fields that hold the current item's duration / progress / start time are found by reading, not guessing.
-- Use: bash _config/pult.sh "lua _G.__cq={filter=nil}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/craft-queue-recon.lua')"
-- [NOT-TESTED]
local a = _G.__cq or {}
local p = FindAllOf('BasePlayerChar_C')[1]
local me = p:GetFullName():match('[^.]+$')
local q
for _, x in ipairs(FindAllOf('ItemInventory') or {}) do
  if x:IsValid() and x:GetFullName():find(me, 1, true) and x:GetFName():ToString() == 'CraftingQueue' then q = x end
end
if not q then return 'no CraftingQueue on the hero' end
local cls = q:GetClass()
local out = { 'class ' .. cls:GetFullName() }
local fns = {}
cls:ForEachFunction(function(f)
  local n = f:GetFName():ToString()
  if not a.filter or n:lower():find(a.filter:lower(), 1, true) then fns[#fns + 1] = n end
end)
table.sort(fns)
out[#out + 1] = 'functions(' .. #fns .. '): ' .. table.concat(fns, ' ')
local props = {}
local c = cls
while c and c:IsValid() do
  c:ForEachProperty(function(pr)
    local n = pr:GetFName():ToString()
    local ok, v = pcall(function() return q[n] end)
    local s
    if not ok then s = '?'
    elseif type(v) == 'number' or type(v) == 'boolean' then s = tostring(v)
    elseif type(v) == 'userdata' then   -- a TrivialObject answers every field with another TrivialObject: probe each method under pcall
      local okA, nA = pcall(function() return v:GetArrayNum() end)
      local okS, tS = pcall(function() return v:ToString() end)
      local okF, tF = pcall(function() return v:GetFullName() end)
      s = (okA and type(nA) == 'number') and ('arr#' .. nA) or (okS and type(tS) == 'string') and tS or (okF and type(tF) == 'string') and tF or 'obj'
    else s = type(v) end
    props[#props + 1] = n .. '=' .. s
  end)
  local ok, sup = pcall(function() return c:GetSuperStruct() end)
  c = ok and sup or nil
  if c and c:IsValid() and c:GetFName():ToString() == 'Object' then break end
end
out[#out + 1] = 'props(' .. #props .. '): ' .. table.concat(props, ' ')
return table.concat(out, '\n')
