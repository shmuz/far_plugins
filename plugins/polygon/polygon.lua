-- coding: UTF-8
-- Started: 2018-01-13
-- luacheck: globals  AppIdToSkip  package  require  polygon_ResetSort

local DIRSEP = string.sub(package.config, 1, 1)
local OS_WIN = (DIRSEP == "\\")

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
  if package.loaded.lsqlite3 then
    return
  end
  if OS_WIN then
    local pluginDir = far.PluginStartupInfo().ModuleDir
    ReadIniFile(pluginDir.."polygon.ini")

    -- Provide priority access to lsqlite3 DLL residing in the plugin's folder
    -- (needed for deployment of the plugin)
    package.cpath = pluginDir.."?.dll;"..package.cpath

    -- Provide access to sqlite3.dll residing in the plugin's folder
    local path = win.GetEnv("PATH") or ""
    win.SetEnv("PATH", pluginDir..";"..path) -- modify PATH
    local ok, msg = pcall(require, "lsqlite3")
    win.SetEnv("PATH", path) -- restore PATH
    if not ok then error(msg) end

    package.path = pluginDir.."?.lua;"..package.path
  else
    local info = far.PluginStartupInfo()
    ReadIniFile(win.JoinPath(info.ShareDir, "polygon.ini"))
    require "lsqlite3"
  end
end

-- In order to properly load sqlite3.dll and lsqlite3.dl,
-- First_load_actions() must precede other require() calls.
First_load_actions()

local M         = require "modules.string_rc"
local mypanel   = require "modules.panel"
local config    = require "modules.config"
local dbx       = require "modules.sqlite"
local utils     = require "modules.utils"
local plugdebug = require "far2.plugdebug"

local F = far.Flags
local PluginGuid = win.Uuid("D4BC5EA7-8229-4FFE-AAC1-5A4F51A0986A")
local ErrMsg, Norm = utils.ErrMsg, utils.Norm


local function get_plugin_data()
  return config.load().plugin
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
    if OS_WIN then
      local dir = win.GetEnv("FARPROFILE")
      if dir and dir~="" then
        dir = dir .. "\\PluginsData\\polygon"
        far.RecursiveSearch(dir, "*.lua", LoadOneUserFile, F.FRS_RECUR, AddModule)
        -- Far build >= 3810 required for calling far.RecursiveSearch with extra parameters
      end
    else
      local dir = far.InMyConfig("plugins/luafar/polygon")
      far.RecursiveSearch(dir, "*.lua", LoadOneUserFile, F.FRS_RECUR, AddModule)
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
          local db_dir = object._filename:gsub("[^"..DIRSEP.."]+$","")
          for _,item in ipairs(collector) do
            local fullname = item.script:match(OS_WIN and "^[a-zA-Z]:" or "^/")
                             and item.script or db_dir..item.script
            local filedata = win.GetFileInfo(fullname)
            if filedata then
              LoadOneUserFile(filedata, fullname, AddModule)
            else
              ErrMsg(M.module_not_found .. "\n" .. fullname)
            end
          end
        end
      else
        ErrMsg("Table "..tablename..":\n"..dbx.last_error(object._db), M.err_sql)
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

  local prefix = PluginData[config.PREFIX]
  if prefix ~= "" then info.CommandPrefix = prefix; end

  if OS_WIN then
    info.PluginConfigGuids = PluginGuid
  end
  info.PluginConfigStrings = { M.title }

  if PluginData[config.ADD_TO_MENU] then
    if OS_WIN then
      info.PluginMenuGuids = PluginGuid;
    end
    info.PluginMenuStrings = { M.title }
  else
    info.Flags = bor(info.Flags, F.PF_DISABLEPANELS)
  end

  return info
end


local function MatchExcludeMasks(filename)
  local mask = get_plugin_data()[config.EXCL_MASKS]
  return type(mask) == "string"
    and mask:find("%S")
    and far.ProcessName("PN_CMPNAMELIST", mask, filename, "PN_SKIPPATH")
end


local function CreatePanel(FileName, Opt, OpenFrom)
  Opt = Opt or get_plugin_data()
  local object = mypanel.open(FileName,
                 Opt[config.EXTENSIONS],
                 Opt[config.IGNORE_FOREIGN_KEYS],
                 Opt[config.MULTIDB_MODE])
  if object then
    object.LoadedModules = LoadUserModules(object,
                 Opt[config.COMMON_USER_MODULES],
                 Opt[config.INDIVID_USER_MODULES])
    if OpenFrom == F.OPEN_FROMMACRO then
      return { type="panel", [1]=object }
    else
      return object
    end
  end
