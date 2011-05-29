-------------------------------------------------------------------------------
-- LuaFAR for Editor: main script
-------------------------------------------------------------------------------
local MinLuafarVersion = { 3, 0 }

-- CONFIGURATION : keep it at the file top !!
local DefaultConfig = {
  -- Default script will be recompiled and run every time OpenPlugin/OpenFilePlugin
  -- are called: set true for debugging, false for normal use;
  ReloadDefaultScript = false,

  -- Reload Lua libraries each time they are require()d:
  -- set true for libraries debugging, false for normal use;
  RequireWithReload   = false,

  -- After executing utility from main menu, return to the menu again
  ReturnToMainMenu    = false,

  UseStrict           = false, -- Use require 'strict'
}

-- UPVALUES : keep them above all function definitions !!
local Utils = require "far2.utils"
local M     = require "lf4ed_message"
local LibHistory = require "far2.history"
local F = far.Flags
local FirstRun = not _Plugin
local band, bor, bxor, bnot = bit64.band, bit64.bor, bit64.bxor, bit64.bnot
lf4ed = lf4ed or {}

local CurrentConfig, _History, _ModuleDir

local function ErrMsg(msg, buttons, flags)
  return far.Message(msg, "Error", buttons, flags or "w")
end

local function ScriptErrMsg(msg)
  (type(export.OnError)=="function" and export.OnError or ErrMsg)(msg)
end

local function ShallowCopy (src)
  local trg = {}; for k,v in pairs(src) do trg[k]=v end
  return trg
end

local InternalLibs = { string=1,table=1,os=1,coroutine=1,math=1,io=1,debug=1,
                       _G=1,package=1,far=1,bit64=1,unicode=1,win=1 }

local function RequireWithReload (name)
  if name and not InternalLibs[name] then
    package.loaded[name] = nil
  end
  return _Plugin.OriginalRequire(name)
end

local function ResetPackageLoaded()
  for name in pairs(package.loaded) do
    if not InternalLibs[name] then
      package.loaded[name] = nil
    end
  end
end

local function OnConfigChange (cfg)
  -- 1 --
  package.loaded.strict = nil
  if cfg.UseStrict then require "strict"
  else setmetatable(_G, nil)
  end
  -- 2 --
  require = cfg.RequireWithReload and RequireWithReload or _Plugin.OriginalRequire
  -- 3 --
  far.ReloadDefaultScript = cfg.ReloadDefaultScript
end

-------------------------------------------------------------------------------
-- @param newcfg: if given, it is a table with configuration parameters to set.
-- @return: a copy of the configuration table (as it was before the call).
-------------------------------------------------------------------------------
function lf4ed.config (newcfg)
  assert(not newcfg or (type(newcfg) == "table"))
  local t = {}
  for k in pairs(DefaultConfig) do t[k] = CurrentConfig[k] end
  if newcfg then
    for k,v in pairs(newcfg) do
      if DefaultConfig[k] ~= nil then CurrentConfig[k] = v end
    end
    OnConfigChange(CurrentConfig)
  end
  return t
end

function lf4ed.version()
  return table.concat(export.GetGlobalInfo().Version, ".")
end

local function ConvertUserHotkey(str)
  local d = 0
  for elem in str:upper():gmatch("[^+-]+") do
    if elem == "ALT" then d = bor(d, 0x01)
    elseif elem == "CTRL" then d = bor(d, 0x02)
    elseif elem == "SHIFT" then d = bor(d, 0x04)
    else d = d .. "+" .. elem; break
    end
  end
  return d
end

