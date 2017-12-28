-- started: 2011-02-20

local F=far.Flags

-- Get space for this script's data. Kept alive between the script's invocations.
local ScriptId = "263e6208-e5b2-4bf7-8953-59da207279c7"
if not rawget(_G, ScriptId) then rawset(_G, ScriptId, {}) end
local T = _G[ScriptId]

-- A table for plugins' data. Each plugin is keyed here by its GUID.
T.plugins = T.plugins or {}

-- Reset all handles, as they may be closed already.
for k,v in pairs(T.plugins) do v.handle = nil end

-- Update plugins' data with the fresh info.
for _, handle in ipairs(far.GetPlugins()) do
  local info = far.GetPluginInformation(handle)
  info.handle = handle
  T.plugins[info.GInfo.Guid] = info
end

-- Create menu items.
local items = {}
for k,v in pairs(T.plugins) do
  items[#items+1] = {
    text = v.PInfo.PluginMenu.Strings[1] or v.GInfo.Title,
    info = v,
    handle = v.handle,
    grayed = not v.handle,
  }
end

-- Sort menu items alphabetically.
table.sort(items,
  function(a,b) return win.CompareString(a.text, b.text, nil, "cS") < 0 end)

local breakkeys = {
  { BreakKey="RETURN", command="load", success="Loaded", fail="Failed to load" },
  { BreakKey="INSERT", command="forcedload", success="Force-loaded", fail="Failed to force-load" },
  { BreakKey="DELETE", command="unload", success="Unloaded", fail="Failed to unload" },
  { BreakKey="F3", command="info" },
}

local properties = {
  Title="Load/Unload Plugins", Bottom="Enter=load, Ins=force-load, Del=unload",
}

while true do
  local item, pos = far.Menu(properties, items, breakkeys)
  if not item then break end
  properties.SelectIndex = pos
  local bItem = item.BreakKey and item or breakkeys[1]
  local mItem = items[pos]
  local result
  if bItem.command == "load" then
    mItem.handle = far.LoadPlugin("PLT_PATH", mItem.info.ModuleName)
    result = mItem.handle and true
    mItem.grayed = not result
  elseif bItem.command == "forcedload" then
    mItem.handle = far.ForcedLoadPlugin("PLT_PATH", mItem.info.ModuleName)
    result = mItem.handle and true
    mItem.grayed = not result
  elseif bItem.command == "unload" then
    if mItem.handle then
      local GInfo = export.GetGlobalInfo()
      if GInfo.Guid ~= mItem.info.GInfo.Guid then
        result = far.UnloadPlugin(mItem.handle)
        if result then mItem.handle = nil end
        mItem.grayed = result
      else
        far.Message("\nI'm running this script and cannot unload myself !!!\n", GInfo.Title, nil, "w")
      end
    end
  elseif bItem.command == "info" then
    local loaded = far.IsPluginLoaded(mItem.info.GInfo.Guid)
    far.Message(loaded and "is loaded" or "is not loaded")
  end
  --far.Message(result and bItem.success or bItem.fail, mItem.text)
end
