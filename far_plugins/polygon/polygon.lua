-- Lua version started: 2018-01-13

far.ReloadDefaultScript = true -- for debugging needs

local F = far.Flags
local band,bor = bit64.band, bit64.bor

if not package.cpath_initialized then -- this is needed for "embed" builds of the plugin
  package.cpath = far.PluginStartupInfo().ModuleDir.."?.dl;"..package.cpath
  package.cpath_initialized = true
end

local Utils     = require "far2.utils"
local RunScript = Utils.RunInternalScript
local M         = RunScript("string_rc")
local sqlite    = RunScript("sqlite")
local settings  = RunScript("settings", {M=M})
local progress  = RunScript("progress", {M=M})
local exporter  = RunScript("exporter", {M=M, progress=progress, settings=settings})
local myeditor  = RunScript("editor",   {M=M, sqlite=sqlite, exporter=exporter})
local mypanel   = RunScript("panel",    {M=M, sqlite=sqlite, progress=progress, exporter=exporter, myeditor=myeditor})

local PluginGuid = export.GetGlobalInfo().Guid -- plugin GUID
local PluginData = settings.load():getfield("plugin")
local User = {} -- contains table LoadedModules, functions AddModule, LoadOneFile, LoadFiles.


-- add a convenience function
_G.ErrMsg = function(msg, flags)
  far.Message(msg, M.ps_title_short, nil, flags or "w")
end

-- add a convenience function
unicode.utf8.resize = function(str, n, char)
  local ln = str:len()
  if n <  ln then return str:sub(1, n) end
  if n == ln then return str end
  return str .. (char or "\0"):rep(n-ln)
end


-- add a convenience function (use for table names and column names)
unicode.utf8.normalize = function(str)
  return '"' .. str:gsub('"','""') .. '"'
end


function User.AddModule (srctable, FileName)
  if  type(srctable) == "table" and type(srctable.Info) == "table" then
    local guid = srctable.Info.Guid
    if type(guid) == "string" and #guid == 16 then
      if not User.LoadedModules[guid] then
        if FileName then srctable.FileName=FileName; end
        User.LoadedModules[guid] = srctable
        table.insert(User.LoadedModules, srctable)
      end
    end
  end
end


function User.LoadOneFile (FindData, FullPath, gmeta)
  if FindData.FileAttributes:find("d") then return end
  local f, msg = loadfile(FullPath)
  if not f then
    ErrMsg("LOAD: "..FullPath.."\n"..msg)
    return
  end
  local env = {
    UserModule = function(t) return User.AddModule(t,FullPath) end;
    NoUserModule = function() end;
  }
  setmetatable(env, gmeta)
  setfenv(f, env)
  local ok, msg = xpcall(function() return f(FullPath) end, debug.traceback)
  if ok then
    env.UserModule, env.NoUserModule = nil
  else
    msg = msg:gsub("\n\t","\n   ")
    ErrMsg("RUN: "..FullPath.."\n"..msg)
  end
end


function User.LoadFiles()
  User.LoadedModules = {}
  local dir = win.GetEnv("FARPROFILE")
  if dir and dir~="" then
    dir = dir .. "\\PluginsData\\polygon"
    far.RecursiveSearch(dir, "*.lua", User.LoadOneFile, F.FRS_RECUR, {__index=_G})
  end
end


function export.GetPluginInfo()
  local info = { Flags=0 }
  if PluginData.prefix ~= "" then
    info.CommandPrefix = PluginData.prefix
  end

  info.PluginConfigGuids = PluginGuid
  info.PluginConfigStrings = { M.ps_title }

  if PluginData.add_to_menu then
    info.PluginMenuGuids = PluginGuid;
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
  return info.FileName and info.FileName~="" and
         sqlite.format_supported(info.Buffer, #info.Buffer)
end


function export.Open(OpenFrom, Guid, Item)
  User.LoadFiles()
  local file_name = nil

  if OpenFrom == F.OPEN_ANALYSE then
    file_name = Item.FileName

  elseif OpenFrom == F.OPEN_COMMANDLINE then
    local str = Item:gsub("\"", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if str == "" then
      file_name = ":memory:"
    else
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
        if attr and not attr:find("d") then
          file_name = name
        end
      end
    end

  elseif OpenFrom == F.OPEN_SHORTCUT then
    file_name = Item.HostFile

  end

  return file_name and mypanel.open(file_name, false, PluginData.foreign_keys)
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
  object._dbx:close()
end


function export.DeleteFiles(object, handle, PanelItems, OpMode)
  return object:delete_items(PanelItems, #PanelItems)
end


function export.ProcessPanelInput(object, handle, rec)
  return rec.EventType == F.KEY_EVENT and object:handle_keyboard(rec)
end


function export.ProcessPanelEvent (object, handle, Event, Param)
  for _,mod in ipairs(User.LoadedModules) do
    if type(mod.ProcessPanelEvent) == "function" then
      if mod.ProcessPanelEvent(object:get_info(), Event, Param) then
        return true
      end
    end
  end
  if Event == F.FE_COMMAND then
    object:open_query(Param)
    panel.SetCmdLine(nil, "")
    return true
  elseif Event == F.FE_CHANGESORTPARAMS then
    object:change_sort_params(Param)
    return false
  end
end


function export.Configure()
  settings.configure();
end


function export.Compare(object, handle, PanelItem1, PanelItem2, Mode)
  return object:compare(PanelItem1, PanelItem2, Mode)
end
