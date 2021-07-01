-- coding: UTF-8
-- Started: 2018-01-13
-- luacheck: globals  AppIdToSkip  package  require

AppIdToSkip = AppIdToSkip or {} -- must be global to withstand script reloads
local band, bor, rshift = bit64.band, bit64.bor, bit64.rshift
local Guid_ConfirmClose = win.Uuid("27224BE2-EEF4-4240-808F-38095BCEF7B2")

-- File <fname> can turn the plugin into debug mode.
-- This file should not be distributed with the plugin.
local function ReadIniFile (fname)
  local fp = io.open(fname)
  if fp then
    local t = {}
    for ln in fp:lines() do
      local key,val,nextchar = ln:match("^%s*(%w+)%s*=%s*([%w,]+)%s*(.?)")
      if key and (nextchar=="" or nextchar==";") then
        t[key] = val
      end
    end
    fp:close()

    local v = t["ReloadDefaultScript"]
    if v=="1" or v=="true" then far.ReloadDefaultScript = true; end

    v = t["DontCacheLibraries"]
    if v=="1" or v=="true" then
      package.require = package.require or require
      require = function(name)
        package.loaded[name] = nil
        return package.require(name)
      end
    end

    v = t["AppIdToSkip"] or ""
    for str in v:gmatch("%w+") do
      local N = tonumber(str)
      if N and N <= 0xFFFFFFFF then
        local key = string.char(
          band(rshift(N,24), 0xFF), band(rshift(N,16), 0xFF),
          band(rshift(N, 8), 0xFF), band(rshift(N, 0), 0xFF))
        AppIdToSkip[key] = true
      end
    end
  end
end


local function First_load_actions()
  if not package.loaded.lsqlite3 then
    local pluginDir = far.PluginStartupInfo().ModuleDir
    ReadIniFile(pluginDir.."polygon.ini")

    -- Provide priority access to lsqlite3.dll residing in the plugin's folder
    -- (needed for deployment of the plugin)
    package.cpath = pluginDir.."?.dll;"..package.cpath

    -- Provide access to sqlite3.dll residing in the plugin's folder
    local path = win.GetEnv("PATH") or ""
    win.SetEnv("PATH", pluginDir..";"..path) -- modify PATH
    local ok, msg = pcall(require, "lsqlite3")
    win.SetEnv("PATH", path) -- restore PATH
    if not ok then error(msg) end

    package.path = pluginDir.."?.lua;"..package.path
  end
end

-- In order to properly load sqlite3.dll and lsqlite3.dl,
-- First_load_actions() must precede other require() calls.
First_load_actions()

local M        = require "modules.string_rc"
local mypanel  = require "modules.panel"
local settings = require "modules.settings"
local sqlite   = require "modules.sqlite"
local utils    = require "modules.utils"

local F = far.Flags
local PluginGuid = export.GetGlobalInfo().Guid -- plugin GUID
local ErrMsg, Norm = utils.ErrMsg, utils.Norm


local function get_plugin_data()
  return settings.load().plugin
end


-- Important: this function must not raise errors, in order to allow next user files to be loaded
local function LoadOneUserFile (FileData, FullName, AddModule)
  if FileData.FileAttributes:find("d") then return end
  local userchunk, msg1 = loadfile(FullName)
  if not userchunk then
    ErrMsg("LOAD: "..FullName.."\n"..msg1)
    return
  end
  -- "UserModule" is the loading function name specified in the docs!
  local env = { UserModule = AddModule; }
  setmetatable(env, {__index=_G})
  setfenv(userchunk, env)
  local ok, msg2 = xpcall(
    function() return userchunk(FullName) end, -- FullName is passed according to the docs!
    debug.traceback)
  env.UserModule = nil
  if not ok then
    msg2 = msg2:gsub("\n\t","\n   ")
    ErrMsg("RUN: "..FullName.."\n"..msg2)
  end
end


