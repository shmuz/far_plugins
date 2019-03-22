-- Started: 2018-01-13
-- luacheck: globals ErrMsg

far.ReloadDefaultScript = true -- for debugging needs

local F = far.Flags
local band, bor = bit64.band, bit64.bor
local PluginGuid = export.GetGlobalInfo().Guid -- plugin GUID

if not package.loaded.lsqlite3 then
  local moduleDir = far.PluginStartupInfo().ModuleDir

  -- Provide priority access to lsqlite3.dl residing in the plugin's folder
  -- (needed for deployment of the plugin)
  package.cpath = moduleDir.."?.dl;"..package.cpath

  -- Provide access to sqlite3.dll residing in the plugin's folder
  local path = win.GetEnv("PATH") or ""
  win.SetEnv("PATH", moduleDir..";"..path) -- modify PATH
  local ok, msg = pcall(require, "lsqlite3")
  win.SetEnv("PATH", path) -- restore PATH
  if not ok then error(msg) end

  package.path = moduleDir.."?.lua;"..package.path
end

local M        = require "modules.string_rc"
local sqlite   = require "modules.sqlite"
local settings = require "modules.settings"
local mypanel  = require "modules.panel"


-- add a convenience function
_G.ErrMsg = function(msg, title, flags)
  far.Message(msg, title or M.ps_title_short, nil, flags or "w")
---error(msg) -- need stack
end


-- add a convenience function
unicode.utf8.resize = function(str, n, char)
  local ln = str:len()
  if n <  ln then return str:sub(1, n) end
  if n == ln then return str end
  return str .. (char or "\0"):rep(n-ln)
end


-- add a convenience function (use for schema, table and column names)
function unicode.utf8.norm(str)
  return "'" .. str:gsub("'","''") .. "'"
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


local function LoadOneUserFile (FileData, FullPath, AddModule, gmeta)
  if FileData.FileAttributes:find("d") then return end
  local userchunk, msg = loadfile(FullPath)
  if not userchunk then
    ErrMsg("LOAD: "..FullPath.."\n"..msg)
    return
  end
  local env = {
    UserModule = AddModule;
    NoUserModule = function() end;
  }
  setmetatable(env, gmeta)
  setfenv(userchunk, env)
  local ok, msg = xpcall(function() return userchunk(FullPath) end, debug.traceback)
  if ok then
    env.UserModule, env.NoUserModule = nil, nil
  else
    msg = msg:gsub("\n\t","\n   ")
    ErrMsg("RUN: "..FullPath.."\n"..msg)
  end
end


local function LoadModules(object)
  -- Load common modules (from %farprofile%\PluginsData\polygon)
  local Modules = {}
  local AddModule = CreateAddModule(Modules)
  local gmeta = {__index=_G}
  local dir = win.GetEnv("FARPROFILE")
  if dir and dir~="" then
    dir = dir .. "\\PluginsData\\polygon"
    far.RecursiveSearch(dir, "*.lua", LoadOneUserFile, F.FRS_RECUR, AddModule, gmeta)
  end

  -- Load modules specified in the database itself in a special table
  local obj_info = object:get_info()
  local tablename = ("modules-"..win.Uuid(PluginGuid):lower()):norm()
  local table_exists
  local query = "SELECT name FROM sqlite_master WHERE type='table' AND LOWER(name)="..tablename
  for item in obj_info.db:nrows(query) do
    table_exists = true
  end
  if table_exists then
    local collector = {}
    query = "SELECT * FROM "..tablename.." ORDER BY load_priority DESC"
    for item in obj_info.db:nrows(query) do
      if item.enabled == 1 and type(item.script) == "string" then
        table.insert(collector, item)
      end
    end
    if #collector > 0 then
      local db_dir = obj_info.file_name:gsub("[^\\/]+$","")
      for _,item in ipairs(collector) do
        local fullname = item.script:match("^[a-zA-Z]:") and item.script or db_dir..item.script
        local filedata = win.GetFileInfo(fullname)
        if filedata then
          LoadOneUserFile(filedata, fullname, AddModule, gmeta)
        else
          ErrMsg(fullname, M.ps_module_not_found)
        end
      end
    end
  end

  -- Sort modules
  for _,mod in ipairs(Modules) do
    if type(mod.Priority) ~= "number" then mod.Priority = 50 end
    mod.Priority = math.min(100, math.max(mod.Priority, 0))
  end
  table.sort(Modules, function(a,b) return a.Priority > b.Priority; end)

  -- Call OnOpenConnection()
  for _,mod in ipairs(Modules) do
    if type(mod.OnOpenConnection) == "function" then
      mod.OnOpenConnection(object:get_info())
    end
  end
  return Modules
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


local function AddOptions(flags, Opt)
  if type(flags) == "string" then
    Opt = Opt or {}
    Opt.user_modules = flags:find("u") and true
    Opt.extensions   = flags:find("e") and true
    Opt.foreign_keys = not flags:find("F")
  end
  return Opt
end


