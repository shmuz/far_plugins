-- lfsearch.lua
-- luacheck: globals _Plugin lfsearch

local FirstRun = ... --> this works with Far >= 3.0.4425

local libUtils   = require "far2.utils"
local libHistory = require "far2.history"

-- Set the defaults: prioritize safety and "least surprise".
local function NormDataOnFirstRun (data)
  data.bAdvanced          = false
  data.bConfirmReplace    = true
  data.bDelEmptyLine      = false
  data.bDelNonMatchLine   = false
  data.bGrepInverseSearch = false
  data.bInverseSearch     = false
  data.bMultiPatterns     = false
  data.bRepIsFunc         = false
  data.bSearchBack        = false
  data.bUseDirFilter      = false
  data.bUseFileFilter     = false
end

if FirstRun then
  _Plugin = {
    DialogHistoryPath = "LuaFAR Search\\",
    OriginalRequire = require,
    History = libHistory.newsettings(nil, "alldata"),
    Repeat = {},
    FileList = nil,
  }
  NormDataOnFirstRun(_Plugin.History:field("main"))
  libUtils.AddCfindFunction()
  export.OnError = libUtils.OnError
  local ModuleDir = far.PluginStartupInfo().ModuleDir
  package.path = ModuleDir .. "?.lua;" .. package.path
  package.cpath = ModuleDir .. "?.dl;" .. package.cpath
end

-- Run internal scripts: do not change the order.
local Libs = {}
Libs.GetMsg     = libUtils.RunInternalScript("lfs_message")
Libs.RepLib     = libUtils.RunInternalScript("lfs_replib", Libs)
Libs.Common     = libUtils.RunInternalScript("lfs_common", Libs)
Libs.EditEngine = libUtils.RunInternalScript("lfs_editengine", Libs)
Libs.EditMain   = libUtils.RunInternalScript("lfs_editmain", Libs)
Libs.MReplace   = libUtils.RunInternalScript("lfs_mreplace", Libs)
Libs.Rename     = libUtils.RunInternalScript("lfs_rename", Libs)
Libs.Panels     = libUtils.RunInternalScript("lfs_panels", Libs) -- call only after modifying package.cpath

local M = Libs.GetMsg
local F = far.Flags
local History = _Plugin.History
local MenuFlags = bit64.bor(F.FMENU_WRAPMODE, F.FMENU_AUTOHIGHLIGHT)
lfsearch = {}


local function ForcedRequire (name)
  package.loaded[name] = nil
  return _Plugin.OriginalRequire(name)
end


local function OpenFromEditor (userItems)
  local hMenu = History:field("editor.menu")
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
    local data = History:field("main")
    data.fUserChoiceFunc = nil
    local ret

    if item.action == "togglehighlight" then
      Libs.EditMain.ToggleHighlight()
    elseif item.action == "mreplace" then
      ret = Libs.MReplace.ReplaceWithDialog(data, true)
    else
      ret = Libs.EditMain.EditorAction(item.action, data, false)
    end

    if ret and item.save then
      History:save() -- very expensive with SQLite (~ 0.1 sec)
    end
  else
    libUtils.RunUserItem(item, item.arg)
    History:save()
  end
end


local function GUI_SearchFromPanels (data)
  local tFileList, bCancel = Libs.Panels.SearchFromPanel(data, true, false)
  if tFileList then -- the dialog was not cancelled
    if tFileList[1] then
      local panel = Libs.Panels.CreateTmpPanel(tFileList, History:field("tmppanel"))
      History:save()
      return panel
    else -- no files were found
      if bCancel or far.Message(M.MNoFilesFound,M.MMenuTitle,M.MButtonsNewSearch)==1 then
        return GUI_SearchFromPanels(data)
      end
      History:save()
    end
  end
end


