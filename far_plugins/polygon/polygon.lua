-- Lua version started: 2018-01-13

far.ReloadDefaultScript = true -- for debugging needs

if not package.cpath_initialized then -- this is needed for "embed" builds of the plugin
  package.cpath = far.PluginStartupInfo().ModuleDir.."?.dl;"..package.cpath
  package.cpath_initialized = true
end

local _FPG     = export.GetGlobalInfo().Guid -- plugin GUID
local F        = far.Flags
local band,bor = bit64.band, bit64.bor
local Utils    = require "far2.utils"

local RunScript = Utils.RunInternalScript
local M        = RunScript("string_rc")
local sqlite   = RunScript("sqlite")
local settings = RunScript("settings", {M=M})
local progress = RunScript("progress", {M=M})
local exporter = RunScript("exporter", {M=M, sqlite=sqlite, progress=progress, settings=settings})
local myeditor = RunScript("editor",   {M=M, sqlite=sqlite, exporter=exporter})
local mypanel  = RunScript("panel",    {M=M, sqlite=sqlite, progress=progress, exporter=exporter, myeditor=myeditor})

-- add a convenience function
_G.ErrMsg = function(msg, flags)
  far.Message(msg, M.ps_title_short, nil, flags or "w")
end

-- add a convenience function
unicode.utf8.resize = function(str, n, char)
  char = char or "\0"
  local ln = str:len()
  if     n <  ln then return str:sub(1, n)
  elseif n == ln then return str
  else return str .. (char or "\0"):rep(n-ln)
  end
end

local plugdata = settings.load():getfield("plugin")

function export.GetPluginInfo()
  local info = { Flags=0 }
  if plugdata.prefix ~= "" then
    info.CommandPrefix = plugdata.prefix
  end

  info.PluginConfigGuids = _FPG
  info.PluginConfigStrings = { M.ps_title }

  if plugdata.add_to_menu then
    info.PluginMenuGuids = _FPG;
    info.PluginMenuStrings = { M.ps_title }
  else
    info.Flags = bor(info.Flags, F.PF_DISABLEPANELS)
  end

  -- if _DEBUG then
  --   info.Flags = bor(info.Flags, F.PF_PRELOAD)
  -- end

  return info
end


function export.Analyse(info)
  if info.FileName and info.FileName~="" and
        sqlite.format_supported(info.Buffer, #info.Buffer) then
    return info.FileName
  end
end


function export.Open(OpenFrom, Guid, Item)
  local file_name = nil

  if OpenFrom == F.OPEN_ANALYSE then
    file_name = Item.Handle

  elseif OpenFrom == F.OPEN_COMMANDLINE then
    local str = Item:gsub("\"", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if str ~= "" then
      str = str:gsub("%%(.-)%%", win.GetEnv) -- expand environment variables
      file_name = far.ConvertPath(str, "CPM_FULL")
    end

  elseif OpenFrom == F.OPEN_PLUGINSMENU then
    -- Make sure that current panel item is a real existing file.
    local info = panel.GetPanelInfo(nil, 1)
    if info and info.PanelType == F.PTYPE_FILEPANEL and band(info.Flags,F.OPIF_REALNAMES) ~= 0 then
      local item = panel.GetCurrentPanelItem(nil, 1)
      if item then
        local name = far.ConvertPath(item.FileName, "CPM_FULL")
        local attr = win.GetFileAttr(name)
        if attr and not attr:find("d") then file_name = name; end
      end
    end
  end

  return file_name and mypanel.open(file_name, false, plugdata.foreign_keys)
end


function export.GetOpenPanelInfo(object, handle)
  return object:get_panel_info()
end


function export.GetFindData(object, handle, OpMode)
  return object:get_panel_list()
end


function export.SetDirectory(object, handle, Dir, OpMode)
  if band(OpMode, F.OPM_FIND) == 0 and band(OpMode, F.OPM_SILENT) == 0 and object then
    if Dir == ".." or Dir == "/" or Dir == "\\" then
      return object:open_database()
    else
      return object:open_object(Dir)
    end
  end
end


function export.ClosePanel(object, handle)
  object._db:close()
end


function export.DeleteFiles(object, handle, PanelItems, OpMode)
  return object:delete_items(PanelItems, #PanelItems)
end


function export.ProcessPanelInput(object, handle, rec)
  return rec.EventType == F.KEY_EVENT and object:handle_keyboard(rec)
end


function export.ProcessPanelEvent (object, handle, Event, Param)
  if Event == F.FE_COMMAND then
    object:open_query(Param)
    panel.SetCmdLine(nil, "")
    return true
  end
end


function export.Configure()
  settings.configure();
end
