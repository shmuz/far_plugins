-------------------------------------------------------------------------------
-- LuaFAR for Editor: main script
-------------------------------------------------------------------------------

-- CONFIGURATION : keep it at the file top !!
local DefaultConfig = {
  -- Default script will be recompiled and run every time OpenW
  -- is called: set true for debugging, false for normal use;
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
local LibHistory = require "far2.history"

local FirstRun = ... --> this works with Far >= 3.0.4425
if FirstRun then
  _Plugin = Utils.InitPlugin()
  package.path = _Plugin.ModuleDir.."?.lua;".._Plugin.ModuleDir.."scripts\\?.lua;"..package.path
  _Plugin.PackagePath = package.path
  _Plugin.OriginalRequire = require
  _Plugin.History = LibHistory.newsettings(nil, "alldata")
end

local M = require "lf4ed_message"
local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor, bxor, bnot = bit64.band, bit64.bor, bit64.bxor, bit64.bnot
lf4ed = lf4ed or {}
local _ModuleDir, _History = _Plugin.ModuleDir, _Plugin.History

local CurrentConfig

local InternalLibs = { string=1,table=1,os=1,coroutine=1,math=1,io=1,debug=1,_G=1,package=1,
                       far=1,bit64=1,unicode=1,win=1,editor=1,viewer=1,panel=1,regex=1 }
if rawget(_G, "jit") and jit.version then
  InternalLibs.jit, InternalLibs.bit, InternalLibs.ffi = 1, 1, 1
end

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

local function fSort()
  local sortlines = require "sortlines"
  local arg = { _History:field("SortDialog") }
  repeat
    local normal, msg = pcall(sortlines.SortWithDialog, arg)
    if not normal then
      -- "Cancel" breaks infinite loop when exception is thrown by far.Dialog()
      if 1 ~= far.Message(msg, M.MError, ";RetryCancel", "w") then break end
    end
  until normal
end

local function fWrap()
  local arg = { _History:field("WrapDialog") }
  return Utils.RunInternalScript("wrap", arg)
end

local function fBlockSum()
  local arg = { "BlockSum", _History:field("BlockSum") }
  return Utils.RunInternalScript("expression", arg)
end

local function fExpr()
  local arg = { "LuaExpr", _History:field("LuaExpression") }
  return Utils.RunInternalScript("expression", arg)
end

local function fScript()
  local arg = { "LuaScript", _History:field("LuaScript") }
  return Utils.RunInternalScript("expression", arg)
end

local function fScriptParams()
  local arg = { "ScriptParams", _History:field("LuaScript") }
  return Utils.RunInternalScript("expression", arg)
end

local function fPluginConfig()
  local arg = { CurrentConfig }
  if Utils.RunInternalScript("config", arg) then
    OnConfigChange(CurrentConfig)
    return true
  end
end

local EditorMenuItems = {
  { text = "::MMenuSortLines",        action = fSort },
  { text = "::MMenuWrap",             action = fWrap },
  { text = "::MMenuBlockSum",         action = fBlockSum },
  { text = "::MMenuExpr",             action = fExpr },
  { text = "::MMenuScript",           action = fScript },
  { text = "::MMenuScriptParams",     action = fScriptParams },
}

local function RunExitScriptHandlers()
  for _,f in ipairs(_Plugin.Handlers.ExitScript) do f() end
end

local function fReloadUserFile()
  if not FirstRun then
    RunExitScriptHandlers()
    ResetPackageLoaded()
  end
  package.path = _Plugin.PackagePath -- restore to original value
  -----------------------------------------------------------------------------
  _Plugin.UserItems, _Plugin.CommandTable, _Plugin.HotKeyTable, _Plugin.Handlers =
    Utils.LoadUserMenu("_usermenu.lua")
end

local function traceback3(msg)
  return debug.traceback(msg, 3)
end

local function RunMenuItem (aItem, aArg, aRestoreConfig)
  local argCopy = {} -- prevent parasite connection between utilities
  for k,v in pairs(aArg) do argCopy[k]=v end
  local restoreConfig = aRestoreConfig and lf4ed.config()
  local function wrapfunc()
    if aItem.action then return aItem.action(argCopy) end
    return Utils.RunUserItem(aItem, argCopy)
  end
  local ok, result = xpcall(wrapfunc, traceback3)
  local result2 = CurrentConfig.ReturnToMainMenu
  if restoreConfig then lf4ed.config(restoreConfig) end
  if not ok then export.OnError(result) end
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
    local ok, result = RunMenuItem(item, aArg, false)
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

local function MakeMainMenu(aFrom)
  local properties = {
    Flags = {FMENU_WRAPMODE=1, FMENU_AUTOHIGHLIGHT=1}, Title = M.MPluginName,
    HelpTopic = "Contents", Bottom = "alt+sh+f9", }
  --------
  local items = {}
  if aFrom == "editor" then Utils.AddMenuItems(items, EditorMenuItems, M) end
  Utils.AddMenuItems(items, _Plugin.UserItems[aFrom], M)
  --------
  local keys = {{ BreakKey="AS+F9", action=Configure },}
  return properties, items, keys
end

local function export_Open (aFrom, aGuid, aItem) -- TODO

  if aFrom == F.OPEN_FROMMACRO then
    return Utils.OpenMacro(aItem, _Plugin.CommandTable, lf4ed.config)
  elseif aFrom == F.OPEN_COMMANDLINE then
    return Utils.OpenCommandLine(aItem, _Plugin.CommandTable, lf4ed.config)
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
    local ok, result, bRetToMainMenu = RunMenuItem(item, arg, item.action~=Configure)
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
  local state = Rec.ControlKeyState
  local ALT   = bor(F.LEFT_ALT_PRESSED, F.RIGHT_ALT_PRESSED)
  local CTRL  = bor(F.LEFT_CTRL_PRESSED, F.RIGHT_CTRL_PRESSED)
  local SHIFT = F.SHIFT_PRESSED

  if 0 ~= band(state, ALT) then f = bor(f, 0x01) end
  if 0 ~= band(state, CTRL) then f = bor(f, 0x02) end
  if 0 ~= band(state, SHIFT) then f = bor(f, 0x04) end
  f = f .. "+" .. VK[Rec.VirtualKeyCode%256]
  return f
end

local function export_ProcessEditorInput (Rec)
  local EventType = Rec.EventType
  if EventType == F.KEY_EVENT then
    local item = _Plugin.HotKeyTable[KeyComb(Rec)]
    if item then
      if Rec.KeyDown then
        if type(item)=="number" then item = EditorMenuItems[item] end
        if item then RunMenuItem(item, {From="editor"}, item.action~=Configure) end
      end
      return true
    end
  end
  for _,f in ipairs(_Plugin.Handlers.EditorInput) do
    if f(Rec) then return true end
  end
end

local function export_ProcessEditorEvent (EditorId, Event, Param)
  for _,f in ipairs(_Plugin.Handlers.EditorEvent) do
    f(EditorId, Event, Param)
  end
end

local function export_ProcessViewerEvent (ViewerId, Event, Param)
  for _,f in ipairs(_Plugin.Handlers.ViewerEvent) do
    f(ViewerId, Event, Param)
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
  CurrentConfig = _History:field("PluginSettings")
  setmetatable(CurrentConfig, { __index=DefaultConfig })
  OnConfigChange(CurrentConfig)
end

do
  InitUpvalues(_Plugin)
  SetExportFunctions()
  if FirstRun then
    fReloadUserFile()
    FirstRun = false -- needed when (ReloadDefaultScript == false)
  end
end