-- options must precede file name
local function OpenFromCommandLine(str)
  local file, Opt
  local from = 1
  while true do
    local start1, end1, first, flags = string.find(str, "(%S)(%S*)", from)
    if first == "-" then
      Opt = AddOptions(flags, Opt)
      from = end1 + 1
    else
      file = string.sub(str, from)
      break
    end
  end
  file = file:gsub("\"", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if file == "" then
    file = ":memory:"
  else
    file = file:gsub("%%(.-)%%", win.GetEnv) -- expand environment variables
    file = far.ConvertPath(file, "CPM_FULL")
  end
  return file, Opt
end


local function OpenFromPluginsMenu()
  -- Make sure that current panel item is a real existing file.
  local info = panel.GetPanelInfo(nil, 1)
  if info and info.PanelType == F.PTYPE_FILEPANEL and band(info.Flags,F.OPIF_REALNAMES) ~= 0 then
    local item = panel.GetCurrentPanelItem(nil, 1)
    if item and not item.FileAttributes:find("d") then
      return far.ConvertPath(item.FileName, "CPM_FULL")
    end
  end
end


local function ExecuteLuaCode(code, whatpanel)
  local chunk, msg = loadstring(code)
  if chunk then
    local obj_info, handle
    if whatpanel==0 or whatpanel==1 then
      local pi = panel.GetPanelInfo(nil, whatpanel)
      if pi and pi.PluginObject then
        obj_info = pi.PluginObject:get_info()
        handle = pi.PluginHandle
      end
    end
    local env = setmetatable({}, {__index=_G})
    setfenv(chunk, env)(obj_info, handle)
  else
    ErrMsg(msg)
  end
end


local function OpenFromMacro(params)
  local file_name, Opt = nil, nil

  -- Plugin.Call(<guid>, "open", <filename>[, <flags>])
  if params[1] == "open" and type(params[2]) == "string" then
    file_name = params[2]
    local flags = params[3]
    Opt = AddOptions(flags)

  -- Plugin.Call(<guid>, "lua", [<whatpanel>], <Lua code>)
  elseif params[1] == "lua" and type(params[3]) == "string" then
    local whatpanel, code = params[2], params[3]
    ExecuteLuaCode(code, whatpanel==0 and 1 or whatpanel==1 and 0)

  -- Plugin.Call(<guid>, "sql", <whatpanel>, <SQL code>)
  elseif params[1] == "sql" then
    local whatpanel, code = params[2], params[3]
    if (whatpanel==0 or whatpanel==1) and (type(code)=="string") then
      local info = panel.GetPanelInfo(nil, whatpanel==0 and 1 or 0)
      if info and info.PluginObject then
        info.PluginObject:open_query(info.PluginHandle, code)
      end
    end
  end

  return file_name, Opt
end


function export.Open(OpenFrom, Guid, Item)
  local file_name, Opt = nil, nil

  if OpenFrom == F.OPEN_ANALYSE then
    file_name = Item.FileName
  elseif OpenFrom == F.OPEN_SHORTCUT then
    file_name = Item.HostFile
  elseif OpenFrom == F.OPEN_PLUGINSMENU then
    file_name = OpenFromPluginsMenu()
  elseif OpenFrom == F.OPEN_COMMANDLINE then
    file_name, Opt = OpenFromCommandLine(Item)
  elseif OpenFrom == F.OPEN_FROMMACRO then
    file_name, Opt = OpenFromMacro(Item)
  end

  if file_name then
    Opt = Opt or get_plugin_data()
    local object = mypanel.open(file_name, Opt.extensions, Opt.foreign_keys, Opt.multidb_mode)
    if object then
      object.LoadedModules = Opt.user_modules and LoadModules(object) or {}
      if OpenFrom == F.OPEN_FROMMACRO then
        return { type="panel", [1]=object }
      else
        return object
      end
    end
  end
end


function export.GetOpenPanelInfo(object, handle)
  return object:get_panel_info(handle)
end


function export.GetFindData(object, handle, OpMode)
  return object:get_find_data(handle)
end


function export.SetDirectory(object, handle, Dir, OpMode, UserData)
  if band(OpMode, F.OPM_FIND) == 0 then
    return object:set_directory(handle, Dir, UserData)
  end
end


function export.DeleteFiles(object, handle, PanelItems, OpMode)
  return object:delete_items(handle, PanelItems)
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
  local ret = false
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelEvent) == "function" then
      if mod.ProcessPanelEvent(object:get_info(), handle, Event, Param) then
        ret = true; break;
      end
    end
  end
  if not ret then
    if Event == F.FE_CLOSE then
      if get_plugin_data().confirm_close then
        ret = 1 ~= far.Message(M.ps_confirm_close, M.ps_title_short, M.ps_yes_no)
      end
    elseif Event == F.FE_COMMAND then
      local command, text = Param:match("^%s*(%S+)%s*(.*)")
      if command then
        local Lcommand = command:lower()
        if Lcommand == "cd" or Lcommand:find(":") then
          ret = false -- let Far Manager process that command
        elseif Lcommand == "lua" then
          if text ~= "" then
            ExecuteLuaCode(text, 1)
            panel.UpdatePanel(handle)
          end
          ret = true
        else
          object:open_query(handle, command.." "..text)
          ret = true
        end
      end
    end
  end
  if ret and Event==F.FE_COMMAND then
    panel.SetCmdLine(handle, "")
  end
  return ret
end


function export.Configure()
  settings.configure();
end


function export.Compare(object, handle, PanelItem1, PanelItem2, Mode)
  return object:compare(PanelItem1, PanelItem2, Mode)
end
