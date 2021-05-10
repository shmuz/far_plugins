-- Encoding: UTF-8
-- tmppanel.lua

local far2_dialog = require "far2.dialog"

local Package = {}

-- The default message table
local M = {
  MOk                         = "Ok";
  MCancel                     = "Cancel";
  MError                      = "Error";
  MWarning                    = "Warning";
  MTempPanel                  = "LuaFAR Temp. Panel";
  MTempPanelTitleNum          = " %sLuaFAR Temp. Panel [%d] ";
  MDiskMenuString             = "temporary (LuaFAR)";
  MF7                         = "Remove";
  MAltShiftF12                = "Switch";
  MAltShiftF2                 = "SavLst";
  MAltShiftF3                 = "Goto";
  MTempUpdate                 = "Updating temporary panel contents";
  MTempSendFiles              = "Sending files to temporary panel";
  MSwitchMenuTxt              = "Total files:";
  MSwitchMenuTitle            = "Available temporary panels";
  MConfigTitle                = "LuaFAR Temporary Panel";
  MConfigAddToDisksMenu       = "Add to &Disks menu";
  MConfigAddToPluginsMenu     = "Add to &Plugins menu";
  MConfigCommonPanel          = "Use &common panel";
  MSafeModePanel              = "&Safe panel mode";
  MReplaceInFilelist          = "&Replace files with file list";
  MMenuForFilelist            = "&Menu from file list";
  MCopyContents               = "Copy folder c&ontents";
  MFullScreenPanel            = "F&ull screen mode";
  MColumnTypes                = "Column &types";
  MColumnWidths               = "Column &widths";
  MStatusColumnTypes          = "Status line column t&ypes";
  MStatusColumnWidths         = "Status l&ine column widths";
  MMask                       = "File masks for the file &lists:";
  MPrefix                     = "Command line pre&fix:";
  MConfigNewOption            = "New settings will become active after FAR restart";
  MNewPanelForSearchResults   = "&New panel for search results";
  MListFilePath               = "Save file list as";
  MCopyContentsMsg            = "Copy folder contents?";
  MSavePanelsOnFarExit        = "Sa&ve panels on FAR exit";
}

-- This function should be called if message localization support is needed
function Package.SetMessageTable(msg_tbl) M = msg_tbl; end

local F  = far.Flags
local VK = win.GetVirtualKeys()
local band, bor, bnot = bit64.band, bit64.bor, bit64.bnot

-- constants
local COMMONPANELSNUMBER = 10
local BOM_UTF16LE = "\255\254"
local BOM_UTF8 = "\239\187\191"

local Opt = {
  AddToDisksMenu            = true,
  AddToPluginsMenu          = true,
  CommonPanel               = true,
  SafeModePanel             = false,
  CopyContents              = 2,
  ReplaceMode               = true,
  MenuForFilelist           = true,
  NewPanelForSearchResults  = true,
  FullScreenPanel           = false,
  ColumnTypes               = "N,S",
  ColumnWidths              = "0,8",
  StatusColumnTypes         = "NR,SC,D,T",
  StatusColumnWidths        = "0,8,0,5",
  Mask                      = "*.tmp2",
  Prefix                    = "tmp2",
  SavePanels                = true, --> new
}

local Env, Panel = {}, {}
local EnvMeta   = { __index = Env }
local PanelMeta = { __index = Panel }

local function LTrim(s) return s:match "^%s*(.*)" end
local function Trim(s) return s:match "^%s*(.-)%s*$" end
local function Unquote(s) return (s:gsub("\"", "")) end
local function ExtractFileName(s) return s:match "[^\\:]*$" end
local function ExtractFileDir(s) return s:match ".*\\" or "" end
local function AddEndSlash(s) return (s:gsub("\\?$", "\\", 1)) end
local function TruncStr(s, maxlen)
  local len = s:len()
  return len <= maxlen and s or s:sub(1,6) .. "..." .. s:sub (len - maxlen + 10)
end

local function ExpandEnvironmentStr (str)
  return ( str:gsub("%%([^%%]*)%%", win.GetEnv) )
end

local function IsDirectory (PanelItem)
  return PanelItem.FileAttributes:find"d" and true
end

local function NormalizePath (path)
  return [[\\?\]] .. path:gsub("/", "\\"):gsub("\\+$", "")
end

local function FileExists (path)
  return win.GetFileAttr(path) or win.GetFileAttr(NormalizePath(path))
end

local function GetFileInfoEx (path)
  return win.GetFileInfo(path) or win.GetFileInfo(NormalizePath(path))
end

