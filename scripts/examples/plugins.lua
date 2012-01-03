-- started: 2011-02-20
local standard = [[C:\Program Files\Far3\Plugins\Standard\]]
local separate = [[C:\Program Files\Far3\Plugins\Separate\]]

local items = {
  { text="FTP client",         path=standard.."FTP\\FarFtp.dll" },
  { text="Search and Replace", path=separate.."S_and_R\\s_and_r.dll" },
  { separator=true },
}
local bkeys = {
  { BreakKey="RETURN", command="PCTL_LOADPLUGIN", success="Loaded", fail="Failed to load" },
  { BreakKey="INSERT", command="PCTL_FORCEDLOADPLUGIN", success="Force-loaded", fail="Failed to force-load" },
  { BreakKey="DELETE", command="PCTL_UNLOADPLUGIN", success="Unloaded", fail="Failed to unload" },
}
local props = {
  Title="Plugins", Bottom="Enter/Ins/Del",
}
local item, pos = far.Menu(props, items, bkeys)
if item then
  local bItem = item.BreakKey and item or bkeys[1]
  local mItem = items[pos]
  local result = far.PluginsControl(nil, bItem.command, "PLT_PATH", mItem.path)
  far.Message(result and bItem.success or bItem.fail, mItem.text)
end