local function LoadUserModules(object, aLoadCommon, aLoadIndividual)
  local Modules = {}
  local function AddModule(module)
    -- prevent multiple loading of the same module table
    if type(module) == "table" and not Modules[module] then
      Modules[module] = true
      table.insert(Modules, module)
    end
  end

  -- Load common modules (from %farprofile%\PluginsData\polygon)
  if aLoadCommon then
    local dir = win.GetEnv("FARPROFILE")
    if dir and dir~="" then
      dir = dir .. "\\PluginsData\\polygon"
      far.RecursiveSearch(dir, "*.lua", LoadOneUserFile, F.FRS_RECUR, AddModule)
      -- Far build >= 3810 required for calling far.RecursiveSearch with extra parameters
    end
  end

  -- Load modules specified in the database itself in a special table
  if aLoadIndividual then
    local tablename = Norm("modules-"..win.Uuid(PluginGuid):lower())
    local table_exists = false
    local query = "SELECT name FROM sqlite_master WHERE type='table' AND LOWER(name)="..tablename
    object._db:exec(query, function() table_exists=true end)
    if table_exists then
      local collector = {}
      query = "SELECT script,load_priority,enabled FROM "..tablename.." ORDER BY load_priority DESC"
      local stmt = object._db:prepare(query)
      if stmt then
        for item in stmt:nrows(query) do
          if item.enabled == 1 and type(item.script) == "string" then
            table.insert(collector, item)
          end
        end
        stmt:finalize()
        if #collector > 0 then
          local db_dir = object._filename:gsub("[^\\/]+$","")
          for _,item in ipairs(collector) do
            local fullname = item.script:match("^[a-zA-Z]:") and item.script or db_dir..item.script
            local filedata = win.GetFileInfo(fullname)
            if filedata then
              LoadOneUserFile(filedata, fullname, AddModule)
            else
              ErrMsg(fullname, M.module_not_found)
            end
          end
        end
      else
        ErrMsg("Table "..tablename..":\n"..object._dbx:last_error(), M.err_sql)
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
      local ok, msg = xpcall(
        function() mod.OnOpenConnection(object:get_info()) end,
        debug.traceback)
      if not ok then ErrMsg(msg) end
    end
  end
  return Modules
end


function export.GetPluginInfo()
  local info = { Flags=0 }
  local PluginData = get_plugin_data()

  local prefix = PluginData[settings.PREFIX]
  if prefix ~= "" then info.CommandPrefix = prefix; end

  info.PluginConfigGuids = PluginGuid
  info.PluginConfigStrings = { M.title }

  if PluginData[settings.ADD_TO_MENU] then
    info.PluginMenuGuids = PluginGuid;
    info.PluginMenuStrings = { M.title }
  else
    info.Flags = bor(info.Flags, F.PF_DISABLEPANELS)
  end

  return info
end


local function MatchExcludeMasks(filename)
  local mask = get_plugin_data()[settings.EXCL_MASKS]
  return type(mask) == "string"
    and mask:find("%S")
    and far.ProcessName("PN_CMPNAMELIST", mask, filename, "PN_SKIPPATH")
end


