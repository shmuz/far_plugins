-- lfsearch.lua
-- luacheck: globals lfsearch _Plugin _finder

-- Minimal required Far Manager build changed from 4425 to 4878 after some testing.
-- The reason: FSF.GetReparsePointInfo() did not work in the range of builds [4425-4876].

local F = far.Flags
local M -- forward declaration
local History = _Plugin and _Plugin.History -- forward declaration
local HField = _Plugin and _Plugin.HField -- forward declaration
local MenuFlags = bit64.bor(F.FMENU_WRAPMODE, F.FMENU_AUTOHIGHLIGHT)
local PluginConfigGuid1 = win.Uuid("B2C08615-ED7C-491D-BE5C-8758FDAB9139")
local PluginMenuGuid1   = win.Uuid("3D5E7985-3B5D-4777-A572-BA7C621B3731")
_G.lfsearch = {}

local SETTINGS_KEY = "plugin"
local SETTINGS_NAME = "settings"
local Sett = require "far2.settings"


local function GetFarBuildNumber()
  return ( select(4, far.AdvControl("ACTL_GETFARMANAGERVERSION",true)) )
end


local function LoadSettings()
  local data = Sett.mload(SETTINGS_KEY, SETTINGS_NAME, "roaming")
  if not data then
    -- try to load old settings (saved when far2.history library was used)
    local obj = far.CreateSettings(nil, "PSL_ROAMING")
    if obj then
      local strData = obj:Get(0, "alldata", "FST_DATA")
      obj:Free()
      if strData then
        data = Sett.deserialize(strData.."\nreturn Data\n")
      end
    end
  end
  return data
end


local function SaveSettings()
  Sett.msave(SETTINGS_KEY, SETTINGS_NAME, History, "roaming")
end


-- Set the defaults: prioritize safety and "least surprise".
local function NormDataOnFirstRun()
  local main = HField("main")
  local pers = HField("persistent")
  local SetVal = function(name, dflt)
    if main[name]==nil or not pers[name] then main[name]=dflt; end
  end
  SetVal("bAdvanced"          , false)
  SetVal("bConfirmReplace"    , true)
  SetVal("bDelEmptyLine"      , false)
  SetVal("bDelNonMatchLine"   , false)
  SetVal("bGrepInverseSearch" , false)
  SetVal("bInverseSearch"     , false)
  SetVal("bMultiPatterns"     , false)
  SetVal("bRepIsFunc"         , false)
  SetVal("bSearchBack"        , false)
  SetVal("bUseDirFilter"      , false)
  SetVal("bUseFileFilter"     , false)
  SetVal("sSearchArea"        , "FromCurrFolder")
end


local function PersistentDialog()
  local sd = require "far2.simpledialog"
  local items = {
      width = 0;
      guid="325E21EA-0E78-4FF8-A800-8710896CE606";
      help="PersistentSettings";
    {tp="dbox";  text=M.MDlgPersistentSettings; },
    {tp="chbox"; name="bAdvanced"         ; text=M.MDlgAdvanced          ; },
    {tp="chbox"; name="bConfirmReplace"   ; text=M.MDlgConfirmReplace    ; },
    {tp="chbox"; name="bDelEmptyLine"     ; text=M.MDlgDelEmptyLine      ; },
    {tp="chbox"; name="bDelNonMatchLine"  ; text=M.MDlgDelNonMatchLine   ; },
    {tp="chbox"; name="bGrepInverseSearch"; text=M.MDlgGrepInverseSearch ; },
    {tp="chbox"; name="bInverseSearch"    ; text=M.MDlgInverseSearch     ; },
    {tp="chbox"; name="bMultiPatterns"    ; text=M.MDlgMultiPatterns     ; },
    {tp="chbox"; name="bRepIsFunc"        ; text=M.MDlgRepIsFunc         ; },
    {tp="chbox"; name="bSearchBack"       ; text=M.MDlgReverseSearch     ; },
    {tp="chbox"; name="bUseDirFilter"     ; text=M.MDlgUseDirFilter      ; },
    {tp="chbox"; name="bUseFileFilter"    ; text=M.MDlgUseFileFilter     ; },
    {tp="chbox"; name="sSearchArea"       ; text=M.MDlgSearchArea        ; },
    {tp="sep"; },
    {tp="butt"; default=1; centergroup=1; text=M.MOk;     },
    {tp="butt"; cancel=1;  centergroup=1; text=M.MCancel; },
  }
  for _,v in ipairs(items) do
    if v.text and v.name then
      v.text=v.text:gsub("&",""):gsub(":$","")
      v.text = ("%-30s(%s)"):format(v.text, v.name)
    end
  end

  local pers = HField("persistent")
  local dlg = sd.New(items)
  dlg:LoadData(pers)
  local out = dlg:Run()
  if out then
    dlg:SaveData(out, pers)
    SaveSettings()
  end