-- File lists are supported in the following formats:
-- (a) UTF-16LE with BOM, (b) UTF-8 with BOM, (c) OEM.
local function ListFromFile (aFileName, aFullPaths)
  local list = {}
  local hFile = io.open (aFileName, "rb")
  if hFile then
    local text = hFile:read("*a")
    hFile:close()
    if text then
      local strsub = string.sub
      if strsub(text, 1, 3) == BOM_UTF8 then
        text = strsub(text, 4)
      elseif strsub(text, 1, 2) == BOM_UTF16LE then
        text = win.Utf16ToUtf8(strsub(text, 3))
      elseif string.find(text, "%z") then
        text = win.Utf16ToUtf8(text)
      -- else -- default is UTF-8
        -- do nothing
      end
      for line in text:gmatch("[^\n\r]+") do
        table.insert(list, aFullPaths and far.ConvertPath(line,"CPM_REAL") or line)
      end
    end
  end
  return list
end


local function IsOwnersDisplayed (ColumnTypes)
  for word in ColumnTypes:gmatch "[^,]+" do
    if word == "O" then return true end
  end
end


local function IsLinksDisplayed (ColumnTypes)
  for word in ColumnTypes:gmatch "[^,]+" do
    if word == "LN" then return true end
  end
end


local function ParseParam (str)
  local parm, str2 = str:match "^%|(.*)%|(.*)"
  if parm then
    return parm, LTrim(str2)
  end
  return nil, str
end


local function isDevice (FileName, dev_begin)
  local len = dev_begin:len()
  return FileName:sub(1, len):upper() == dev_begin:upper() and
         FileName:sub(len+1):match("%d+$") and true
end


local function CheckForCorrect (Name)
  Name = ExpandEnvironmentStr(Name)
  local _, p = ParseParam (Name)
  if p:match [[^\\%.\%a%:$]]
      or isDevice(p, [[\\.\PhysicalDrive]])
      or isDevice(p, [[\\.\cdrom]]) then
    return { FileName = p, FileAttributes = "a" }
  end

  if p:find "%S" and not p:find "[?*]" and p ~= "\\" and p ~= ".." then
    local PanelItem = GetFileInfoEx(p)
    if PanelItem then
      PanelItem.FileName = p
      PanelItem.AllocationSize = PanelItem.FileSize
      PanelItem.Description = "One of my files"
      PanelItem.Owner       = "Joe Average"
    --PanelItem.UserData    = numline
    --PanelItem.Flags       = { selected=true, }
      return PanelItem
    end
  end
end


local function IsCurrentFileCorrect (Handle)
  local fname = panel.GetCurrentPanelItem(Handle, 1).FileName
  local correct = (fname == "..") or (CheckForCorrect(fname) and true)
  return correct, fname
end


local function GoToFile (Target, PanelNumber)
  local Dir  = Unquote (Trim (ExtractFileDir (Target)))
  if Dir ~= "" then
    panel.SetPanelDirectory (nil, PanelNumber, Dir)
  end

  local PInfo = assert(panel.GetPanelInfo (nil, PanelNumber))
  local Name = Unquote (Trim (ExtractFileName (Target))):upper()
  for i=1, PInfo.ItemsNumber do
    local item = panel.GetPanelItem (nil, PanelNumber, i)
    if Name == ExtractFileName (item.FileName):upper() then
      panel.RedrawPanel (nil, PanelNumber, { CurrentItem=i, TopPanelItem=i })
      return
    end
  end
end


