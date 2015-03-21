--------------------
-- lf_history.lua --
--------------------
local Utils      = require "far2.utils"
local LibHistory = require "far2.history"
package.loaded["far2.custommenu"] = nil
local custommenu = require "far2.custommenu"

local FirstRun = not _Plugin
if FirstRun then
  _Plugin = Utils.InitPlugin()
  _Plugin.History = LibHistory.newsettings(nil, "config")
  package.path = far.PluginStartupInfo().ModuleDir .. "?.lua;" .. package.path
end

local M = require "lfh_message"
local F = far.Flags
local band, bor, bxor, bnot = bit64.band, bit64.bor, bit64.bxor, bit64.bnot
local FarId = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"

local cfgView = {
  PluginHistoryType = "view",
  --FarHistoryType = F.FSSF_HISTORY_VIEW,
  title = "mTitleView",
  brkeys = {
    "F3", "F4",
    "CtrlEnter", "CtrlNumEnter", "RCtrlEnter", "RCtrlNumEnter",
    "ShiftEnter", "ShiftNumEnter",
    "CtrlPgUp", "RCtrlPgUp",
  },
  maxItemsKey = "iSizeView",
}

local cfgCommands = {
  PluginHistoryType = "commands",
  FarHistoryType = F.FSSF_HISTORY_CMD,
  title = "mTitleCommands",
  brkeys = {
    "CtrlEnter", "RCtrlEnter", "CtrlNumEnter", "RCtrlNumEnter",
    "ShiftEnter", "ShiftNumEnter",
  },
  maxItemsKey = "iSizeCmd",
}

local cfgFolders = {
  PluginHistoryType  = "folders",
  FarHistoryType = F.FSSF_HISTORY_FOLDER,
  title = "mTitleFolders",
  brkeys = {
    "CtrlEnter", "RCtrlEnter", "CtrlNumEnter", "RCtrlNumEnter",
    "ShiftEnter", "ShiftNumEnter",
  },
  maxItemsKey = "iSizeFold",
}

local cfgLocateFile = {
  PluginHistoryType  = "locatefile",
  title = "mTitleLocateFile",
  brkeys = {
    "F3", "F4",
    "CtrlEnter", "RCtrlEnter", "CtrlNumEnter", "RCtrlNumEnter",
  },
  bDynResize = true,
}

local function IsCtrlEnter (key)
  return key=="CtrlEnter" or key=="RCtrlEnter" or key=="CtrlNumEnter" or key=="RCtrlNumEnter"
end

local function IsCtrlPgUp (key)
  return key=="CtrlPgUp" or key=="RCtrlPgUp"
end

local function ExecuteFromCmdLine(str, newwindow)
  panel.SetCmdLine(nil, str)
  far.MacroPost(newwindow and 'Keys"ShiftEnter"' or 'Keys"Enter"')
end

local DefaultCfg = {
  bDynResize  = true,
  bAutoCenter = true,
  iSizeCmd    = 1000,
  iSizeView   = 1000,
  iSizeFold   = 1000,
}

local function GetTimeString (filetime)
  local ft = win.FileTimeToLocalFileTime(filetime)
  ft = ft and win.FileTimeToSystemTime(ft)
  if ft then
    return ("%04d-%02d-%02d %02d:%02d:%02d"):format(
      ft.wYear,ft.wMonth,ft.wDay,ft.wHour,ft.wMinute,ft.wSecond)
  end
end

local function TellFileNotExist (fname)
  far.Message(('%s:\n"%s"'):format(M.mFileNotExist, fname), M.mError, M.mOk, "w")
end

local function TellFileIsDirectory (fname)
  far.Message(('%s:\n"%s"'):format(M.mFileIsDirectory, fname), M.mError, M.mOk, "w")
end