local function RunUserFunc (aArgTable, aItem, ...)
  assert(aItem.filename, "no file name")
  assert(aItem.env, "no environment")
  -- compile the file
  local chunk, msg = loadfile(aItem.filename)
  if not chunk then error(msg,2) end
  -- copy "fixed" arguments
  local argCopy = ShallowCopy(aArgTable)
  for i,v in ipairs(aItem.arg) do argCopy[i] = v end
  -- append "variable" arguments
  for i=1,select("#", ...) do argCopy[#argCopy+1] = select(i, ...) end
  -- run the chunk
  setfenv(chunk, aItem.env)
  chunk(argCopy)
end

local function fSort (aArg)
  local sortlines = require "sortlines"
  aArg[1] = _History:field("SortDialog")
  repeat
    local normal, msg = pcall(sortlines.SortWithDialog, aArg)
    if not normal then
      -- "Cancel" breaks infinite loop when exception is thrown by far.Dialog()
      if 0 ~= ErrMsg(msg, ";RetryCancel") then break end
    end
  until normal
end

local function fWrap (aArg)
  aArg[1] = _History:field("WrapDialog")
  return Utils.RunFile("<wrap|wrap.lua", aArg)
end

local function fBlockSum (aArg)
  aArg[1], aArg[2] = "BlockSum", _History:field("BlockSum")
  return Utils.RunFile("<expression|expression.lua", aArg)
end

local function fExpr (aArg)
  aArg[1], aArg[2] = "LuaExpr", _History:field("LuaExpression")
  return Utils.RunFile("<expression|expression.lua", aArg)
end

local function fScript (aArg)
  aArg[1], aArg[2] = "LuaScript", _History:field("LuaScript")
  return Utils.RunFile("<expression|expression.lua", aArg)
end

local function fScriptParams (aArg)
  aArg[1], aArg[2] = "ScriptParams", _History:field("LuaScript")
  return Utils.RunFile("<expression|expression.lua", aArg)
end

local function fPluginConfig (aArg)
  aArg[1] = CurrentConfig
  if Utils.RunFile("<config|config.lua", aArg) then
    OnConfigChange(CurrentConfig)
    return true
  end
end

local EditorMenuItems = {
  { text = "::MSort",         action = fSort },
  { text = "::MWrap",         action = fWrap },
  { text = "::MBlockSum",     action = fBlockSum },
  { text = "::MExpr",         action = fExpr },
  { text = "::MScript",       action = fScript },
  { text = "::MScriptParams", action = fScriptParams },
}

-- Split command line into separate arguments.
-- * An argument is either of:
--     a) a sequence of 0 or more characters enclosed within a pair of non-escaped
--        double quotes; can contain spaces; enclosing double quotes are stripped
--        from the argument.
--     b) a sequence of 1 or more non-space characters.
-- * Backslashes only escape double quotes.
-- * The function does not raise errors.
local function SplitCommandLine (str)
  local pat = [["((?:\\"|[^"])*)"|((?:\\"|\S)+)]]
  local out = {}
  for c1, c2 in far.gmatch(str, pat) do
    out[#out+1] = far.gsub(c1 or c2, [[\\(")|(.)]], "%1%2")
  end
  return out
end

local function MakeAddCommand (Items, Env)
  return function (aCommand, aFileName, ...)
    if type(aCommand)=="string" and type(aFileName)=="string" then
      _Plugin.CommandTable[aCommand] = { filename=_ModuleDir..aFileName, env=Env,
                                        arg={...} }
    end
  end
end

local function MakeAddToMenu (Items, Env)
  local function AddToMenu (aWhere, aItemText, aHotKey, aFileName, ...)
    if type(aWhere) ~= "string" then return end
    aWhere = aWhere:lower()
    if not aWhere:find("[evpdc]") then return end
    ---------------------------------------------------------------------------
    local SepText = type(aItemText)=="string" and aItemText:match("^:sep:(.*)")
    local bUserItem = SepText or type(aFileName)=="string"
    if not bUserItem then
      if aItemText~=true or type(aFileName)~="number" then
        return
      end
    end
    ---------------------------------------------------------------------------
    if not SepText and aWhere:find("[ec]") and type(aHotKey)=="string" then
      local HotKeyTable = _Plugin.HotKeyTable
      aHotKey = ConvertUserHotkey (aHotKey)
      if bUserItem then
        HotKeyTable[aHotKey] = {filename=_ModuleDir..aFileName, env=Env, arg={...}}
      else
        HotKeyTable[aHotKey] = aFileName
      end
    end
    ---------------------------------------------------------------------------
    if bUserItem and aItemText then
      local item
      if SepText then
        item = { text=SepText, separator=true }
      else
        item = { text=tostring(aItemText),
                 filename=_ModuleDir..aFileName, env=Env, arg={...} }
      end
      if aWhere:find"c" then table.insert(Items.config, item) end
      if aWhere:find"d" then table.insert(Items.dialog, item) end
      if aWhere:find"e" then table.insert(Items.editor, item) end
      if aWhere:find"p" then table.insert(Items.panels, item) end
      if aWhere:find"v" then table.insert(Items.viewer, item) end
    end
  end
  return AddToMenu
end

local function RunExitScriptHandlers()
  local t = _Plugin.ExitScriptHandlers
  for i = 1,#t do t[i]() end
end

local function InsertHandler (env, name, target)
  local f = rawget(env, name)
  if type(f)=="function" then table.insert(target, f) end
end

local function MakeResident (source)
  local env
  local meta = { __index=_G }
  local tp = type(source)
  if tp == "string" then
    local chunk, errmsg = loadfile(_ModuleDir .. source)
    if not chunk then error(errmsg, 2) end
    env = setmetatable({}, meta)
    local ok, errmsg = pcall(setfenv(chunk, env))
    if not ok then error(errmsg, 2) end
  elseif tp == "table" then
    env = setmetatable(source, meta)
  else
    return
  end
  InsertHandler(env, "ProcessEditorInput", _Plugin.EditorInputHandlers)
  InsertHandler(env, "ProcessEditorEvent", _Plugin.EditorEventHandlers)
  InsertHandler(env, "ProcessViewerEvent", _Plugin.ViewerEventHandlers)
  InsertHandler(env, "ExitScript",         _Plugin.ExitScriptHandlers)
end

local function MakeAddUserFile (aEnv, aItems)
  local uDepth, uStack, uMeta = 0, {}, {__index = _G}
  local function AddUserFile (filename)
    uDepth = uDepth + 1
    filename = _ModuleDir .. filename
    if uDepth == 1 then
      -- if top-level _usermenu.lua doesn't exist, it isn't error
      local attr = win.GetFileAttr(filename)
      if not attr or attr:find("d") then return end
    end
    ---------------------------------------------------------------------------
    local chunk = assert(loadfile(filename))
    ---------------------------------------------------------------------------
    uStack[uDepth] = setmetatable({}, uMeta)
    aEnv.AddToMenu = MakeAddToMenu(aItems, uStack[uDepth])
    aEnv.AddCommand = MakeAddCommand(aItems, uStack[uDepth])
    setfenv(chunk, aEnv)()
    uDepth = uDepth - 1
  end
  return AddUserFile
end

local function MakeAutoInstall (AddUserFile)
  local function AutoInstall (startpath, filepattern, depth)
    assert(type(startpath)=="string", "bad arg. #1 to AutoInstall")
    assert(filepattern==nil or type(filepattern)=="string", "bad arg. #2 to AutoInstall")
    assert(depth==nil or type(depth)=="number", "bad arg. #3 to AutoInstall")
    ---------------------------------------------------------------------------
    startpath = _ModuleDir .. startpath:gsub("[\\/]*$", "\\", 1)
    filepattern = filepattern or "^_usermenu%.lua$"
    ---------------------------------------------------------------------------
    local first = depth
    local offset = _ModuleDir:len() + 1
    for _, item in ipairs(far.GetDirList(startpath) or {}) do
      if first then
        first = false
        local _, m = item.FileName:gsub("\\", "")
        depth = depth + m
      end
      if not item.FileAttributes:find"d" then
        local try = true
        if depth then
          local _, n = item.FileName:gsub("\\", "")
          try = (n <= depth)
        end
        if try then
          local relName = item.FileName:sub(offset)
          local Name = relName:match("[^\\/]+$")
          if Name:match(filepattern) then AddUserFile(relName) end
        end
      end
    end
  end
  return AutoInstall
end

local function fReloadUserFile()
  if not FirstRun then
    RunExitScriptHandlers()
    ResetPackageLoaded()
  end
  package.path = _Plugin.PackagePath -- restore to original value
  _Plugin.HotKeyTable = {}
  _Plugin.CommandTable = {}
  _Plugin.EditorEventHandlers = {}
  _Plugin.ViewerEventHandlers = {}
  _Plugin.EditorInputHandlers = {}
  _Plugin.ExitScriptHandlers = {}
  -----------------------------------------------------------------------------
  _Plugin.UserItems = { editor={},viewer={},panels={},config={},cmdline={},dialog={} }
  local env = setmetatable({}, {__index=_G})
  env.AddUserFile  = MakeAddUserFile(env, _Plugin.UserItems)
  env.AutoInstall  = MakeAutoInstall(env.AddUserFile)
  env.MakeResident = MakeResident
  -----------------------------------------------------------------------------
  env.AddUserFile("_usermenu.lua")
end

local function traceback3(msg)
  return debug.traceback(msg, 3)
end

local function RunMenuItem(aArg, aItem, aRestoreConfig)
  local argCopy = ShallowCopy(aArg) -- prevent parasite connection between utilities
  local restoreConfig = aRestoreConfig and lf4ed.config()
  local function wrapfunc()
    if aItem.action then return aItem.action(argCopy) end
    return RunUserFunc(argCopy, aItem)
  end
  local ok, result = xpcall(wrapfunc, traceback3)
  local result2 = CurrentConfig.ReturnToMainMenu
  if restoreConfig then lf4ed.config(restoreConfig) end
  if not ok then ScriptErrMsg(result) end
  return ok, result, result2
end

local function Configure (aArg)
  local properties, items = {
    Flags = {FMENU_WRAPMODE=1, FMENU_AUTOHIGHLIGHT=1}, Title = M.MPluginNameCfg,
    HelpTopic = "Contents",
  }, {
    { text=M.MPluginSettings, action=fPluginConfig },
    { text=M.MReloadUserFile, action=fReloadUserFile },
  }
  for _,v in ipairs(_Plugin.UserItems.config) do items[#items+1]=v end
  while true do
    local item, pos = far.Menu(properties, items)
    if not item then return end
    local ok, result = RunMenuItem(aArg, item, false)
    if not ok then return end
    if result then _History:save() end
    if item.action == fReloadUserFile then return "reloaded" end
    properties.SelectIndex = pos
  end
end

local function export_Configure (Guid)
  Configure({From="config"})
  return true
end

local function AddMenuItems (src, trg)
  trg = trg or {}
  for _, item in ipairs(src) do
    local text = item.text
    if type(text)=="string" and text:sub(1,2)=="::" then
      local newitem = {}
      for k,v in pairs(item) do newitem[k] = v end
      newitem.text = M[text:sub(3)]
      trg[#trg+1] = newitem
    else
      trg[#trg+1] = item
    end
  end
  return trg
end

local function MakeMainMenu(aFrom)
  local properties = {
    Flags = {FMENU_WRAPMODE=1, FMENU_AUTOHIGHLIGHT=1}, Title = M.MPluginName,
    HelpTopic = "Contents", Bottom = "alt+sh+f9", }
  --------
  local items = {}
  if aFrom == "editor" then AddMenuItems(EditorMenuItems, items) end
  AddMenuItems(_Plugin.UserItems[aFrom], items)
  --------
  local keys = {{ BreakKey="AS+F9", action=Configure },}
  return properties, items, keys
end

local function CommandSyntaxMessage()
  local syn = [[

Syntax:
  lfe: [<options>] <command>|-r<filename> [<arguments>]
    or
  CallPlugin(0x10000, [<options>] <command>|-r<filename>
                                          [<arguments>])
Options:
  -a          asynchronous execution
  -e <str>    execute string <str>
  -l <lib>    load library <lib>

Available commands:
]]

  if next(_Plugin.CommandTable) then
    local arr = {}
    for k in pairs(_Plugin.CommandTable) do arr[#arr+1] = k end
    table.sort(arr)
    syn = syn .. "  " .. table.concat(arr, ", ")
  else
    syn = syn .. "  <no commands available>"
  end
  far.Message(syn, M.MPluginName..": "..M.MCommandSyntaxTitle, ";Ok", "l")
end

-------------------------------------------------------------------------------
-- This function processes both command line calls and calls from macros.
-- Externally, it should always be called with a string 1st argument.
-- Internally, it does two passes: the 1-st pass is intended for syntax checking;
-- if the syntax is correct, the function calls itself with a table 1st argument.
-------------------------------------------------------------------------------
local function ProcessCommand (source, sFrom)
  local pass2 = (type(source) == "table")
  local args = pass2 and source or SplitCommandLine(source)
  if #args==0 then return CommandSyntaxMessage() end
  local opt, async
  local env = setmetatable({}, {__index=_G})
  for i,v in ipairs(args) do
    local param
    if opt then
      param = v
    elseif v:sub(1,1) == "-" then
      opt, param = v:match("^%-([aelr])(.*)")
      if not opt then return CommandSyntaxMessage() end
    else
      local fileobject = _Plugin.CommandTable[v]
      if not fileobject then return CommandSyntaxMessage() end
      if pass2 then
        local oldConfig = lf4ed.config()
        local wrapfunc = function()
          return RunUserFunc({From=sFrom}, fileobject, unpack(args, i+1))
        end
        local ok, res = xpcall(wrapfunc, traceback3)
        lf4ed.config(oldConfig)
        if not ok then ScriptErrMsg(res) end
      end
      break
    end
    if opt == "a" then
      opt, async = nil, true
    elseif param ~= "" then
      if opt=="r" then
        if pass2 then
          local f = assert(loadfile(Utils.CorrectPath(param)))
          setfenv(f, env)(unpack(args, i+1))
        end
        break
      elseif opt=="e" then
        if pass2 then
          local f = assert(loadstring(param))
          setfenv(f, env)()
        end
      elseif opt=="l" then
        if pass2 then require(param) end
      end
      opt = nil
    end
  end
  if not pass2 then
    if async then
      ---- autocomplete:good; Escape response:bad when timer period < 20;
      far.Timer(30, function(h) h:Close() ProcessCommand(args, sFrom) end)
    else
      ---- autocomplete:bad; Escape responsiveness:good;
      return ProcessCommand(args, sFrom)
    end
  end
end

local function export_Open (aFrom, aGuid, aItem) -- TODO

  -- Called from macro
  if band(aFrom, bnot(F.OPEN_FROM_MASK)) ~= 0 then
    if band(aFrom, F.OPEN_FROMMACRO) ~= 0 then
      aFrom = band(aFrom, bnot(F.OPEN_FROMMACRO))
      if band(aFrom, F.OPEN_FROMMACRO_MASK) == F.OPEN_FROMMACROSTRING then
        local map = {
          [F.MACROAREA_SHELL]  = "panels",
          [F.MACROAREA_EDITOR] = "editor",
          [F.MACROAREA_VIEWER] = "viewer",
          [F.MACROAREA_DIALOG] = "dialog",
        }
        local lowByte = band(aFrom, F.OPEN_FROM_MASK)
        ProcessCommand(aItem, map[lowByte] or aFrom)
      end
    end
    return
  end

  -- Called from command line
  if aFrom == F.OPEN_COMMANDLINE then
    ProcessCommand(aItem, "panels")
    return
  end

  -- Called from a not supported source
  local map = {
    [F.OPEN_PLUGINSMENU] = "panels",
    [F.OPEN_EDITOR] = "editor",
    [F.OPEN_VIEWER] = "viewer",
    [F.OPEN_DIALOG] = "dialog",
  }
  if map[aFrom] == nil then
    return
  end

  -----------------------------------------------------------------------------
  local sFrom = map[aFrom]
  local history = _History:field("menu." .. sFrom)
  local properties, items, keys = MakeMainMenu(sFrom)
  properties.SelectIndex = history.position
  while true do
    local item, pos = far.Menu(properties, items, keys)
    if not item then break end
    history.position = pos
    local arg = { From = sFrom }
    if sFrom == "dialog" then arg.hDlg = aItem.hDlg end
    local ok, result, bRetToMainMenu = RunMenuItem(arg, item, item.action~=Configure)
    if not ok then break end
    _History:save()
    if not (bRetToMainMenu or item.action==Configure) then break end
    if item.action==Configure and result=="reloaded" then
      properties, items, keys = MakeMainMenu(sFrom)
    else
      properties.SelectIndex = pos
    end
  end
end

local PluginMenuGuid1   = win.Uuid("e7218df9-e556-4801-8715-f14e2348fcce")
local PluginConfigGuid1 = win.Uuid("0411deb2-73d0-49a6-95c0-3e24150edd44")

local function export_GetPluginInfo()
  local flags = bor(F.PF_EDITOR, F.PF_DISABLEPANELS)
  local useritems = _Plugin.UserItems
  if useritems then
    if #useritems.panels > 0 then flags = F.PF_EDITOR end
    if #useritems.viewer > 0 then flags = bor(flags, F.PF_VIEWER) end
    if #useritems.dialog > 0 then flags = bor(flags, F.PF_DIALOG) end
  end
  return {
    CommandPrefix = "lfe",
    Flags = flags,
    PluginConfigGuids   = PluginConfigGuid1.."",
    PluginConfigStrings = { M.MPluginName },
    PluginMenuGuids   = PluginMenuGuid1.."",
    PluginMenuStrings = { M.MPluginName },
  }
end

local function export_ExitFAR()
  RunExitScriptHandlers()
  _History:save()
end

local function KeyComb (Rec)
  local f = 0
  local state = Rec.dwControlKeyState
  local ALT   = bor(F.LEFT_ALT_PRESSED, F.RIGHT_ALT_PRESSED)
  local CTRL  = bor(F.LEFT_CTRL_PRESSED, F.RIGHT_CTRL_PRESSED)
  local SHIFT = F.SHIFT_PRESSED

  if 0 ~= band(state, ALT) then f = bor(f, 0x01) end
  if 0 ~= band(state, CTRL) then f = bor(f, 0x02) end
  if 0 ~= band(state, SHIFT) then f = bor(f, 0x04) end
  f = f .. "+" .. Rec.wVirtualKeyCode
  return f
end

local function export_ProcessEditorInput (Rec)
  local EventType = Rec.EventType
  if (EventType==F.FARMACRO_KEY_EVENT) or (EventType==F.KEY_EVENT) then
    local item = _Plugin.HotKeyTable[KeyComb(Rec)]
    if item then
      if Rec.bKeyDown then
        if type(item)=="number" then item = EditorMenuItems[item] end
        if item then RunMenuItem({From="editor"}, item, item.action~=Configure) end
      end
      return true
    end
  end
  for _,f in ipairs(_Plugin.EditorInputHandlers) do
    if f(Rec) then return true end
  end
end

local function export_ProcessEditorEvent (Event, Param)
  for _,f in ipairs(_Plugin.EditorEventHandlers) do
    f(Event, Param)
  end
end

local function export_ProcessViewerEvent (Event, Param)
  for _,f in ipairs(_Plugin.ViewerEventHandlers) do
    f(Event, Param)
  end
end

local function SetExportFunctions()
  export.Configure          = export_Configure
  export.ExitFAR            = export_ExitFAR
  export.GetPluginInfo      = export_GetPluginInfo
  export.Open               = export_Open
  export.ProcessEditorEvent = export_ProcessEditorEvent
  export.ProcessEditorInput = export_ProcessEditorInput
  export.ProcessViewerEvent = export_ProcessViewerEvent
end

local function InitUpvalues (_Plugin)
  _ModuleDir, _History = _Plugin.ModuleDir, _Plugin.History
  CurrentConfig = _History:field("PluginSettings")
  setmetatable(CurrentConfig, { __index=DefaultConfig })
  OnConfigChange(CurrentConfig)
end

local function main()
  if FirstRun then
    _Plugin = Utils.InitPlugin()
    if not Utils.CheckLuafarVersion(MinLuafarVersion, M.MPluginName) then
      return
    end
    _Plugin.PackagePath = package.path:gsub(";", ";".._Plugin.ModuleDir.."scripts\\?.lua;", 1)
    _Plugin.OriginalRequire = require
    _Plugin.History = LibHistory.newsettings(nil, "alldata")
  end

  InitUpvalues(_Plugin)
  SetExportFunctions()

  if FirstRun then
    fReloadUserFile()
    FirstRun = false -- needed when (ReloadDefaultScript == false)
  end
end

main()