local function ShowMenuFromFile (FileName)
  local list = ListFromFile(FileName,false)
  local menuitems = {}
  for i, line in ipairs(list) do
    line = ExpandEnvironmentStr(line)
    local part1, part2 = ParseParam(line)
    if part1 == "-" then
      menuitems[i] = { separator=true }
    else
      local menuline = TruncStr(part1 or part2, 67)
      menuitems[i] = { text=menuline, action=part2 }
    end
  end
  local breakkeys = { {BreakKey="S+RETURN"}, } -- Shift+Enter

  local Title = ExtractFileName(FileName):gsub("%.[^.]+$", "")
  Title = TruncStr(Title, 64)
  local Item, Position = far.Menu(
    { Flags="FMENU_WRAPMODE", Title=Title, HelpTopic="Contents", Bottom=#menuitems.." lines" },
    menuitems, breakkeys)
  if not Item then return end

  local bShellExecute
  if Item.BreakKey then
    bShellExecute = true
    Item = menuitems[Position]
  else
    local panelitem = CheckForCorrect(Item.action)
    if panelitem then
      if IsDirectory(panelitem) then
        panel.SetPanelDirectory(nil, 1, Item.action)
      else
        bShellExecute = true
      end
    else
      panel.SetCmdLine(nil, Item.action)
    end
  end
  if bShellExecute then
    win.ShellExecute(nil, "open", Item.action, nil, nil, 5) --> 5 == SW_SHOW
  end
end


function Package.PutExportedFunctions (tab)
  for _, name in ipairs {
    "ClosePanel", "GetFindData", "GetOpenPanelInfo", "ProcessPanelEvent",
    "ProcessPanelInput", "PutFiles", "SetDirectory", "SetFindList" }
  do
    tab[name] = Panel[name]
  end
end


-- Создать новое окружение, или воссоздать из истории /?/
function Package.NewEnv (aEnv)
  local self = aEnv or {}

  -- создать или воссоздать опции для окружения
  self.Opt = self.Opt or {}
  for k,v in pairs(Opt) do -- скопировать отсутствующие опции
    if self.Opt[k]==nil then self.Opt[k]=v end
  end
  self.OptMeta = { __index = self.Opt } -- метатаблица для будущего наследования

  -- инициализировать некоторые переменные
  self.LastSearchResultsPanel = self.LastSearchResultsPanel or 1
  self.StartupOptCommonPanel = self.Opt.CommonPanel
  self.StartupOptFullScreenPanel = self.Opt.FullScreenPanel

  -- если нет "общих" панелей - создать их
  if not self.CommonPanels then
    self.CommonPanels = {}
    for i=1,COMMONPANELSNUMBER do self.CommonPanels[i] = {} end
    self.CurrentCommonPanel = 1
  end

  -- установить наследование функций от базового окружения
  return setmetatable (self, EnvMeta)
end


-- Создать новую панель
function Env:NewPanel (aOptions)
  local pan = {
    Env = self,
    LastOwnersRead = false,
    LastLinksRead = false,
    UpdateNeeded = true
  }

  -- панель наследует опции от своего окружения,
  -- но переданные опции (аргумент функции) имеют приоритет.
  pan.Opt = setmetatable({}, self.OptMeta)
  if aOptions then
    for k,v in pairs(aOptions) do pan.Opt[k] = v end
  end

  if self.StartupOptCommonPanel then
    pan.Index = self.CurrentCommonPanel
    pan.GetItems = Panel.GetRefItems
    pan.ReplaceFiles = Panel.ReplaceRefFiles
  else
    pan.Files = {}
    pan.GetItems = Panel.GetOwnItems
    pan.ReplaceFiles = Panel.ReplaceOwnFiles
  end

  -- установить наследование функций от базового класса панели
  return setmetatable (pan, PanelMeta)
end


function Env:OpenPanelFromOutput (command)
  local mypanel = nil
  -- Run the command in the context of directory displayed in Far panel
  -- rather than current directory of the Far process.
  local dir_to_restore = win.GetCurrentDir()
  win.SetCurrentDir(far.GetCurrentDirectory())
  local h = io.popen (command, "rt")
  if h then
    local list = {}
    local cp = win.GetConsoleOutputCP() -- this function exists in Far >= 3.0.5326
    for line in h:lines() do
      local line2 = line
      if cp ~= 65001 then -- not UTF-8
        line2 = win.MultiByteToWideChar(line2, cp)
        line2 = win.WideCharToMultiByte(line2, 65001)
      end
      table.insert(list, line2)
    end
    h:close()
    mypanel = self:NewPanel()
    mypanel:AddList (list, mypanel.Opt.ReplaceMode)
  end
  win.SetCurrentDir(dir_to_restore)
  return mypanel
end


function Env:GetPluginInfo()
  local PluginMenuGuid1   = win.Uuid("b1263604-3d97-4a7f-9803-99d3e0c37bae")
  local PluginConfigGuid1 = win.Uuid("78f0f093-a71f-44f0-a7be-c59c79376b68")
  local DiskMenuGuid1     = win.Uuid("2cd6d14a-e300-4dd4-a0dd-04d2e6c84501")

  local opt = self.Opt
  local Info = {
    Flags = 0,
    CommandPrefix = opt.Prefix,
    PluginConfigGuids = PluginConfigGuid1.."",
    PluginConfigStrings = { M.MTempPanel },
  }
  -- Info.Flags.preload = true
  if opt.AddToPluginsMenu then
    Info.PluginMenuGuids = PluginMenuGuid1..""
    Info.PluginMenuStrings = { M.MTempPanel }
  end
  if opt.AddToDisksMenu then
    Info.DiskMenuGuids = DiskMenuGuid1..""
    Info.DiskMenuStrings = { M.MDiskMenuString }
  end
  return Info
end


function Env:SelectPanelFromMenu()
  local txt = M.MSwitchMenuTxt
  local fmt1 = "&%s. %s %d"
  local menuitems = {}
  for i = 1, COMMONPANELSNUMBER do
    local menuline
    if i <= 10 then
      menuline = fmt1:format(i-1, txt, #self.CommonPanels[i])
    elseif i <= 36 then
      menuline = fmt1:format(string.char(("A"):byte()+i-11), txt, #self.CommonPanels[i])
    else
      menuline = ("   %s %d"):format(txt, #self.CommonPanels[i])
    end
    menuitems[i] = { text=menuline }
  end

  local Item, Position = far.Menu( {
    Flags = {FMENU_AUTOHIGHLIGHT=1, FMENU_WRAPMODE=1},
    Title = M.MSwitchMenuTitle, HelpTopic = "Contents",
    SelectIndex = self.CurrentCommonPanel,
  }, menuitems)
  return Item and Position
end


function Env:FindSearchResultsPanel()
  for i,v in ipairs(self.CommonPanels) do
    if #v == 0 then return i end
  end
  -- no panel is empty - use least recently used index
  local index = self.LastSearchResultsPanel
  self.LastSearchResultsPanel = self.LastSearchResultsPanel + 1
  if self.LastSearchResultsPanel > #self.CommonPanels then
    self.LastSearchResultsPanel = 1
  end
  return index
end


function Env:Analyse (Data)
--far.Show("AnalyseW", "OpMode="..Data.OpMode, "FileName="..Data.FileName)
  if Data.FileName then
    return far.ProcessName(
      "PN_CMPNAMELIST", self.Opt.Mask, Data.FileName, "PN_SKIPPATH")
  end
end


function Env:Open (OpenFrom, Guid, Item)
  self.StartupOpenFrom = OpenFrom
  if OpenFrom == F.OPEN_ANALYSE then
    if self.Opt.MenuForFilelist then
      ShowMenuFromFile(Item.FileName)
      return F.PANEL_STOP
    else
      -- far.Show("OpenW", "OpenFrom="..(OpenFrom==9 and "OPEN_ANALYSE" or OpenFrom),
      --          "Item.Handle="..tostring(Item.Handle), Item.FileName)
      local pan = self:NewPanel()
      pan:AddList (ListFromFile(Item.FileName,true), self.Opt.ReplaceMode)
      pan.HostFile = Item.FileName
      return pan
    end
  elseif OpenFrom == F.OPEN_COMMANDLINE then
    local newOpt = setmetatable({}, {__index=self.Opt})
    local ParamsTable = {
      safe="SafeModePanel", replace="ReplaceMode", menu="MenuForFilelist",
      full="FullScreenPanel" }

    local argv = Item
    while #argv > 0 do
      local switch, param, rest = argv:match "^%s*([+%-])(%S*)(.*)"
      if not switch then break end
      argv = rest
      param = param:lower()
      if ParamsTable[param] then
        newOpt[ParamsTable[param]] = (switch == "+")
      else
        local digit = param:sub(1,1):match "%d"
        if digit then
          self.CurrentCommonPanel = tonumber(digit) + 1
        end
      end
    end

    argv = Trim(argv)
    if #argv > 0 then
      if argv:sub(1,1) == "<" then
        argv = argv:sub(2)
        return self:OpenPanelFromOutput (argv)
      else
        argv = Unquote(argv)
        local TMP = ExpandEnvironmentStr(argv)
        local TmpPanelDir = far.PluginStartupInfo().ModuleDir
        local PathName = win.SearchPath (panel.GetPanelDirectory(nil, 1).Name, TMP) or
                         win.SearchPath (TmpPanelDir, TMP) or
                         win.SearchPath (nil, TMP)
        if PathName then
          if newOpt.MenuForFilelist then
            ShowMenuFromFile(PathName)
            return nil
          else
            local pan = self:NewPanel(newOpt)
            pan:AddList(ListFromFile(PathName,true), newOpt.ReplaceMode)
            pan.HostFile = PathName
            return pan
          end
        else
          return
        end
      end
    end
    return self:NewPanel(newOpt)
  end
  return self:NewPanel()
end


function Env:ExitFAR()
  if not self.Opt.SavePanels then
    self.CommonPanels = nil
    self.CurrentCommonPanel = nil
  end
end


function Env:Configure()
  local Guid1 = win.Uuid("dd4492cf-d7a3-431d-b464-3fe4ee63de57")
  local WIDTH, HEIGHT = 78, 22
  local DC = math.floor(WIDTH/2 - 1)

  local D = far2_dialog.NewDialog()

  D._                  = {"DI_DOUBLEBOX", 3, 1, WIDTH-4,HEIGHT-2, 0,0,0,0, M.MConfigTitle}
  D.AddToDisksMenu     = {"DI_CHECKBOX",  5, 2, 0, 0,   0,0,0,0, M.MConfigAddToDisksMenu}
  D.AddToPluginsMenu   = {"DI_CHECKBOX", DC, 2, 0, 0,   0,0,0,0, M.MConfigAddToPluginsMenu}
  D.separator          = {"DI_TEXT",      5, 4, 0, 0,   0,0,0,{DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}

  D.CommonPanel        = {"DI_CHECKBOX",  5, 5, 0, 0,   0,0,0,0, M.MConfigCommonPanel}
  D.SafeModePanel      = {"DI_CHECKBOX",  5, 6, 0, 0,   0,0,0,0, M.MSafeModePanel}
  D.CopyContents       = {"DI_CHECKBOX",  5, 7, 0, 0,   0,0,0,"DIF_3STATE", M.MCopyContents}
  D.ReplaceMode        = {"DI_CHECKBOX", DC, 5, 0, 0,   0,0,0,0, M.MReplaceInFilelist}
  D.MenuForFilelist    = {"DI_CHECKBOX", DC, 6, 0, 0,   0,0,0,0, M.MMenuForFilelist}
  D.NewPanelForSearchResults =
                         {"DI_CHECKBOX", DC, 7, 0, 0,   0,0,0,0, M.MNewPanelForSearchResults}
  D.SavePanels         = {"DI_CHECKBOX", DC, 8, 0, 0,   0,0,0,0, M.MSavePanelsOnFarExit}
  D.separator          = {"DI_TEXT",      5, 9, 0, 0,   0,0,0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}

  D._                  = {"DI_TEXT",      5,10, 0, 0,   0,0,0,0, M.MColumnTypes}
  D.ColumnTypes        = {"DI_EDIT",      5,11,36,11,   0,0,0,0, ""}
  D._                  = {"DI_TEXT",      5,12, 0, 0,   0,0,0,0, M.MColumnWidths}
  D.ColumnWidths       = {"DI_EDIT",      5,13,36,13,   0,0,0,0, ""}
  D._                  = {"DI_TEXT",     DC,10, 0, 0,   0,0,0,0, M.MStatusColumnTypes}
  D.StatusColumnTypes  = {"DI_EDIT",     DC,11,72,11,   0,0,0,0, ""}
  D._                  = {"DI_TEXT",     DC,12, 0, 0,   0,0,0,0, M.MStatusColumnWidths}
  D.StatusColumnWidths = {"DI_EDIT",     DC,13,72,13,   0,0,0,0, ""}
  D.FullScreenPanel    = {"DI_CHECKBOX",  5,14, 0, 0,   0,0,0,0, M.MFullScreenPanel}
  D.separator          = {"DI_TEXT",      5,15, 0, 0,   0,0,0,{DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}

  D._                  = {"DI_TEXT",      5,16, 0, 0,   0,0,0,0, M.MMask}
  D.Mask               = {"DI_EDIT",      5,17,36,17,   0,0,0,0, ""}
  D._                  = {"DI_TEXT",     DC,16, 0, 0,   0,0,0,0, M.MPrefix}
  D.Prefix             = {"DI_EDIT",     DC,17,72,17,   0,0,0,0, ""}
  D.separator          = {"DI_TEXT",      5,18, 0, 0,   0,0,0,{DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}

  D.btnOk              = {"DI_BUTTON",    0,19, 0, 0,   0,0,0,{DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MOk}
  D.btnCancel          = {"DI_BUTTON",    0,19, 0, 0,   0,0,0,"DIF_CENTERGROUP", M.MCancel}

  far2_dialog.LoadData(D, self.Opt)
  local ret = far.Dialog (Guid1, -1, -1, WIDTH, HEIGHT, "Config", D)
  if ret ~= D.btnOk.id then return false end
  far2_dialog.SaveData(D, self.Opt)

  if self.StartupOptFullScreenPanel ~= self.Opt.FullScreenPanel or
    self.StartupOptCommonPanel ~= self.Opt.CommonPanel
  then
    far.Message(M.MConfigNewOption, M.MTempPanel, M.MOk)
  end
  return true
end


function Panel:GetOwnItems()
  return self.Files
end


function Panel:GetRefItems()
  return self.Env.CommonPanels[self.Index]
end


function Panel:ReplaceOwnFiles (Table)
  self.Files = Table
end


function Panel:ReplaceRefFiles (Table)
  self.Env.CommonPanels[self.Index] = Table
end


function Panel:ClosePanel (Handle)
  collectgarbage "collect"
end


function Panel:AddList (aList, aReplaceMode)
  if aReplaceMode then
    self:ReplaceFiles({})
  end
  local items = self:GetItems()
  for _,v in ipairs(aList) do
    if v ~= "." and v ~= ".." and FileExists(v) then
      items[#items+1] = v
    end
  end
end


function Panel:UpdateItems (ShowOwners, ShowLinks)
  local hScreen = #self:GetItems() >= 1000 and far.SaveScreen()
  if hScreen then far.Message(M.MTempUpdate, M.MTempPanel, "") end

  self.LastOwnersRead = ShowOwners
  self.LastLinksRead = ShowLinks
  local RemoveTable = {}
  local PanelItems = {}
  for i,v in ipairs(self:GetItems()) do
    local panelitem = CheckForCorrect (v)
    if panelitem then
      table.insert (PanelItems, panelitem)
    else
      RemoveTable[i] = true
    end
  end
  self:RemoveMarkedItems(RemoveTable)

  if ShowOwners or ShowLinks then
    for _,v in ipairs(PanelItems) do
      if ShowOwners then
        v.Owner = far.GetFileOwner(nil, v.FileName)
      end
      if ShowLinks then
        v.NumberOfLinks = far.GetNumberOfLinks(v.FileName)
      end
    end
  end
  if hScreen then far.RestoreScreen(hScreen) end
  return PanelItems
end


function Panel:ProcessRemoveKey (Handle)
  local tb_out, tb_dict = {}, {}
  local PInfo = assert(panel.GetPanelInfo (Handle, 1))
  for i=1, PInfo.SelectedItemsNumber do
    local item = panel.GetSelectedPanelItem (Handle, 1, i)
    tb_dict[item.FileName] = true
  end
  for _,v in ipairs(self:GetItems()) do
    if not tb_dict[v] then
      table.insert (tb_out, v)
    end
  end
  self:ReplaceFiles (tb_out)

  panel.UpdatePanel (Handle, 1, true)
  panel.RedrawPanel (Handle, 1)

  PInfo = assert(panel.GetPanelInfo (Handle, 0))
  if PInfo.PanelType == F.PTYPE_QVIEWPANEL then
    panel.UpdatePanel (Handle, 0, true)
    panel.RedrawPanel (Handle, 0)
  end
end


function Panel:SaveListFile (FileName)
  local hFile = io.open (FileName, "w")
  if hFile then
    hFile:write(BOM_UTF8)
    for _,v in ipairs(self:GetItems()) do
      hFile:write (v, "\n")
    end
    hFile:close()
  else
    far.Message("", M.MError, nil, "we")
  end
end


function Panel:ProcessSaveListKey (Handle)
  if #self:GetItems() == 0 then return end

  -- default path: opposite panel directory\panel<index>.<mask extension>
  local CurDir = panel.GetPanelDirectory(Handle, 0).Name
  local ListPath = AddEndSlash (CurDir) .. "panel"
  if self.Index then
    ListPath = ListPath .. (self.Index - 1)
  end

  local ExtBuf = self.Opt.Mask:gsub(",.*", "")
  local ext = ExtBuf:match "%..-$"
  if ext and not ext:match "[*?]" then
    ListPath = ListPath .. ext
  end

  ListPath = far.InputBox (nil, M.MTempPanel, M.MListFilePath,
      "Panel.SaveList", ListPath, nil, nil, F.FIB_BUTTONS)
  if ListPath then
    self:SaveListFile (ListPath)
    panel.UpdatePanel (Handle, 0, true)
    panel.RedrawPanel (Handle, 0)
  end
end


function Panel:ProcessPanelInput (Handle, Rec)
  if not Rec.KeyDown then return false end

  local Key = Rec.VirtualKeyCode
  local ALT   = bor(F.LEFT_ALT_PRESSED, F.RIGHT_ALT_PRESSED)
  local CTRL  = bor(F.LEFT_CTRL_PRESSED, F.RIGHT_CTRL_PRESSED)
  local A = (0 ~= band(Rec.ControlKeyState, ALT))
  local C = (0 ~= band(Rec.ControlKeyState, CTRL))
  local S = (0 ~= band(Rec.ControlKeyState, F.SHIFT_PRESSED))

  if not (A or C or S) and Key == VK.F1 then
    far.ShowHelp (far.PluginStartupInfo().ModuleName, nil,
      bor (F.FHELP_USECONTENTS, F.FHELP_NOSHOWERROR))
    return true
  end

  if A and S and not C and Key == VK.F9 then
     if self.AS_F9 then self:AS_F9(Handle) end
     return true
  end

  if A and S and not C and Key == VK.F3 then
    local Ok, CurFileName = IsCurrentFileCorrect (Handle)
    if Ok then
      if CurFileName ~= ".." then
        local currItem = assert(panel.GetCurrentPanelItem (Handle, 1))
        if IsDirectory (currItem) then
          panel.SetPanelDirectory (nil, 2, CurFileName)
        else
          GoToFile(CurFileName, 2)
        end
        panel.RedrawPanel (nil, 2)
        return true
      end
    end
  end

  if (A or S or not C) and (Key==VK.F3 or Key==VK.F4 or Key==VK.F5 or
                            Key==VK.F6 or Key==VK.F8) then
    if not IsCurrentFileCorrect (Handle) then
      return true
    end
  end

  if self.Opt.SafeModePanel and (not A and not S and C) and Key == VK.PRIOR then
    local Ok, CurFileName = IsCurrentFileCorrect(Handle)
    if Ok and CurFileName ~= ".." then
      GoToFile(CurFileName, 1)
      return true
    end
    if CurFileName == ".." then
      panel.ClosePanel(Handle, ".")
      return true
    end
  end

  if not (A or C or S) and Key == VK.F7 then
    self:ProcessRemoveKey (Handle)
    collectgarbage "collect"
    return true
  elseif (A and S and not C) and Key == VK.F2 then
    self:ProcessSaveListKey()
    return true
  else
    if self.Env.StartupOptCommonPanel and (A and S and not C) then
      if Key == VK.F12 then
        local index = self.Env:SelectPanelFromMenu()
        if index then
          self:SwitchToPanel (Handle, index)
        end
        return true
      elseif Key >= VK["0"] and Key <= VK["9"] then
        self:SwitchToPanel (Handle, Key - VK["0"] + 1)
        return true
      end
    end
  end
  return false
end


function Panel:RemoveDuplicates ()
  local items = self:GetItems()
  if items.NoDuplicates then
    items.NoDuplicates = nil
  else
    local RemoveTable, map = {}, {}
    for i,v in ipairs(items) do
      if map[v] then RemoveTable[i] = true
      else map[v] = true
      end
    end
    self:RemoveMarkedItems(RemoveTable)
  end
end


function Panel:CommitPutFiles (hRestoreScreen)
  far.RestoreScreen (hRestoreScreen)
end


function Panel:PutFiles (Handle, PanelItems, Move, SrcPath, OpMode)
  local was_error
  self.UpdateNeeded = true
  local hScreen = self:BeginPutFiles()
  for _,v in ipairs (PanelItems) do
    if not self:PutOneFile(SrcPath, v) then
      was_error = true
    end
  end
  collectgarbage "collect"
  self:CommitPutFiles (hScreen)
  return not was_error
end


function Panel:BeginPutFiles()
  self.SelectedCopyContents = self.Opt.CopyContents
  local hScreen = far.SaveScreen()
  far.Message(M.MTempSendFiles, M.MTempPanel, "")
  return hScreen
end


function Panel:PutOneFile (SrcPath, PanelItem)
  local CurName = PanelItem.FileName
  if not CurName:find("\\") then
    local path = SrcPath=="" and far.GetCurrentDirectory() or SrcPath
    CurName = AddEndSlash(path) .. CurName
  end
  local outPanelItem = CheckForCorrect(CurName)
  if not outPanelItem then return false end

  local items = self:GetItems()
  items[#items+1] = CurName

  if self.SelectedCopyContents and IsDirectory(outPanelItem) then
    if self.SelectedCopyContents == 2 then
      local res = far.Message(M.MCopyContentsMsg, M.MWarning, ";YesNo", "", "Config")
      self.SelectedCopyContents = (res == 1)
    end
    if self.SelectedCopyContents then
      local DirPanelItems = far.GetDirList (CurName)
      if DirPanelItems then
        for _, v in ipairs (DirPanelItems) do
          items[#items+1] = v.FileName
        end
      else
        self:ReplaceFiles {}
        return false
      end
    end
  end
  PanelItem.Flags = band(PanelItem.Flags, bnot(F.PPIF_SELECTED))
  return true
end


function Panel:GetFindData (Handle, OpMode)
  -- far.Show("GetFindData", "Handle="..Handle,
  --          "OpMode="..(OpMode==16 and "OPM_TOPLEVEL" or OpMode==0 and "OPM_NONE" or OpMode))
  local types = panel.GetColumnTypes (Handle, 1)
  if types then
    self:RemoveDuplicates()
    local PanelItems = self:UpdateItems (IsOwnersDisplayed (types), IsLinksDisplayed (types))
    return PanelItems
  end
end


function Panel:RemoveMarkedItems (RemoveTable)
  if next(RemoveTable) then
    local tb = {}
    local items = self:GetItems()
    for i,v in ipairs(items) do
      if not RemoveTable[i] then table.insert(tb, v) end
    end
    self:ReplaceFiles(tb)
  end
end


function Panel:ProcessPanelEvent (Handle, Event, Param)
  if Event == F.FE_CHANGEVIEWMODE then
    local types = panel.GetColumnTypes (Handle, 1)
    local UpdateOwners = IsOwnersDisplayed (types) and not self.LastOwnersRead
    local UpdateLinks = IsLinksDisplayed (types) and not self.LastLinksRead
    if UpdateOwners or UpdateLinks then
      self:UpdateItems (UpdateOwners, UpdateLinks)
      panel.UpdatePanel (Handle, 1, true)
      panel.RedrawPanel (Handle, 1)
    end
  end
  return false
end


function Panel:GetOpenPanelInfo (Handle)
  local OPIF_SAFE_FLAGS = bor(
    F.OPIF_ADDDOTS,         -- Автоматически добавить элемент, равный двум точкам (..)
    F.OPIF_SHOWNAMESONLY)   -- Показывать по умолчанию имена без путей во всех режимах просмотра

  local OPIF_COMMON_FLAGS = bor(
    OPIF_SAFE_FLAGS,
    F.OPIF_EXTERNALDELETE,  -- Флаги могут быть использованы только с OPIF_REALNAMES.
    F.OPIF_EXTERNALGET,     -- Вынуждает использование соответствующих функций Far Manager,
                            -- даже если требуемая функция экспортируется плагином.

    F.OPIF_REALNAMES,       -- Включает использование стандартной обработки файла Far Manager'ом,
                            -- если запрошенная операция не поддерживается плагином. Если этот
                            -- флаг указан, элементы на панели плагина должны быть именами
                            -- реальных файлов.
    F.OPIF_SHORTCUT)        -- Флаг указывает, что плагин позволяет добавлять смену каталогов
                            -- в историю Far Manager'a, а также поддерживает установку "быстрых
                            -- каталогов" на своей панели.
  -----------------------------------------------------------------------------
  --far.Message"GetOpenPanelInfo" --> this crashes FAR if enter then exit viewer/editor
                                  --  on a file in the emulated file system
  -----------------------------------------------------------------------------
  local Info = {
    Flags = self.Opt.SafeModePanel and OPIF_SAFE_FLAGS or OPIF_COMMON_FLAGS,
    Format = M.MTempPanel,
    CurDir = "",
  }
  if self.HostFile then
    local cur = panel.GetCurrentPanelItem(nil,1)
    if cur and cur.FileName==".." then Info.HostFile=self.HostFile; end
  end
  -----------------------------------------------------------------------------
  local TitleMode = self.Opt.SafeModePanel and "(R) " or ""
  if self.Index then
    Info.PanelTitle = M.MTempPanelTitleNum : format(TitleMode, self.Index-1)
  else
    Info.PanelTitle = (" %s%s ") : format(TitleMode, M.MTempPanel)
  end
  -----------------------------------------------------------------------------
  local mode = {
    ColumnTypes = self.Opt.ColumnTypes,
    ColumnWidths = self.Opt.ColumnWidths,
    StatusColumnTypes = self.Opt.StatusColumnTypes,
    StatusColumnWidths = self.Opt.StatusColumnWidths,
    Flags = { PMFLAGS_CASECONVERSION=1 },
  }
  if self.Env.StartupOpenFrom == F.OPEN_COMMANDLINE then
    mode.Flags.PMFLAGS_FULLSCREEN = self.Opt.FullScreenPanel
  else
    mode.Flags.PMFLAGS_FULLSCREEN = self.Env.StartupOptFullScreenPanel
  end
  Info.PanelModesArray = { [5] = mode }
  Info.PanelModesNumber = 10
  Info.StartPanelMode = ("4"):byte()
  -----------------------------------------------------------------------------
	local ALTSHIFT = bor(F.SHIFT_PRESSED, F.LEFT_ALT_PRESSED)
  Info.KeyBar = {
    {VirtualKeyCode=VK.F7, Text=M.MF7, LongText=M.MF7},
    {VirtualKeyCode=VK.F2, ControlKeyState=ALTSHIFT, Text=M.MAltShiftF2, LongText=M.MAltShiftF2},
    {VirtualKeyCode=VK.F3, ControlKeyState=ALTSHIFT, Text=M.MAltShiftF3, LongText=M.MAltShiftF3},
  }
  if self.Env.StartupOptCommonPanel then
    table.insert(Info.KeyBar,
      {VirtualKeyCode=VK.F12, ControlKeyState=ALTSHIFT, Text=M.MAltShiftF12, LongText=M.MAltShiftF12})
  end
  -----------------------------------------------------------------------------
  return Info
end


function Panel:SetDirectory (Handle, Dir, OpMode)
  if 0 == band(OpMode, F.OPM_FIND) then
    panel.ClosePanel (Handle, (Dir ~= "\\" and Dir or "."))
    return true
  end
end


function Panel:SetFindList (Handle, PanelItems)
  local hScreen = self:BeginPutFiles()
  if self.Index and self.Opt.NewPanelForSearchResults then
    self.Env.CurrentCommonPanel = self.Env:FindSearchResultsPanel()
    self.Index = self.Env.CurrentCommonPanel
  end
  local newfiles = {}
  for i,v in ipairs(PanelItems) do
    newfiles[i] = v.FileName
  end
  self:ReplaceFiles (newfiles)
  self:CommitPutFiles (hScreen)
  self.UpdateNeeded = true
  return true
end


function Panel:SwitchToPanel (Handle, Index)
  if Index and Index ~= self.Index then
    self.Env.CurrentCommonPanel = Index
    self.Index = self.Env.CurrentCommonPanel
    panel.UpdatePanel(Handle, 1, true)
    panel.RedrawPanel(Handle, 1)
  end
end


Package.Env, Package.Panel = Env, Panel
return Package