end


local function Analyse(FileName, Buffer, OpMode)
  return
    band(OpMode, F.OPM_TOPLEVEL+F.OPM_FIND) == 0 -- not supposed to process ShiftF1/F2/F3
    and FileName
    and FileName ~= ""
    and dbx.format_supported(Buffer, #Buffer)
    and not AppIdToSkip[string.sub(Buffer,69,72)]
    and not MatchExcludeMasks(FileName)
end


function export.Analyse(info)
  return Analyse(info.FileName, info.Buffer, info.OpMode)
end


local function AddOptions(Opt, Str)
  if type(Str) == "string" then
    if Str:find("u") then Opt[config.COMMON_USER_MODULES]  = true; end
    if Str:find("i") then Opt[config.INDIVID_USER_MODULES] = true; end
    if Str:find("e") then Opt[config.EXTENSIONS]           = true; end
    if Str:find("F") then Opt[config.IGNORE_FOREIGN_KEYS]  = true; end
  end
end


-- options must precede file name
local function OpenFromCommandLine(str)
  local File = ""
  local Opt = {}
  for pos, word in str:gmatch("()(%S+)") do
    if word:sub(1,1) == "-" then
      if     word == "-startdebug" then plugdebug.Start() -- undocumented
      elseif word == "-stopdebug"  then plugdebug.Stop()  -- undocumented
      else AddOptions(Opt, word:sub(2))
      end
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
    File = OS_WIN and File:gsub("%%(.-)%%", win.GetEnv) or win.ExpandEnv(File)
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

  elseif params[1] == "startdebug" then plugdebug.Start() -- undocumented
  elseif params[1] == "stopdebug"  then plugdebug.Stop()  -- undocumented

  end
end


function export.Open(OpenFrom, Guid, Item)
  local FileName, Opt = nil, nil

  if OpenFrom == F.OPEN_ANALYSE then
    if OS_WIN then FileName = Item.FileName
    else FileName = Item
    end

  elseif OpenFrom == F.OPEN_SHORTCUT then
    if OS_WIN then FileName = Item.HostFile
    else FileName = Item
    end

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
    return CreatePanel(FileName, Opt, OpenFrom)
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
  object._db:close()
end


local function ProcessPanelInput(object, handle, rec)
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelInput) == "function" then
      local func = function()
        return mod.ProcessPanelInput(object:get_info(), handle, rec)
      end
      local ok, msg = xpcall(func, debug.traceback)
      if ok and msg then
        return true
      end
      if not ok then ErrMsg(msg) end
    end
  end
  return rec.EventType == F.KEY_EVENT and object:handle_keyboard(handle, rec)
end


local function ProcessKey(object, handle, key, controlstate)
  if 0 ~= band(key, F.PKF_PREPROCESS) then
    return
  end
  local cs = 0
  if 0 ~= band(controlstate, F.PKF_CONTROL) then cs = bor(cs, 0x08) end -- LEFT_CTRL_PRESSED
  if 0 ~= band(controlstate, F.PKF_ALT    ) then cs = bor(cs, 0x02) end -- LEFT_ALT_PRESSED
  if 0 ~= band(controlstate, F.PKF_SHIFT  ) then cs = bor(cs, 0x10) end -- SHIFT_PRESSED
  local rec = {
    EventType = F.KEY_EVENT;
    KeyDown = true;
    VirtualKeyCode = key;
    ControlKeyState = cs;
  }
  return ProcessPanelInput(object, handle, rec)
end


export.ProcessPanelInput = OS_WIN and ProcessPanelInput or nil
export.ProcessKey = (not OS_WIN) and ProcessKey or nil


function export.ProcessPanelEvent (object, handle, Event, Param)
  if Event == F.FE_REDRAW then
    polygon_ResetSort()
  end

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
      if get_plugin_data()[config.CONFIRM_CLOSE] and not object.close_confirmed then
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
  config.showdialog();
end


if plugdebug.Running() then
  local msg = "On_Default_Script_Loaded"
  plugdebug.Start()
  if OS_WIN then
    win.OutputDebugString(msg)
  else
    far.Log(msg)
  end
end
