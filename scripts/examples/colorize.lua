-- Select colorizer in the editor.

-- Get space for this script's data. Kept alive between the script's invocations.
local ScriptId = "1664991a-f7bc-4f15-8fe0-f9a91f918109"
if not rawget(_G, ScriptId) then -- first run
  local data = {
      { Guid = win.Uuid("9860393A-918D-450F-A3EA-84186F21B0A2") }, -- airbrush
      { Guid = win.Uuid("D2F36B62-A470-418D-83A3-ED7A3710E5B5") }, -- colorer
    }
  rawset(_G, ScriptId, data)
  for k, v in ipairs(data) do
    local handle = far.FindPlugin("PFM_GUID", v.Guid)
    if handle then
      local info = far.GetPluginInformation(handle)
      v.ModuleName = info.ModuleName
      v.Title = info.GInfo.Title
    end
  end
end

local T = _G[ScriptId]
local items = {}
for k,v in ipairs(T) do
  if v.Title then items[#items+1] = { text=v.Title, plugin=v } end
end
items[#items+1] = { text="Unload all" }

local item = far.Menu({ Title="Select colorizer" }, items)
if not item then return end

for k,v in ipairs(T) do
  local handle = far.FindPlugin("PFM_GUID", v.Guid)
  if handle then far.UnloadPlugin(handle) end
end

local info = editor.GetInfo()
for y = 0,info.TotalLines-1 do
  for k,v in ipairs(T) do editor.DelColor(nil, y, -1, v.Guid) end
end
if item.plugin then far.LoadPlugin("PLT_PATH", item.plugin.ModuleName) end
editor.Redraw()