local function SetListKeyFunction (list, HistTypeConfig, HistObject)
  function list:keyfunction (hDlg, key, Item)
    if key == "F8" then
      list.xlat = not list.xlat
      list:ChangePattern(hDlg, list.pattern)
      return "done"
    end

    if key == "F9" then
      local s = HistObject:getfield("lastpattern")
      if s and s ~= "" then list:ChangePattern(hDlg,s) end
      return "done"
    end

    if key == "F7" then
      if HistTypeConfig ~= cfgLocateFile then
        if Item then
          local timestring = GetTimeString(Item.time)
          if timestring then
            far.Message(Item.text, timestring, ";Ok")
          end
        end
      end
      return "done"
    end

    if key=="CtrlDel" or key=="RCtrlDel" or key=="CtrlNumDel" or key=="RCtrlNumDel" then
      if HistTypeConfig ~= cfgLocateFile then
        if Item then
          if far.Message((M.mDeleteItemsQuery):format(#self.drawitems),
                          M.mDeleteItemsTitle, ";YesNo", "w") == 1 then
            self:DeleteFilteredItems (hDlg, false)
          end
        end
      end
      return "done"
    end

    if HistTypeConfig==cfgView or HistTypeConfig==cfgLocateFile then
      if key=="F3" or key=="F4" or key=="AltF3" or key=="AltF4" then
        local fname = HistTypeConfig==cfgView and Item.Text or Item.text:sub(2)
        local attr = win.GetFileAttr(fname)
        if not attr then
          TellFileNotExist(fname)
          return "done"
        elseif attr:find("d") then
          TellFileIsDirectory(fname)
          return "done"
        elseif key == "AltF3" then
          viewer.Viewer(fname)
          far.AdvControl("ACTL_REDRAWALL")
          return "done"
        elseif key == "AltF4" then
          editor.Editor(fname)
          far.AdvControl("ACTL_REDRAWALL")
          return "done"
        end
      end
    end

    if HistTypeConfig==cfgView then
      if key=="Enter" or key=="NumEnter" or key=="ShiftEnter" or key=="ShiftNumEnter" then
        local attr = win.GetFileAttr(Item.text)
        if not attr then
          TellFileNotExist(Item.text)
          return "done"
        elseif attr:find("d") then
          TellFileIsDirectory(Item.text)
          return "done"
        end
      end
    end

    for _,v in ipairs(HistTypeConfig.brkeys) do
      if key == v then return "break" end
    end
  end
end

local function SetCanCloseFunction (list, HistTypeConfig)
  function list:CanClose (item, breakkey)
    if HistTypeConfig == cfgFolders then
      if item then
        if IsCtrlEnter(breakkey) then
          panel.SetCmdLine(nil, item.text)
        else
          if not panel.SetPanelDirectory(nil, breakkey==nil and 1 or 0, item.text) then
            far.Message(item.text, M.mPathNotFound, nil, "w")
            return false
          end
        end
      end
    end
    return true
  end
end

local function MakeMenuParams (aCommonConfig, aHistTypeConfig, aHistTypeData, aItems, aHistObject)
  local menuProps = {
    DialogId      = win.Uuid("d853e243-6b82-4b84-96cd-e733d77eeaa1"),
    Flags         = {FMENU_WRAPMODE=1},
    HelpTopic     = "Contents",
    Title         = M[aHistTypeConfig.title],
    SelectIndex   = #aItems,
  }
  local listProps = {
    autocenter    = aCommonConfig.bAutoCenter,
    resizeW       = aHistTypeConfig.bDynResize or aCommonConfig.bDynResize,
    resizeH       = aHistTypeConfig.bDynResize or aCommonConfig.bDynResize,
    resizeScreen  = true,
    col_highlight = 0x3A,
    col_selectedhighlight = 0x0A,
    selalign      = "bottom",
    selignore     = true,
    searchmethod  = aHistTypeData.searchmethod or "dos",
    filterlines   = true,
    xlat          = aHistTypeData.xlat,
  }
  local list = custommenu.NewList(listProps, aItems)
  SetListKeyFunction(list, aHistTypeConfig, aHistObject)
  SetCanCloseFunction(list, aHistTypeConfig)
  return menuProps, list
end

local function GetMaxItems (aConfig)
  return _Plugin.Cfg[aConfig.maxItemsKey]
end

local function DelayedSaveHistory (hist, delay)
  far.Timer(delay, function(h) h:Close(); hist:save(); end)
end

local function get_history (aConfig)
  local menu_items, map = {}, {}

  -- add plugin database items
  local hst = LibHistory.newsettings(nil, aConfig.PluginHistoryType)
  local plugin_items = hst:field("items")
  local settings = hst:field("settings")
  for _,v in ipairs(plugin_items) do
    if v.text then
      if not map[v.text] then
        table.insert(menu_items, v)
        map[v.text] = v
      end
    end
  end

  -- add Far database items
  local last_time = settings.last_time or 0
  local far_settings = assert(far.CreateSettings("far"))

  local function AddFarItems (aFarHistoryType, aType)
    local far_items = far_settings:Enum(aFarHistoryType)
    for _,v in ipairs(far_items) do
      if v.PluginId == FarId then -- filter out archive plugins' items
        local item = map[v.Name]
        if item then
          if v.Time > item.time then
            item.time = v.Time
            item.typ = aType
          end
        elseif v.Time >= last_time then -- add only new items
          item = { text=v.Name, time=v.Time, typ=aType }
          table.insert(menu_items, item)
          map[v.Name] = item
        end
      end
    end
  end
  settings.last_time = win.GetSystemTimeAsFileTime()

  if aConfig == cfgView then
    AddFarItems(F.FSSF_HISTORY_VIEW, "V")
    AddFarItems(F.FSSF_HISTORY_EDIT, "E")
    ---AddFarItems(F.FSSF_HISTORY_EXTERNAL)
  else
    AddFarItems(aConfig.FarHistoryType)
  end
  far_settings:Free()

  -- sort menu items: oldest records go first
  table.sort(menu_items, function(a,b) return a.time < b.time end)

  -- remove excessive items; leave checked items;
  local i = 1
  local maxitems = GetMaxItems(aConfig)
  while (#menu_items >= i) and (#menu_items > maxitems) do
    if menu_items[i].checked then i = i+1 -- leave the item
    else table.remove(menu_items, i)      -- remove the item
    end
  end

  -- execute the menu
  local menuProps, list = MakeMenuParams(_Plugin.Cfg, aConfig, settings, menu_items, hst)
  local item, itempos = custommenu.Menu(menuProps, list)
  settings.searchmethod = list.searchmethod
  settings.xlat = list.xlat
  hst:setfield("items", list.items)
  if item and list.pattern ~= "" then
    hst:setfield("lastpattern", list.pattern)
  end
  DelayedSaveHistory(hst, 200)
  if item then
    return menu_items[itempos], item.BreakKey
  end
end

local function commands_history()
  local item, key = get_history(cfgCommands)
  if item then
    if IsCtrlEnter(key) then
      panel.SetCmdLine(nil, item.text)
    else
      ExecuteFromCmdLine(item.text, key ~= nil)
    end
  end
end

local function folders_history()
  get_history(cfgFolders)
end

local function LocateFile (fname)
  local attr = win.GetFileAttr(fname)
  if attr and not attr:find"d" then
    local dir, name = fname:match("^(.*\\)([^\\]*)$")
    if panel.SetPanelDirectory(nil, 1, dir) then
      local pinfo = panel.GetPanelInfo(nil, 1)
      for i=1, pinfo.ItemsNumber do
        local item = panel.GetPanelItem(nil, 1, i)
        if item.FileName == name then
          local rect = pinfo.PanelRect
          local hheight = math.floor((rect.bottom - rect.top - 4) / 2)
          local topitem = pinfo.TopPanelItem
          panel.RedrawPanel(nil, 1, { CurrentItem = i,
            TopPanelItem = i>=topitem and i<topitem+hheight and topitem or
                           i>hheight and i-hheight or 0 })
          return true
        end
      end
    end
  end
  return false
end

local function CallViewer (fname, disablehistory)
  local flags = {VF_NONMODAL=1, VF_IMMEDIATERETURN=1, VF_ENABLE_F6=1, VF_DISABLEHISTORY=disablehistory}
  viewer.Viewer(fname, nil, nil, nil, nil, nil, flags)
end

local function CallEditor (fname, disablehistory)
  local flags = {EF_NONMODAL=1, EF_IMMEDIATERETURN=1, EF_ENABLE_F6=1, EF_DISABLEHISTORY=disablehistory}
  editor.Editor(fname, nil, nil, nil, nil, nil, flags)
end

local function view_history()
  local item, key = get_history(cfgView)
  if not item then return end
  local fname = item.text

  local shift_enter = (key=="ShiftEnter" or key=="ShiftNumEnter")

  if IsCtrlEnter(key) then
    panel.SetCmdLine(nil, fname)

  elseif IsCtrlPgUp(key) then
    if not LocateFile(fname) then TellFileNotExist(fname) end

  elseif key == nil or shift_enter then
    if item.typ == "V" then CallViewer(fname, shift_enter)
    else CallEditor(fname, shift_enter)
    end

  elseif key == "F3" then CallViewer(fname, false)
  elseif key == "F4" then CallEditor(fname, false)
  end
end

local function LocateFile2()
  local info = panel.GetPanelInfo(nil,1)
  if not info then return end

  local items = {}
  for k=1,info.ItemsNumber do
    local v = panel.GetPanelItem(nil,1,k)
    local prefix = v.FileAttributes:find("d") and "/" or " "
    items[k] = {text=prefix..v.FileName}
  end

  local hst = LibHistory.newsettings(nil, cfgLocateFile.PluginHistoryType)
  local settings = hst:field("settings")

  local menuProps, list = MakeMenuParams(_Plugin.Cfg, cfgLocateFile, settings, items, hst)
  list.searchstart = 2

  local item, itempos = custommenu.Menu(menuProps, list)
  settings.searchmethod = list.searchmethod
  settings.xlat = list.xlat
  if item and list.pattern ~= "" then
    hst:setfield("lastpattern", list.pattern)
  end
  DelayedSaveHistory(hst, 200)

  if item then
    if item.BreakKey then
      local data = items[itempos].text:sub(2)
      if IsCtrlEnter(item.BreakKey) then panel.SetCmdLine(nil, data)
      elseif item.BreakKey == "F3" then CallViewer(data)
      elseif item.BreakKey == "F4" then CallEditor(data)
      end
    else
      panel.RedrawPanel(nil,1,{CurrentItem=itempos})
    end
  end
end

local PluginMenuGuid1   = win.Uuid("181fa8c3-fd3f-44a8-9c16-e3ca753c4ccb")
local PluginConfigGuid1 = win.Uuid("688f9ee4-d0ac-49d0-b66b-8dbaa989f22c")

local function export_GetPluginInfo()
  return {
    CommandPrefix = "lfh",
    Flags = bor(F.PF_EDITOR, F.PF_VIEWER),
    PluginConfigGuids   = PluginConfigGuid1.."",
    PluginConfigStrings = { M.mPluginTitle },
    PluginMenuGuids   = PluginMenuGuid1.."",
    PluginMenuStrings = { M.mPluginTitle },
  }
end

local function export_Configure()
  if Utils.RunInternalScript("config", _Plugin.Cfg) then
    _Plugin.History:save()
  end
end

local function export_Open (From, Guid, Item)
  local userItems, commandTable, hotKeyTable = Utils.LoadUserMenu("_usermenu.lua")
  ------------------------------------------------------------------------------
  if From == F.OPEN_FROMMACRO then
    return Utils.OpenMacro(Item, commandTable, nil)
  elseif From == F.OPEN_COMMANDLINE then
    return Utils.OpenCommandLine(Item, commandTable, nil)
  end
  ------------------------------------------------------------------------------
  if From==F.OPEN_PLUGINSMENU or From==F.OPEN_EDITOR or From==F.OPEN_VIEWER then
    ---------------------------------------------------------------------------
    local properties = {
      Title=M.mPluginTitle, HelpTopic="Contents", Flags="FMENU_WRAPMODE",
    }
    local items = {
      { disable = (From ~= F.OPEN_PLUGINSMENU),
        text=M.mMenuCommands,   action=commands_history },
      { text=M.mMenuView,       action=view_history     },
      { text=M.mMenuFolders,    action=folders_history  },
      { text=M.mMenuConfig,     action=export_Configure },
      { text=M.mMenuLocateFile, action=LocateFile2      },
    }
    Utils.AddMenuItems(items,
      From==F.OPEN_PLUGINSMENU and userItems.panels or
      From==F.OPEN_EDITOR and userItems.editor or
      From==F.OPEN_VIEWER and userItems.viewer, M)
    ---------------------------------------------------------------------------
    local item = far.Menu(properties, items)
    if item then
      if item.action then item.action()
      else Utils.RunUserItem(item, item.arg)
      end
    end
  end
end

local function SetExportFunctions()
  export.Configure     = export_Configure
  export.GetPluginInfo = export_GetPluginInfo
  export.Open          = export_Open
end

do
  if FirstRun then
    _Plugin.Cfg = _Plugin.History:field("config")
    setmetatable(_Plugin.Cfg, {__index = DefaultCfg})
  end
  SetExportFunctions()
  far.ReloadDefaultScript = true
end