end


local function FirstRunActions()
  History = LoadSettings() or {}
  HField = function(key) return Sett.field(History, key) end
  NormDataOnFirstRun()

  _Plugin = {
    DialogHistoryPath = "LuaFAR Search\\";
    FileList          = nil;
    Finder            = _finder;
    HField            = HField;
    History           = History;
    OriginalRequire   = require;
    Repeat            = {};
    SaveSettings      = SaveSettings;
  }

  if GetFarBuildNumber() >= 5550 then
    -- far.FileTimeResolution()     requires LuaFAR build >= 704 (Far build 5465)
    -- _finder.FileTimeResolution() requires LuaFAR build >= 725 (Far build 5550)
    far.FileTimeResolution(2) -- set 100ns file resolution
    _finder.FileTimeResolution(2)
  end

  local ModuleDir = far.PluginStartupInfo().ModuleDir
  package.path = ModuleDir .. "?.lua;" .. package.path
  package.cpath = ModuleDir .. "?.dl;" .. package.cpath
end


local FirstRun = ... --> this works with LuaFAR builds >= 529 (Far >= 3.0.4425)
if FirstRun then FirstRunActions() end


local libUtils   = require "far2.utils"
local Common     = require "lfs_common"
local EditMain   = require "lfs_editmain"
local Editors    = require "lfs_editors"
M                = require "lfs_message"
local MReplace   = require "lfs_mreplace"
local Panels     = require "lfs_panels" -- call only after modifying package.cpath
local Rename     = require "lfs_rename"


local function ForcedRequire (name)
  package.loaded[name] = nil
  return _Plugin.OriginalRequire(name)
end


local function OpenFromEditor (userItems)
  local hMenu = HField("editor.menu")
  local items = {
    { text=M.MMenuFind,             action="search",         save=true  },
    { text=M.MMenuReplace,          action="replace",        save=true  },
    { text=M.MMenuRepeat,           action="repeat",         save=false },
    { text=M.MMenuRepeatRev,        action="repeat_rev",     save=false },
    { text=M.MMenuFindWord,         action="searchword",     save=false },
    { text=M.MMenuFindWordRev,      action="searchword_rev", save=false },
    { text=M.MMenuMultilineReplace, action="mreplace",       save=true  },
    { text=M.MMenuToggleHighlight,  action="togglehighlight",save=false },
    { text=M.MMenuConfig,           action="config",         save=true  },
  }
  for k,v in ipairs(items) do v.text=k..". "..v.text end

  local nOwnItems = #items
  libUtils.AddMenuItems(items, userItems, M)
  local item, pos = far.Menu(
    { Title=M.MMenuTitle, HelpTopic="EditorMenu", SelectIndex=hMenu.position, Flags=MenuFlags}, items)
  if not item then return end
  hMenu.position = pos

  if pos <= nOwnItems then
    local data = HField("main")
    data.fUserChoiceFunc = nil
    local ret

    if item.action == "togglehighlight" then
      Editors.ToggleHighlight()
    elseif item.action == "mreplace" then
      ret = MReplace.ReplaceWithDialog(data, true)
    else
      ret = EditMain.EditorAction(item.action, data, false)
    end

    if ret and item.save then
      SaveSettings() -- very expensive with SQLite (~ 0.1 sec)
    end
  else
    libUtils.RunUserItem(item, item.arg)
    SaveSettings()
  end
end


