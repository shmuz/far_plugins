-- Select colorizer in the editor.

local F = far.Flags

local function GetData()
  local ScriptId = "1664991a-f7bc-4f15-8fe0-f9a91f918109"
  local data =  rawget(_G, ScriptId)
  if data then return data end
  -- Get space for this script's data. Kept alive between the script's invocations.
  data = {
      { Guid = win.Uuid("D2F36B62-A470-418D-83A3-ED7A3710E5B5") }, -- colorer
      { Guid = win.Uuid("9860393A-918D-450F-A3EA-84186F21B0A2") }, -- airbrush
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
  return data
end

-- Unload all colorizers except the first found one.
--    Should be called from an autostarting macro, like this:
-- Macro {
--   area="Shell"; key="AltShiftF24"; flags="RunAfterFARStart"; description="Init colorizer"; action = function()
--      CallPlugin("6f332978-08b8-4919-847a-efbb6154c99a","InitColorizer")
--   end;
-- }
local function AutoStart (data)
  local firstfound
  for k,v in ipairs(data) do
    local handle = far.FindPlugin("PFM_GUID", v.Guid)
    if handle then
      if firstfound then far.UnloadPlugin(handle)
      else firstfound = true
      end
    end
  end
end

local function CallMenu (data)
  local items = {}
  for k,v in ipairs(data) do
    if v.Title then
      local handle = far.FindPlugin("PFM_GUID", v.Guid)
      items[#items+1] = { checked=handle, text=v.Title, ModuleName=v.ModuleName }
    end
  end
  items[#items+1] = { text="Unload all" }
  return far.Menu({ Title="Select colorizer" }, items)
end

local function UnloadAllPlugins (data)
  for k,v in ipairs(data) do
    local handle = far.FindPlugin("PFM_GUID", v.Guid)
    if handle then far.UnloadPlugin(handle) end
  end
end

local function CleanAllEditors (data)
  local count = far.AdvControl("ACTL_GETWINDOWCOUNT")
  for k=1,count do
    local winfo = far.AdvControl("ACTL_GETWINDOWINFO", k)
    if winfo.Type == F.WTYPE_EDITOR then
      local info = editor.GetInfo(winfo.Id)
      for y = 1,info.TotalLines do
        for k,v in ipairs(data) do editor.DelColor(winfo.Id, y, nil, v.Guid) end
      end
    end
  end
end

do
  local data = GetData()
  local arg = ...
  if arg == "init" then
    AutoStart(data)
  else
    local item = CallMenu(data)
    if item then
      UnloadAllPlugins(data)
      CleanAllEditors(data)
      if item.ModuleName then far.LoadPlugin("PLT_PATH", item.ModuleName) end
    end
  end
end
