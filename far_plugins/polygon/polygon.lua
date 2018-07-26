-- Lua version started: 2018-01-13
-- luacheck: globals ErrMsg LOG polygon

far.ReloadDefaultScript = true -- for debugging needs
local MyExport = { GetGlobalInfo = export.GetGlobalInfo; } -- function defined in another file

_G.polygon = _G.polygon or {}

polygon.debug = function(turn_on)
  if not polygon.DEBUG ~= not turn_on then
    polygon.DEBUG = not polygon.DEBUG
    if far.RunDefaultScript then far.RunDefaultScript() end
  end
end

-- Debug section -------------------------------------------------------------------------
if polygon.DEBUG then
  _G.LOG = win.OutputDebugString
  local Exclusions = {
    -- functions that need to avoid calling __index metamethod on them
    SetDirectory = true;
    ProcessPanelInput = true;
    ProcessPanelEvent = true;
  }
  _G.export = setmetatable({}, { __index =
    function(t,k)
      if not Exclusions[k] then LOG("export." .. k); end
      return MyExport[k]
    end })
else
  _G.LOG = function() end
  _G.export = MyExport
end
-- /Debug section ------------------------------------------------------------------------

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

local Params = {}
do
  local run = (require "far2.utils").RunInternalScript
  -- the order of calls here is important!
  Params.M        = run("string_rc")
  Params.sqlite   = run("sqlite")
  Params.settings = run("settings", Params)
  Params.progress = run("progress", Params)
  Params.exporter = run("exporter", Params)
  Params.myeditor = run("editor",   Params)
  Params.mypanel  = run("panel",    Params)
end

local M        = Params.M
local sqlite   = Params.sqlite
local settings = Params.settings
local mypanel  = Params.mypanel

local PluginGuid = MyExport.GetGlobalInfo().Guid -- plugin GUID


-- add a convenience function
_G.ErrMsg = function(msg, title, flags)
  far.Message(msg, title or M.ps_title_short, nil, flags or "w")
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


local function LoadModules(object)
  -- Load modules
  local Modules = {}
  local dir = win.GetEnv("FARPROFILE")
  if dir and dir~="" then
    dir = dir .. "\\PluginsData\\polygon"
    far.RecursiveSearch(dir, "*.lua", LoadOneUserFile, F.FRS_RECUR,
                        CreateAddModule(Modules), {__index=_G})
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


function MyExport.GetPluginInfo()
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


function MyExport.Analyse(info)
  return info.FileName and info.FileName~="" and
         sqlite.format_supported(info.Buffer, #info.Buffer)
end


local function OpenFromCommandLine(name)
  local str = name:gsub("\"", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if str == "" then
    str = ":memory:"
  else
    str = str:gsub("%%(.-)%%", win.GetEnv) -- expand environment variables
    str = far.ConvertPath(str, "CPM_FULL")
  end
  return str
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
    if type(flags) == "string" then
      Opt = {}
      Opt.user_modules = flags:find("u") and true
      Opt.extensions   = flags:find("e") and true
      Opt.foreign_keys = flags:find("f") and true
    end

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


function MyExport.Open(OpenFrom, Guid, Item)
  local file_name, Opt = nil, nil

  if OpenFrom == F.OPEN_ANALYSE then
    file_name = Item.FileName
  elseif OpenFrom == F.OPEN_SHORTCUT then
    file_name = Item.HostFile
  elseif OpenFrom == F.OPEN_PLUGINSMENU then
    file_name = OpenFromPluginsMenu()
  elseif OpenFrom == F.OPEN_COMMANDLINE then
    file_name = OpenFromCommandLine(Item)
  elseif OpenFrom == F.OPEN_FROMMACRO then
    file_name, Opt = OpenFromMacro(Item)
  end

  if file_name then
    Opt = Opt or get_plugin_data()
    local object = mypanel.open(file_name, false, Opt.extensions, Opt.foreign_keys)
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


function MyExport.GetOpenPanelInfo(object, handle)
  return object:get_panel_info(handle)
end


function MyExport.GetFindData(object, handle, OpMode)
  return object:get_panel_list(handle)
end


function MyExport.SetDirectory(object, handle, Dir, OpMode)
  if polygon.DEBUG then
    LOG("export.SetDirectory: "..tostring(Dir))
  end
  if band(OpMode, F.OPM_FIND) == 0 then
    return object:set_directory(handle, Dir)
  end
end


function MyExport.DeleteFiles(object, handle, PanelItems, OpMode)
  return object:delete_items(handle, PanelItems, #PanelItems)
end


function MyExport.ClosePanel(object, handle)
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ClosePanel) == "function" then
      mod.ClosePanel(object:get_info(), handle)
    end
  end
  object._dbx:close()
end


function MyExport.ProcessPanelInput(object, handle, rec)
  if polygon.DEBUG then
    if rec.EventType ~= F.MENU_EVENT then
      LOG("export.ProcessPanelInput: " .. (far.InputRecordToName(rec) or "unknown"))
    end
  end
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelInput) == "function" then
      if mod.ProcessPanelInput(object:get_info(), handle, rec) then
        return true
      end
    end
  end
  return rec.EventType == F.KEY_EVENT and object:handle_keyboard(handle, rec)
end


local FAR_EVENTS = {
	[0] = "FE_CHANGEVIEWMODE",
	[1] = "FE_REDRAW",
	[2] = "FE_IDLE",
	[3] = "FE_CLOSE",
	[4] = "FE_BREAK",
	[5] = "FE_COMMAND",
	[6] = "FE_GOTFOCUS",
	[7] = "FE_KILLFOCUS",
	[8] = "FE_CHANGESORTPARAMS",
};

function MyExport.ProcessPanelEvent (object, handle, Event, Param)
  if polygon.DEBUG then
    LOG("export.ProcessPanelEvent: " .. (FAR_EVENTS[Event] or tostring(Event)))
  end
  for _,mod in ipairs(object.LoadedModules) do
    if type(mod.ProcessPanelEvent) == "function" then
      if mod.ProcessPanelEvent(object:get_info(), handle, Event, Param) then
        return true
      end
    end
  end
  if Event == F.FE_COMMAND then
    local command, text = Param:match("^%s*(%S+)%s*(.*)")
    command = command and command:lower() or ""
    if command == "lua" then
      ExecuteLuaCode(text, 1)
    elseif command == "sql" then
      object:open_query(handle, text)
    elseif not command:find("%S") then
      -- do nothing
    else
      far.Message("sql <SQL query>\n"..
                  "      or\n"..
                  "lua <Lua code>", "Syntax", nil, "l")
    end
    panel.SetCmdLine(nil, "")
    return true
  end
end


function MyExport.Configure()
  settings.configure();
end


function MyExport.Compare(object, handle, PanelItem1, PanelItem2, Mode)
  return object:compare(PanelItem1, PanelItem2, Mode)
end