local function GUI_SearchFromPanels (data)
  local tFileList, bCancel = Panels.SearchFromPanel(data, true, false)
  if tFileList then -- the dialog was not cancelled
    if tFileList[1] then
      local panel = Panels.CreateTmpPanel(tFileList, HField("tmppanel"))
      SaveSettings()
      return panel
    else -- no files were found
      if bCancel or 1==far.Message(M.MNoFilesFound,M.MMenuTitle,M.MButtonsNewSearch) then
        return GUI_SearchFromPanels(data)
      end
      SaveSettings()
    end
  end
end


local function OpenFromPanels (userItems)
  local hMain = HField("main")
  local hMenu = HField("panels.menu")

  local items = {
    {text=M.MMenuFind,     action="find"},
    {text=M.MMenuReplace,  action="replace"},
    {text=M.MMenuGrep,     action="grep"},
    {text=M.MMenuRename,   action="rename"},
    {text=M.MMenuTmpPanel, action="tmppanel"},
  }
  for k,v in ipairs(items) do v.text=k..". "..v.text end

  local nOwnItems = #items
  libUtils.AddMenuItems(items, userItems, M)
  local item, pos = far.Menu(
    { Title=M.MMenuTitle, HelpTopic="OperInPanels", SelectIndex=hMenu.position, Flags=MenuFlags }, items)
  if not item then return end
  hMenu.position = pos

  if pos <= nOwnItems then
    if item.action == "find" then
      return GUI_SearchFromPanels(hMain)
    elseif item.action == "replace" then
      Panels.ReplaceFromPanel(hMain, true, false)
    elseif item.action == "grep" then
      Panels.GrepFromPanel(hMain, true, false)
    elseif item.action == "rename" then
      Rename.main()
    elseif item.action == "tmppanel" then
      return Panels.CreateTmpPanel(_Plugin.FileList or {}, HField("tmppanel"))
    end
  else
    libUtils.RunUserItem(item, item.arg)
  end
end


local function OpenFromMacro (aItem, commandTable)
  local Op, Where, Cmd = unpack(aItem)

  if Op=="code" or Op=="file" or Op=="command" then
    return libUtils.OpenMacro(aItem, commandTable, nil)

  elseif Op=="own" then
    local area = far.MacroGetArea()
    local data = HField("main")
    data.fUserChoiceFunc = nil

    if Where=="editor" then
      if area == F.MACROAREA_EDITOR then
        if Cmd=="search" or Cmd=="replace" or Cmd=="repeat" or Cmd=="repeat_rev" or
          Cmd=="searchword" or Cmd=="searchword_rev" or Cmd=="config"
        then
          local ret = EditMain.EditorAction(Cmd, data, false)
          if ret and (Cmd=="search" or Cmd=="replace" or Cmd=="config") then
            SaveSettings() -- very expensive with SQLite (~ 0.1 sec)
          end
          return ret
        elseif Cmd=="mreplace" then
          if MReplace.ReplaceWithDialog(data, true) then
            SaveSettings() -- very expensive with SQLite (~ 0.1 sec)
          end
        elseif Cmd=="resethighlight" then
          Editors.ActivateHighlight(false)
        elseif Cmd=="togglehighlight" then
          Editors.ToggleHighlight()
        end
      end

    elseif Where=="panels" then
      if area==F.MACROAREA_SHELL or area==F.MACROAREA_TREEPANEL or
         area==F.MACROAREA_QVIEWPANEL or area==F.MACROAREA_INFOPANEL
      then
        if Cmd == "search" then
          local pan = GUI_SearchFromPanels(data)
          return pan and { pan, type="panel" }
        elseif Cmd == "replace" then
          Panels.ReplaceFromPanel(data, true, false)
        elseif Cmd == "grep" then
          Panels.GrepFromPanel(data, true, false)
        elseif Cmd == "rename" then
          Rename.main()
        elseif Cmd == "panel" then
          local pan = Panels.CreateTmpPanel(_Plugin.FileList or {}, HField("tmppanel"))
          return { [1]=pan; type="panel" }
        end
      end
    end

  end
  return false
end


