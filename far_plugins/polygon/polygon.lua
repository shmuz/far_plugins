-- Lua version started: 2018-01-13

far.ReloadDefaultScript = true -- for debugging needs

local F = far.Flags
local band,bor = bit64.band, bit64.bor

if not package.loaded.lsqlite3 then -- this is needed for "embed" builds of the plugin
  -- make possible to use lsqlite3.dl residing in the plugin's folder
  package.cpath = far.PluginStartupInfo().ModuleDir.."?.dl;"..package.cpath
  -- make possible to use sqlite3.dll residing in the plugin's folder
  local oldpath = win.GetEnv("PATH")
  win.SetEnv("PATH", far.PluginStartupInfo().ModuleDir..";"..oldpath)
  require "lsqlite3"
  win.SetEnv("PATH", oldpath)
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


local function get_plugin_data()
  return settings.load():getfield("plugin")
end


local function CreateAddModule (LoadedModules)
  return function (srctable, FileName)
    if  type(srctable) == "table" then
      if not LoadedModules[srctable] then
        LoadedModules[srctable] = true
        if FileName then srctable.FileName=FileName; end
        table.insert(LoadedModules, srctable)
      end
    end
  end
end


local function LoadOneUserFile (FindData, FullPath, AddModule, gmeta)
  if FindData.FileAttributes:find("d") then return end
  local f, msg = loadfile(FullPath)
  if not f then
    ErrMsg("LOAD: "..FullPath.."\n"..msg)
    return
  end
  local env = {
    UserModule = AddModule;
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


local function LoadUserFiles()
  local LoadedModules = {}
  local dir = win.GetEnv("FARPROFILE")
  if dir and dir~="" then
    dir = dir .. "\\PluginsData\\polygon"
    far.RecursiveSearch(dir, "*.lua", LoadOneUserFile, F.FRS_RECUR,
                        CreateAddModule(LoadedModules), {__index=_G})
  end
  return LoadedModules
end


function export.GetPluginInfo()
  local info = { Flags=0 }
  local PluginData = get_plugin_data()

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

  return info
end


function export.Analyse(info)
  return info.FileName and info.FileName~="" and
         sqlite.format_supported(info.Buffer, #info.Buffer)
end


function export.Open(OpenFrom, Guid, Item)
  -- prepare some values
  local file_name = nil
  local PluginData = get_plugin_data()
  local opt_user_modules = PluginData.user_modules
  local opt_extensions   = PluginData.extensions
  local opt_foreign_keys = PluginData.foreign_keys

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

  elseif OpenFrom == F.OPEN_FROMMACRO then
    -- Plugin.Call(<guid>, "open", <filename>[, <flags>])
    if Item[1] == "open" and type(Item[2]) == "string" then
      file_name = Item[2]
      if type(Item[3]) == "string" then
        opt_user_modules = Item[3]:find("u") and true
        opt_extensions   = Item[3]:find("e") and true
        opt_foreign_keys = Item[3]:find("f") and true
      end
    end

  end

  if file_name then
    local object = mypanel.open(file_name, false, opt_extensions, opt_foreign_keys)
    if object then
      if opt_user_modules then
        -- Load modules
        object.LoadedModules = LoadUserFiles()
        -- Sort modules
        for _,mod in ipairs(object.LoadedModules) do
          if type(mod.Priority) ~= "number" then mod.Priority = 50 end
          mod.Priority = math.min(100, math.max(mod.Priority, 0))
        end
        table.sort(object.LoadedModules, function(a,b) return a.Priority > b.Priority; end)
        -- Call OnOpenConnection()
        for _,mod in ipairs(object.LoadedModules) do
          if type(mod.OnOpenConnection) == "function" then
            mod.OnOpenConnection(object:get_info())
          end
        end
      else
        object.LoadedModules = {}
      end
      if OpenFrom == F.OPEN_FROMMACRO then
        return { type="panel", [1]=object }
      else
        return object
      end
    end
  end

end


function export.GetOpenPanelInfo(object, handle)
  return object:get_panel_info()
end


function export.GetFindData(object, handle, OpMode)
  return object:get_panel_list()
end


function export.SetDirectory(object, handle, Dir, OpMode)
  if band(OpMode, F.OPM_FIND) == 0 then
    return object:set_directory(Dir)
  end
end


function export.DeleteFiles(object, handle, PanelItems, OpMode)
  return object:delete_items(PanelItems, #PanelItems)
end


function export.ClosePanel(object, handle)
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ClosePanel) == "function" then
      mod.ClosePanel(object:get_info(), handle)
    end
  end
  object._dbx:close()
end


function export.ProcessPanelInput(object, handle, rec)
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelInput) == "function" then
      if mod.ProcessPanelInput(object:get_info(), handle, rec) then
        return true
      end
    end
  end
  return rec.EventType == F.KEY_EVENT and object:handle_keyboard(handle, rec)
end


function export.ProcessPanelEvent (object, handle, Event, Param)
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelEvent) == "function" then
      if mod.ProcessPanelEvent(object:get_info(), handle, Event, Param) then
        return true
      end
    end
  end
  if Event == F.FE_COMMAND then
    object:open_query(Param)
    panel.SetCmdLine(nil, "")
    return true
  end
end


function export.Configure()
  settings.configure();
end


function export.Compare(object, handle, PanelItem1, PanelItem2, Mode)
  return object:compare(PanelItem1, PanelItem2, Mode)
end
