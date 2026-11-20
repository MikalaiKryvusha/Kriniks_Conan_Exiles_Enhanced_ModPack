-- markers-find.lua — named map places whose Russian name holds one of the words (MapMarkers_ConanSandbox, game map «Test stands by place»).
-- Use: bash pult.sh "lua _G.__mf={'Пляж','Берег'}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/markers-find.lua')"
-- [NOT-TESTED]
local words = _G.__mf or { 'Пляж' }
local t = StaticFindObject('/Game/Systems/Map/MapMarkers_ConanSandbox.MapMarkers_ConanSandbox')
if not t or not t:IsValid() then return 'no table' end
local out = {}
t:ForEachRow(function(name, row)
  local ok, n = pcall(function() return row.Name:ToString() end)
  if ok and n then
    for _, w in ipairs(words) do
      if n:find(w) then
        local l = row.Location
        out[#out + 1] = string.format('%s (%.0f, %.0f, %.0f)', n, l.X, l.Y, l.Z)
        break
      end
    end
  end
end)
return table.concat(out, ' | ')