local function OpenFromShortcut()
  return Panels.CreateTmpPanel(_Plugin.FileList or {}, HField("tmppanel"))
end


export.OnError = libUtils.OnError
export.ProcessEditorEvent = Editors.ProcessEditorEvent


function export.Open (aFrom, aGuid, aItem) -- luacheck: no unused args (aGuid)
  local userItems, commandTable = libUtils.LoadUserMenu("_usermenu.lua")
  if     aFrom == F.OPEN_PLUGINSMENU then return OpenFromPanels(userItems.panels)
  elseif aFrom == F.OPEN_EDITOR      then OpenFromEditor(userItems.editor)
  elseif aFrom == F.OPEN_COMMANDLINE then return libUtils.OpenCommandLine(aItem, commandTable, nil)
  elseif aFrom == F.OPEN_FROMMACRO   then return OpenFromMacro(aItem, commandTable)
  elseif aFrom == F.OPEN_SHORTCUT    then return OpenFromShortcut()
  end
end


function export.GetPluginInfo()
  return {
    CommandPrefix = "lfs",
    Flags = F.PF_EDITOR,
    PluginMenuGuids = PluginMenuGuid1,
    PluginMenuStrings = { M.MMenuTitle },
    PluginConfigGuids = PluginConfigGuid1,
    PluginConfigStrings = { M.MMenuTitle },
  }
end


function export.Configure (Guid) -- luacheck: no unused args
  local properties = {
    Flags = MenuFlags,
    Title = M.MConfigMenuTitle,
    HelpTopic = "Contents",
  }
  local items = {
    { text=M.MConfigTitleEditor;     action=Common.EditorConfigDialog; },
    { text=M.MConfigTitleTmpPanel;   action=Panels.ConfigDialog;       },
    { text=M.MConfigTitleCommon;     action=Common.ConfigDialog;       },
    { text=M.MDlgPersistentSettings; action=PersistentDialog;          },
  }
  local userItems = libUtils.LoadUserMenu("_usermenu.lua")
  libUtils.AddMenuItems(items, userItems.config, M)
  while true do
    local item, pos = far.Menu(properties, items)
    if not item then break end
    if pos <= #items then
      item.action()
    else
      libUtils.RunUserItem(item, item.arg)
    end
    properties.SelectIndex = pos
  end
end


lfsearch.MReplaceEditorAction = MReplace.EditorAction
lfsearch.MReplaceDialog = MReplace.ReplaceWithDialog


-- Note: not intended to process tables containing cyclic references
local function MergeTables(trg, src)
  for k,v in pairs(src) do
    if type(v)=="table" and type(trg[k])=="table" then
      MergeTables(trg[k], v) -- recursion
    else
      trg[k] = v
    end
  end
end


function lfsearch.EditorAction (aOp, aData, aSaveData)
  assert(type(aOp)=="string", "arg #1: string expected")
  assert(type(aData)=="table", "arg #2: table expected")
  local newdata = {}; for k,v in pairs(aData) do newdata[k] = v end
  local nFound, nReps = EditMain.EditorAction(aOp, newdata, true)
  if aSaveData and nFound then
    MergeTables(History["main"], newdata)
  end
  return nFound, nReps
end


function lfsearch.SetDebugMode (On)
  if On then
    require = ForcedRequire -- luacheck: allow defined (require)
    far.ReloadDefaultScript = true
  else
    require = _Plugin.OriginalRequire
    far.ReloadDefaultScript = false
  end
end


function lfsearch.SearchFromPanel (data, bWithDialog)
  return Panels.SearchFromPanel(data, bWithDialog, true)
end


function lfsearch.ReplaceFromPanel (data, bWithDialog)
  return Panels.ReplaceFromPanel(data, bWithDialog, true)
end


do
  local config = HField("config")
  config.bUseFarHistory = config.bUseFarHistory~=false -- true by default
  config.EditorHighlightColor    = config.EditorHighlightColor    or 0xCF
  config.GrepLineNumMatchColor   = config.GrepLineNumMatchColor   or 0xA0
  config.GrepLineNumContextColor = config.GrepLineNumContextColor or 0x80
  Panels.InitTmpPanel()
end