local function OpenFromPanels (userItems)
  local hMain = History:field("main")
  local hMenu = History:field("panels.menu")

  local items = {
    {text=M.MMenuFind},
    {text=M.MMenuReplace},
    {text=M.MMenuGrep},
    {text=M.MMenuRename},
    {text=M.MMenuTmpPanel},
  }
  for k,v in ipairs(items) do v.text=k..". "..v.text end

  libUtils.AddMenuItems(items, userItems, M)
  local item, pos = far.Menu(
    { Title=M.MMenuTitle, HelpTopic="OperInPanels", SelectIndex=hMenu.position, Flags=MenuFlags }, items)
  if not item then return end
  hMenu.position = pos

  if pos == 1 then
    return GUI_SearchFromPanels(hMain)
  elseif pos == 2 then
    Libs.Panels.ReplaceFromPanel(hMain, true, false)
  elseif pos == 3 then
    Libs.Panels.GrepFromPanel(hMain, true, false)
  elseif pos == 4 then
    Libs.Rename.main()
  elseif pos == 5 then
    return Libs.Panels.CreateTmpPanel(_Plugin.FileList or {}, History:field("tmppanel"))
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
    local data = History:field("main")
    data.fUserChoiceFunc = nil

    if Where=="editor" then
      if area == F.MACROAREA_EDITOR then
        if Cmd=="search" or Cmd=="replace" or Cmd=="repeat" or Cmd=="repeat_rev" or
          Cmd=="searchword" or Cmd=="searchword_rev" or Cmd=="config"
        then
          local ret = Libs.EditMain.EditorAction(Cmd, data, false)
          if ret and (Cmd=="search" or Cmd=="replace" or Cmd=="config") then
            History:save() -- very expensive with SQLite (~ 0.1 sec)
          end
          return ret
        elseif Cmd=="mreplace" then
          if Libs.MReplace.ReplaceWithDialog(data, true) then
            History:save() -- very expensive with SQLite (~ 0.1 sec)
          end
        elseif Cmd=="resethighlight" then
          Libs.EditMain.ActivateHighlight(false)
        elseif Cmd=="togglehighlight" then
          Libs.EditMain.ToggleHighlight()
        end
      end

    elseif Where=="panels" then
      if area==F.MACROAREA_SHELL or area==F.MACROAREA_TREEPANEL or
         area==F.MACROAREA_QVIEWPANEL or area==F.MACROAREA_INFOPANEL
      then
        if Cmd=="search" then
          local panel = GUI_SearchFromPanels(data)
          return panel and { panel, type="panel" }
        elseif Cmd=="replace" then
          Libs.Panels.ReplaceFromPanel(data, true, false)
        elseif Cmd=="grep" then
          Libs.Panels.GrepFromPanel(data, true, false)
        elseif Cmd=="rename" then
          Libs.Rename.main()
        elseif Cmd=="panel" then
          local pan = Libs.Panels.CreateTmpPanel(_Plugin.FileList or {}, History:field("tmppanel"))
          return { [1]=pan; type="panel" }
        end
      end
    end

  end
  return false
end


function export.Open (aFrom, aGuid, aItem)
  local userItems, commandTable = libUtils.LoadUserMenu("_usermenu.lua")
  if     aFrom == F.OPEN_PLUGINSMENU then return OpenFromPanels(userItems.panels)
  elseif aFrom == F.OPEN_EDITOR      then OpenFromEditor(userItems.editor)
  elseif aFrom == F.OPEN_COMMANDLINE then return libUtils.OpenCommandLine(aItem, commandTable, nil)
  elseif aFrom == F.OPEN_FROMMACRO   then return OpenFromMacro(aItem, commandTable)
  end
end


local PluginMenuGuid1 = win.Uuid("3d5e7985-3b5d-4777-a572-ba7c621b3731")
local PluginConfigGuid1 = win.Uuid("b2c08615-ed7c-491d-be5c-8758fdab9139")
function export.GetPluginInfo()
  return {
    CommandPrefix = "lfs",
    Flags = F.PF_EDITOR,
    PluginMenuGuids = PluginMenuGuid1.."",
    PluginMenuStrings = { M.MMenuTitle },
    PluginConfigGuids = PluginConfigGuid1.."",
    PluginConfigStrings = { M.MMenuTitle },
  }
end


function lfsearch.EditorAction (aOp, aData, aSaveData)
  assert(type(aOp)=="string", "arg #1: string expected")
  assert(type(aData)=="table", "arg #2: table expected")
  local newdata = {}; for k,v in pairs(aData) do newdata[k] = v end
  local nFound, nReps = Libs.EditMain.EditorAction(aOp, newdata, true)
  if aSaveData and nFound then
    History:setfield("main", newdata)
  end
  return nFound, nReps
end


function lfsearch.SetDebugMode (On)
  if On then
    require = ForcedRequire
    far.ReloadDefaultScript = true
  else
    require = _Plugin.OriginalRequire
    far.ReloadDefaultScript = false
  end
end


function lfsearch.SearchFromPanel (data, bWithDialog)
  return Libs.Panels.SearchFromPanel(data, bWithDialog, true)
end


function lfsearch.ReplaceFromPanel (data, bWithDialog)
  return Libs.Panels.ReplaceFromPanel(data, bWithDialog, true)
end


lfsearch.MReplaceEditorAction = Libs.MReplace.EditorAction
lfsearch.MReplaceDialog = Libs.MReplace.ReplaceWithDialog


function export.Configure (Guid)
  local properties = {
    Flags = MenuFlags,
    Title = M.MConfigMenuTitle,
    HelpTopic = "Contents",
  }
  local items = {
    { text=M.MConfigTitleCommon },
    { text=M.MConfigTitleEditor },
    { text=M.MConfigTitleTmpPanel },
  }
  local userItems = libUtils.LoadUserMenu("_usermenu.lua")
  libUtils.AddMenuItems(items, userItems.config, M)
  while true do
    local item, pos = far.Menu(properties, items)
    if not item then break end
    if pos == 1 then
      Libs.Common.ConfigDialog()
    elseif pos == 2 then
      Libs.Common.EditorConfigDialog()
    elseif pos == 3 then
      Libs.Panels.ConfigDialog()
    else
      libUtils.RunUserItem(item, item.arg)
    end
    properties.SelectIndex = pos
  end
end


do
  local config = History:field("config")
  config.bUseFarHistory = config.bUseFarHistory~=false -- true by default
  config.EditorHighlightColor    = config.EditorHighlightColor    or 0xCF
  config.GrepLineNumMatchColor   = config.GrepLineNumMatchColor   or 0xA0
  config.GrepLineNumContextColor = config.GrepLineNumContextColor or 0x80
  Libs.Panels.InitTmpPanel()
end
