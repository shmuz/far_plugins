-- coding: UTF-8
-- luacheck: globals _Plugin

far.ReloadDefaultScript = true
package.loaded["far2.custommenu"] = nil

local custommenu = require "far2.custommenu"
local Utils      = require "far2.utils"
local LibHistory = require "far2.history"
local M          = Utils.RunInternalScript("lfh_message")
local F          = far.Flags
local FarId      = ("\0"):rep(16)
local PlugTitleCache = {}

local DefaultCfg = {
  bDynResize  = true,
  bAutoCenter = true,
  bDirectSort = true,
  iSizeCmd    = 1000,
  iSizeView   = 1000,
  iSizeFold   = 1000,
}

local cfgView = {
  PluginHistoryType = "view",
  --FarHistoryType = F.FSSF_HISTORY_VIEW,
  title = "mTitleView",
  brkeys = {
    "F3", "F4",
    "CtrlEnter", "CtrlNumEnter", "RCtrlEnter", "RCtrlNumEnter",
    "ShiftEnter", "ShiftNumEnter",
    "CtrlPgUp", "RCtrlPgUp", "CtrlPgDn", "RCtrlPgDn",
    "AltF8", "RAltF8", "AltF12", "RAltF12",
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
    "AltF11", "RAltF11", "AltF12", "RAltF12",
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
    "AltF8", "RAltF8", "AltF11", "RAltF11",
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

local function GetFileAttrEx(fname)
  return win.GetFileAttr(fname) or win.GetFileAttr([[\\?\]]..fname)
end

local function IsCtrlEnter (key)
  return key=="CtrlEnter" or key=="RCtrlEnter" or key=="CtrlNumEnter" or key=="RCtrlNumEnter"
end

local function IsCtrlPgUp (key) return key=="CtrlPgUp" or key=="RCtrlPgUp" end

local function IsCtrlPgDn (key) return key=="CtrlPgDn" or key=="RCtrlPgDn" end

local function ExecuteFromCmdLine(str, newwindow)
  panel.SetCmdLine(nil, str)
  far.MacroPost(newwindow and 'Keys"ShiftEnter"' or 'Keys"Enter"')
end

local function GetTimeString (filetime)
  if filetime then
    local ft = win.FileTimeToLocalFileTime(filetime)
    ft = ft and win.FileTimeToSystemTime(ft)
    if ft then
      return ("%04d-%02d-%02d %02d:%02d:%02d"):format(
        ft.wYear,ft.wMonth,ft.wDay,ft.wHour,ft.wMinute,ft.wSecond)
    end
  end
  return M.mTimestampMissing
end

local function TellFileNotExist (fname)
  far.Message(('%s:\n"%s"'):format(M.mFileNotExist, fname), M.mError, M.mOk, "w")
end

local function TellFileIsDirectory (fname)
  far.Message(('%s:\n"%s"'):format(M.mFileIsDirectory, fname), M.mError, M.mOk, "w")
end

local function LocateFile (fname)
  local attr = GetFileAttrEx(fname)
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

-- Баг позиционирования на файл при возвращении в меню из модального редактора;
-- причина описана здесь: http://forum.farmanager.com/viewtopic.php?p=136358#p136358
local function RedrawAll_Workaround_b4545 (list)
  local f = list.OnResizeConsole
  list.OnResizeConsole = function() end
  far.AdvControl("ACTL_REDRAWALL")
  list.OnResizeConsole = f
end

local function SortListItems (list, bDirectSort, hDlg)
  _Plugin.Cfg.bDirectSort = bDirectSort
  if bDirectSort then
    list.selalign = "bottom"
    list:Sort(function(a,b) return (a.time or 0) < (b.time or 0) end)
  else
    list.selalign = "top"
    list:Sort(function(a,b) return (a.time or 0) > (b.time or 0) end)
  end
  if hDlg then
    list:ChangePattern(hDlg, list.pattern)
  end
end

local function GetListKeyFunction (HistTypeConfig, HistObject)
  return function (self, hDlg, key, Item)
    -----------------------------------------------------------------------------------------------
    if key=="CtrlI" or key=="RCtrlI" then
      if HistTypeConfig==cfgCommands or HistTypeConfig==cfgView or HistTypeConfig==cfgFolders then
        SortListItems(self, not _Plugin.Cfg.bDirectSort, hDlg)
      end
      return "done"
    elseif key=="F3" or key=="F4" or key=="AltF3" or key=="AltF4" then
      if not Item then
        return "done"
      end
      if HistTypeConfig==cfgView or HistTypeConfig==cfgLocateFile then
        local fname = HistTypeConfig==cfgView and Item.text or Item.text:sub(2)
        if HistTypeConfig==cfgLocateFile then
          if not fname:find("[\\/]") then
            local Name = self.items.PanelDirectory and self.items.PanelDirectory.Name
            if Name and Name ~= "" then
              fname = Name:find("[\\/]$") and Name..fname or Name.."\\"..fname
            end
          end
        end
        local attr = GetFileAttrEx(fname)
        if not attr then
          TellFileNotExist(fname)
          return "done"
        elseif attr:find("d") then
          TellFileIsDirectory(fname)
          return "done"
        elseif key == "AltF3" then
          viewer.Viewer(fname)
          RedrawAll_Workaround_b4545(self)
          return "done"
        elseif key == "AltF4" then
          editor.Editor(fname)
          RedrawAll_Workaround_b4545(self)
          return "done"
        end
      end
    -----------------------------------------------------------------------------------------------
    elseif key == "F7" then
      if HistTypeConfig ~= cfgLocateFile then
        if Item then
          local timestring = GetTimeString(Item.time)
          if timestring then
            far.Message(Item.text, timestring, ";Ok")
          end
        end
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key == "CtrlF8" or key == "RCtrlF8" then
      if HistTypeConfig == cfgFolders or HistTypeConfig == cfgView then
        far.Message(M.mPleaseWait, "", "")
        self:DeleteNonexistentItems(hDlg,
            function(t) return t.text:find("^%w%w+:") -- some plugin's prefix
                               or GetFileAttrEx(t.text) or t.checked end,
            function(n) return 1 == far.Message((M.mDeleteItemsQuery):format(n),
                        M.mDeleteNonexistentTitle, ";YesNo", "w") end)
        hDlg:send("DM_REDRAW", 0, 0)
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key == "F9" then
      local s = HistObject:getfield("lastpattern")
      if s and s ~= "" then self:ChangePattern(hDlg,s) end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key=="CtrlDel" or key=="RCtrlDel" or key=="CtrlNumDel" or key=="RCtrlNumDel" then
      if HistTypeConfig ~= cfgLocateFile then
        self:DeleteNonexistentItems(hDlg,
            function(t) return t.checked end,
            function(n) return 1 == far.Message((M.mDeleteItemsQuery):format(n),
                        M.mDeleteItemsTitle, ";YesNo", "w") end)
        hDlg:send("DM_REDRAW", 0, 0)
      end
      return "done"
    -----------------------------------------------------------------------------------------------
    elseif key=="ShiftDel" or key=="ShiftNumDel" then
      if HistTypeConfig == cfgLocateFile then return "done" end
    -----------------------------------------------------------------------------------------------
    elseif key=="Enter" or key=="NumEnter" or key=="ShiftEnter" or key=="ShiftNumEnter" then
      if not Item then
        return "done"
      end
      if HistTypeConfig==cfgView then
        local attr = GetFileAttrEx(Item.text)
        if not attr then
          TellFileNotExist(Item.text)
          return "done"
        elseif attr:find("d") then
          TellFileIsDirectory(Item.text)
          return "done"
        end
      end
    -----------------------------------------------------------------------------------------------
    end

    for _,v in ipairs(HistTypeConfig.brkeys) do
      if key == v then return "break" end
    end
  end
end

local function ViewHistory_CanClose (self, item, breakkey)
  if item and (IsCtrlPgUp(breakkey) or IsCtrlPgDn(breakkey)) and not LocateFile(item.text) then
    TellFileNotExist(item.text)
    return false
  end
  return true
end

local function FoldersHistory_CanClose (self, item, breakkey)
  if not item then
    return true
  end
  ----------------------------------------------------------------------------
  if IsCtrlEnter(breakkey) then
    panel.SetCmdLine(nil, item.text)
    return true
  end
  ----------------------------------------------------------------------------
  if breakkey=="AltF8" or breakkey=="RAltF8" or breakkey=="AltF11" or breakkey=="RAltF11" then
    return true
  end
  ----------------------------------------------------------------------------
  if item.PluginId then
    if far.FindPlugin("PFM_GUID", item.PluginId) then
      panel.SetPanelDirectory(nil, breakkey==nil and 1 or 0, item.PanelDir)
      return true
    else
      far.Message(M.mPluginNotFound.."\n"..win.Uuid(item.PluginId):upper(), M.mError, M.mOk, "w")
      return false
    end
  end
  ----------------------------------------------------------------------------
  if panel.SetPanelDirectory(nil, breakkey==nil and 1 or 0, item.text) then
    return true
  end
  ----------------------------------------------------------------------------
  local GetNextPath = function(s) return s:match("^(.*[\\/]).+") end
  if not GetNextPath(item.text) then -- check before asking user
    far.Message(item.text, M.mPathNotFound, nil, "w")
    return false
  end
  ----------------------------------------------------------------------------
  if 1 ~= far.Message(item.text.."\n"..M.mJumpToNearestFolder, M.mPathNotFound, ";YesNo", "w") then
    return false
  end
  ----------------------------------------------------------------------------
  local path = item.text
  while true do
    local nextpath = GetNextPath(path)
    if nextpath then
      if panel.SetPanelDirectory(nil, breakkey==nil and 1 or 0, nextpath) then
        return true
      end
      path = nextpath
    else
      far.Message(path, M.mPathNotFound, nil, "w")
      return false
    end
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
    col_highlight = aCommonConfig.HighTextColor or 0x3A,
    col_selectedhighlight = aCommonConfig.SelHighTextColor or 0x0A,
    selalign      = "bottom",
    selignore     = true,
    searchmethod  = aHistTypeData.searchmethod or "dos",
    filterlines   = true,
    xlat          = aHistTypeData.xlat,
  }
  local list = custommenu.NewList(listProps, aItems)
  list.keyfunction = GetListKeyFunction(aHistTypeConfig, aHistObject)
  list.CanClose = (aHistTypeConfig == cfgFolders) and FoldersHistory_CanClose or
                  (aHistTypeConfig == cfgView) and ViewHistory_CanClose
  return menuProps, list
end

local function GetMaxItems (aConfig)
  return _Plugin.Cfg[aConfig.maxItemsKey]
end

local function DelayedSaveHistory (hist, delay)
  far.Timer(delay, function(h)
    h:Close()
    hist:save()
    _Plugin.History:save() -- _Plugin.Cfg.bDirectSort
  end)
end

local function get_history (aConfig, obj)
  local menu_items, map = {}, {}

  -- add plugin database items
  local hst = LibHistory.newsettings(nil, aConfig.PluginHistoryType, "PSL_LOCAL")
  local plugin_items = hst:field("items")
  local settings = hst:field("settings")
  for _,v in ipairs(plugin_items) do
    if v.text and not map[v.text] then
      table.insert(menu_items, v)
      map[v.text] = v
    end
  end

  -- add Far database items
  local last_time = settings.last_time or 0
  local far_settings = assert(far.CreateSettings("far"))

  local function AddFarItems (aFarHistoryType, aType)
    local far_items = far_settings:Enum(aFarHistoryType)
    for _,v in ipairs(far_items) do
      if v.PluginId == FarId then
      -- FAR item
        local item = map[v.Name]
        if item then
          if not (item.time and item.time >= v.Time) then
            item.time = v.Time
            item.typ = aType
          end
        else
          if v.Time >= last_time then
            item = { text=v.Name, time=v.Time, typ=aType }
            table.insert(menu_items, item)
            map[v.Name] = item
          end
        end
      else
      -- plugin item
        if v.Time >= last_time then
          local plugin_handle = far.FindPlugin("PFM_GUID", v.PluginId)
          if plugin_handle then
            local title = PlugTitleCache[v.PluginId]
            if title == nil then
              title = far.GetPluginInformation(plugin_handle).GInfo.Title -- expensive
              PlugTitleCache[v.PluginId] = title
            end
            title = v.File=="" and title or title..":"
            local text = title..v.File..":"..v.Name
            local item = map[text]
            if item then
              if not (item.time and item.time >= v.Time) then
                item.time = v.Time
                item.typ = aType
              end
            else
              item = {
                PluginId = v.PluginId;
                PanelDir = v;
                text     = text;
                time     = v.Time;
                typ      = aType;
              }
              table.insert(menu_items, item)
              map[text] = item
            end
          end
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

  local maxitems = GetMaxItems(aConfig)
  if #menu_items > maxitems then
    -- sort menu items: oldest records go first
    table.sort(menu_items, function(a,b) return (a.time or 0) < (b.time or 0) end)

    -- remove excessive items; leave checked items;
    local i = 1
    while (#menu_items >= i) and (#menu_items > maxitems) do
      if menu_items[i].checked then i = i+1 -- leave the item
      else table.remove(menu_items, i)      -- remove the item
      end
    end
  end

  -- execute the menu
  local menuProps, list = MakeMenuParams(_Plugin.Cfg, aConfig, settings, menu_items, hst)
  list.pattern = obj.pattern
  SortListItems(list, _Plugin.Cfg.bDirectSort, nil)
  local item, itempos = custommenu.Menu(menuProps, list)
  obj.pattern = list.pattern
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

local function IsCmdLineAvail()
  local ar = far.MacroGetArea()
  return ar==F.MACROAREA_SHELL or ar==F.MACROAREA_INFOPANEL or
         ar==F.MACROAREA_QVIEWPANEL or ar==F.MACROAREA_TREEPANEL
end

local function commands_history(obj)
  local item, key = get_history(cfgCommands, obj)

  if key=="AltF11" or key=="RAltF11" then return "view" end
  if key=="AltF12" or key=="RAltF12" then return "folders" end

  if item and IsCmdLineAvail() then
    if IsCtrlEnter(key) then
      panel.SetCmdLine(nil, item.text)
    else
      ExecuteFromCmdLine(item.text, key ~= nil)
    end
  end
end

local function folders_history(obj)
  local item, key = get_history(cfgFolders, obj)

  if key=="AltF8" or key=="RAltF8" then return "commands" end
  if key=="AltF11" or key=="RAltF11" then return "view" end
end

local function CallViewer (fname, disablehistory)
  local flags = {VF_NONMODAL=1, VF_IMMEDIATERETURN=1, VF_ENABLE_F6=1, VF_DISABLEHISTORY=disablehistory}
  viewer.Viewer(fname, nil, nil, nil, nil, nil, flags)
end

local function CallEditor (fname, disablehistory)
  local flags = {EF_NONMODAL=1, EF_IMMEDIATERETURN=1, EF_ENABLE_F6=1, EF_DISABLEHISTORY=disablehistory}
  editor.Editor(fname, nil, nil, nil, nil, nil, flags)
end

local function view_history(obj)
  local item, key = get_history(cfgView, obj)

  if key=="AltF8" or key=="RAltF8" then return "commands" end
  if key=="AltF12" or key=="RAltF12" then return "folders" end

  if not item then return end
  local fname = item.text

  local shift_enter = (key=="ShiftEnter" or key=="ShiftNumEnter")

  if IsCtrlEnter(key) then
    panel.SetCmdLine(nil, fname)

  elseif key == nil or shift_enter or IsCtrlPgDn(key) then
    if item.typ == "V" then CallViewer(fname, shift_enter)
    else CallEditor(fname, shift_enter)
    end

  elseif key == "F3" then CallViewer(fname, false)
  elseif key == "F4" then CallEditor(fname, false)
  end
  return key
end

local function LocateFile2()
  local info = panel.GetPanelInfo(nil,1)
  if not (info and info.PanelType==F.PTYPE_FILEPANEL) then return end

  local items = { PanelInfo=info; PanelDirectory=panel.GetPanelDirectory(nil,1); }
  for k=1,info.ItemsNumber do
    local v = panel.GetPanelItem(nil,1,k)
    local prefix = v.FileAttributes:find("d") and "/" or " "
    items[k] = {text=prefix..v.FileName}
  end

  local hst = LibHistory.newsettings(nil, cfgLocateFile.PluginHistoryType, "PSL_ROAMING")
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
    Flags = bit64.bor(F.PF_EDITOR, F.PF_VIEWER),
    PluginConfigGuids   = PluginConfigGuid1.."",
    PluginConfigStrings = { M.mPluginTitle },
    PluginMenuGuids   = PluginMenuGuid1.."",
    PluginMenuStrings = { M.mPluginTitle },
  }
end

local function export_Configure()
  if Utils.RunInternalScript("config", _Plugin.Cfg, M) then
    _Plugin.History:save()
  end
end

local function RunCycle (op)

  local obj_commands = { func=commands_history; pattern=""; }
  local obj_view     = { func=view_history;     pattern=""; }
  local obj_folders  = { func=folders_history;  pattern=""; }

  while op do
    if     op == "commands" then op = obj_commands:func()
    elseif op == "view"     then op = obj_view:func()
    elseif op == "folders"  then op = obj_folders:func()
    else break
    end
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
      { text=M.mMenuCommands,   run_cycle=true; param="commands" },
      { text=M.mMenuView,       run_cycle=true; param="view"     },
      { text=M.mMenuFolders,    run_cycle=true; param="folders"  },
      { text=M.mMenuConfig,     action=export_Configure },
      { text=M.mMenuLocateFile, action=LocateFile2      },
    }
    local numInternalItems = #items
    Utils.AddMenuItems(items,
      From==F.OPEN_PLUGINSMENU and userItems.panels or
      From==F.OPEN_EDITOR and userItems.editor or
      From==F.OPEN_VIEWER and userItems.viewer, M)
    ---------------------------------------------------------------------------
    local item, pos = far.Menu(properties, items)
    if item then
      if pos <= numInternalItems then
        if item.run_cycle then RunCycle(item.param)
        elseif item.action then item.action()
        end
      else
        Utils.RunUserItem(item, item.arg)
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
  local FirstRun = ... --> this works with Far >= 3.0.4425
  if FirstRun then
    _Plugin = Utils.InitPlugin()
    _Plugin.History = LibHistory.newsettings(nil, "config", "PSL_ROAMING")
    _Plugin.Cfg = _Plugin.History:field("config")
    setmetatable(_Plugin.Cfg, {__index = DefaultCfg})
  end
  SetExportFunctions()
end