function export.Analyse(info)
  -- far.Show(info.OpMode)
  return
    band(info.OpMode,F.OPM_TOPLEVEL) == 0 -- not supposed to process ShiftF1/F2/F3
    and info.FileName
    and info.FileName ~= ""
    and sqlite.format_supported(info.Buffer, #info.Buffer)
    and not AppIdToSkip[string.sub(info.Buffer,69,72)]
    and not MatchExcludeMasks(info.FileName)
end


local function AddOptions(Opt, Str)
  if type(Str) == "string" then
    if Str:find("u") then Opt[settings.COMMON_USER_MODULES]  = true; end
    if Str:find("i") then Opt[settings.INDIVID_USER_MODULES] = true; end
    if Str:find("e") then Opt[settings.EXTENSIONS]           = true; end
    if Str:find("F") then Opt[settings.IGNORE_FOREIGN_KEYS]  = true; end
  end
end


-- options must precede file name
local function OpenFromCommandLine(str)
  local File = ""
  local Opt = {}
  for pos, word in str:gmatch("()(%S+)") do
    if word:sub(1,1) == "-" then
      AddOptions(Opt, word:sub(2))
    else
      File = str:sub(pos)
      break
    end
  end
  File = File:gsub("\"", "")
  File = File:gsub("^%s*(.-)%s*$", "%1")
  if File == "" then
    File = ":memory:"
  else
    File = File:gsub("%%(.-)%%", win.GetEnv) -- expand environment variables
    File = far.ConvertPath(File, "CPM_FULL")
  end
  return File, Opt
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
  -- Plugin.Call(<guid>, "open", <filename>[, <flags>])
  if params[1] == "open" and type(params[2]) == "string" then
    local opt, filename, flags = {}, params[2], params[3]
    AddOptions(opt, flags)
    return filename, opt

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
end


function export.Open(OpenFrom, Guid, Item)
  local FileName, Opt = nil, nil

  if OpenFrom == F.OPEN_ANALYSE then
    FileName = Item.FileName
  elseif OpenFrom == F.OPEN_SHORTCUT then
    FileName = Item.HostFile
  elseif OpenFrom == F.OPEN_PLUGINSMENU then
    FileName = OpenFromPluginsMenu()
  elseif OpenFrom == F.OPEN_COMMANDLINE then
    FileName, Opt = OpenFromCommandLine(Item)
  elseif OpenFrom == F.OPEN_FROMMACRO then
    if Item[1] == "open" then
      FileName, Opt = OpenFromMacro(Item)
    else
      return OpenFromMacro(Item)
    end
  end

  if FileName then
    Opt = Opt or get_plugin_data()
    local object = mypanel.open(FileName,
                   Opt[settings.EXTENSIONS],
                   Opt[settings.IGNORE_FOREIGN_KEYS],
                   Opt[settings.MULTIDB_MODE])
    if object then
      object.LoadedModules = LoadUserModules(object,
                   Opt[settings.COMMON_USER_MODULES],
                   Opt[settings.INDIVID_USER_MODULES])
      if OpenFrom == F.OPEN_FROMMACRO then
        return { type="panel", [1]=object }
      else
        return object
      end
    end
  end
end


function export.GetOpenPanelInfo(object, handle)
  return object:get_open_panel_info(handle)
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
      local ok, msg = xpcall(
        function() mod.ClosePanel(object:get_info(), handle) end,
        debug.traceback)
      if not ok then ErrMsg(msg) end
    end
  end
  object._dbx:close()
end


function export.ProcessPanelInput(object, handle, rec)
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelInput) == "function" then
      local ok, msg = xpcall(
        function() return mod.ProcessPanelInput(object:get_info(), handle, rec) end,
        debug.traceback)
        if ok and msg then return true end
      if not ok then ErrMsg(msg) end
    end
  end
  return rec.EventType == F.KEY_EVENT and object:handle_keyboard(handle, rec)
end


function export.ProcessPanelEvent (object, handle, Event, Param)
  local ret = false
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelEvent) == "function" then
      local ok, val = xpcall(
        function() return mod.ProcessPanelEvent(object:get_info(), handle, Event, Param) end,
        debug.traceback)
      if ok then
        if val then ret = true; break; end
      else
        ErrMsg(val)
      end
    end
  end
  if not ret then
    if Event == F.FE_CLOSE then
      -- work around the Far bug: FE_CLOSE is called twice after a folder shortcut was pressed
      if get_plugin_data()[settings.CONFIRM_CLOSE] and not object.close_confirmed then
        ret = 1 ~= far.Message(M.confirm_close, M.title_short, M.yes_no, "w", nil, Guid_ConfirmClose)
        object.close_confirmed = not ret
      end
    elseif Event == F.FE_COMMAND then
      local command, text = Param:match("^%s*(%S+)%s*(.*)")
      if command then
        local Lcommand = command:lower()
        if Lcommand == "cd" or Lcommand:find(":") then
          ret = false -- let Far Manager process that command
        elseif Lcommand == "lua" then
          if text ~= "" then
            local ok, msg = pcall(ExecuteLuaCode, text, 1) -- pcall is needed to return true to Far
            if not ok then ErrMsg(msg); end                -- even if error occurs (otherwise
            panel.UpdatePanel(handle)                      -- lua.exe will be invoked)
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


--   if oldexport then return end
--   far.ReloadDefaultScript = false
--   oldexport = export
--   export = {}
--   local mt = {}
--   mt.__index = function(t,name)
--     win.OutputDebugString(name)
--     return oldexport[name]
--   end
--   setmetatable(export, mt)
