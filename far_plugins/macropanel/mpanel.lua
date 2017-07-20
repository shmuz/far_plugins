-- started: 2013-10-30
--------------------------------------------------------------------------------
far.ReloadDefaultScript = true
_G.Settings = Settings or {}

local F = far.Flags
local Title = "Macro Panel"
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor
local LStricmp = far.LStricmp

local LoadSettings, SaveSettings, SettingsAreLoaded do
  local Descr = {
    { Name="LastPanelMode", Type="FST_QWORD", Default=("1"):byte() },
    { Name="LastSortMode",  Type="FST_QWORD", Default=F.SM_NAME    },
    { Name="LastSortOrder", Type="FST_QWORD", Default=0            },
  }

  function LoadSettings()
    local obj = far.CreateSettings()
    for _,v in ipairs(Descr) do
      Settings[v.Name] = obj:Get(0, v.Name, v.Type) or v.Default
    end
    obj:Free()
  end

  function SaveSettings()
    local obj = far.CreateSettings()
    for _,v in ipairs(Descr) do
      obj:Set(0, v.Name, v.Type, Settings[v.Name])
    end
    obj:Free()
  end

  function SettingsAreLoaded()
    return not not Settings[Descr[1].Name]
  end
end

if not SettingsAreLoaded() then
  LoadSettings()
end

local OpenPanelInfoFlags = bor(F.OPIF_ADDDOTS, F.OPIF_DISABLEFILTER,
  F.OPIF_DISABLEHIGHLIGHTING, F.OPIF_DISABLESORTGROUPS, F.OPIF_SHORTCUT)

local P_AREA,P_GROUP,P_KEY,P_FILENAME,P_STARTLINE,P_FILEMASK = 1,1,2,3,4,5

local PluginMenuGuid1   = win.Uuid("788CFB39-783F-431B-9CB2-C277E867ECE2")
local PluginConfigGuid1 = win.Uuid("1DCA3760-AA03-496C-B7CC-590D923525BC")

-- @param fname     : full file name
-- @param whatpanel : 0=passive, 1=active (default)
-- @return          : true if the file has been located
local function LocateFile (fname, whatpanel)
  whatpanel = whatpanel or 1
  local attr = win.GetFileAttr(fname)
  if attr and not attr:find"d" then
    local dir, name = fname:match("^(.*\\)([^\\]*)$")
    if panel.SetPanelDirectory(nil, whatpanel, dir) then
      local pinfo = panel.GetPanelInfo(nil, whatpanel)
      for i=1, pinfo.ItemsNumber do
        local item = panel.GetPanelItem(nil, whatpanel, i)
        if item.FileName == name then
          local rect = pinfo.PanelRect
          local hheight = math.floor((rect.bottom - rect.top - 4) / 2)
          local topitem = pinfo.TopPanelItem
          panel.RedrawPanel(nil, whatpanel, { CurrentItem = i,
            TopPanelItem = i>=topitem and i<topitem+hheight and topitem or
                           i>hheight and i-hheight or 0 })
          return true
        end
      end
    end
  end
  return false
end

function export.GetPluginInfo()
  return {
    CommandPrefix = "mp",
    Flags = 0,
    PluginConfigGuids   = PluginConfigGuid1,
    PluginConfigStrings = { Title },
    PluginMenuGuids   = PluginMenuGuid1,
    PluginMenuStrings = { Title },
  }
end

local pat_cmdline = regex.new ([[
  ^ \s* (?: (macros | m) | (events | e) )
  (?: \s+(\S+) (?: \s+(\S+) (?: \s+(\S+) )? )? )? (?: \s | $)
]], "ix")

function export.Open(OpenFrom, Guid, Item)
-- local t1=os.clock()
-- for k=1,1000 do export.GetFindData({type="macros"},nil,nil) end
-- far.Message(os.clock()-t1)

  if OpenFrom == F.OPEN_PLUGINSMENU then
    local menuitem = far.Menu({Title=Title},
      { {text="&1. Show macros",type="macros"}, {text="&2. Show events",type="events"} })
    if menuitem then return { type=menuitem.type } end

  elseif OpenFrom == F.OPEN_COMMANDLINE then
    local macros, events, f1, f2, f3 = pat_cmdline:match(Item)
    if macros or events then
      f1, f2, f3 = f1 and regex.new(f1,"i"), f2 and regex.new(f2,"i"), f3 and regex.new(f3,"i")
      return { type=macros and "macros" or "events", f1=f1, f2=f2, f3=f3 }
    end

  elseif OpenFrom == F.OPEN_SHORTCUT then
    return { type=Item.ShortcutData }

  end
end

function export.Configure()
  far.Message("Nothing to configure as yet", Title)
end

function export.GetFindData (object, handle, OpMode)
  --if band(OpMode, F.OPM_FIND) ~= 0 then return end
  local sequence = [[
    local idx, kind = ...
    while true do
      local m = mf.GetMacroCopy(idx)
      if not m then return 0 end
      if kind == "macros" then
        if m.area and not m.disabled then
          local startline = m.FileName and m.action and debug.getinfo(m.action,"S").linedefined or 1
          return idx, m.description, m.area, m.key, m.index, m.FileName, startline, m.filemask
        end
      elseif kind == "events" then
        if m.group and not m.disabled then
          local startline = m.FileName and m.action and debug.getinfo(m.action,"S").linedefined or 1
          return idx, m.description, m.group, m.index, m.FileName, startline, m.filemask
        end
      end
      idx = idx+1
    end
  ]]
  local data = {}
  local objtype = object.type
  local idx = 1
  while true do
    local t = far.MacroExecute(sequence, nil, idx, objtype)
    if not t then -- error occured: do not create panel
      far.Message("Can not retrieve "..objtype, Title, nil, "w")
      return
    end
    if t[1]==0 then return data end -- end indicator
    if objtype == "macros" then
      local description, area, key, index, filename, startline, filemask = unpack(t, 2, t.n)
      if description==nil or description=="" then
        description = ("[index = %d]"):format(index)
      end
      if  (not object.f1 or object.f1:find(description)) and
          (not object.f2 or object.f2:find(area)) and
          (not object.f3 or object.f3:find(key))
      then
        filemask = filemask or ""
        data[#data+1] = { FileName=description, CustomColumnData = { area,key,filename,startline,filemask } }
      end
    elseif objtype == "events" then
      local description, group, index, filename, startline, filemask = unpack(t, 2, t.n)
      if description==nil or description=="" then
        description = ("[index = %d]"):format(index)
      end
      if  (not object.f1 or object.f1:find(description)) and
          (not object.f2 or object.f2:find(group))
      then
        data[#data+1] = { FileName=description, CustomColumnData = { group,"",filename,startline,filemask } }
      end
    end
    idx = t[1] + 1
  end
end

local MacroPanelModes do
  local m1 = {
    ColumnTypes = "N,C0,C1",
    ColumnWidths = "50%,0,0",
    ColumnTitles = { "Description","Area","Key" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    Flags = 0,
  }
  local m2 = {
    ColumnTypes = "N,C0,C1,C4",
    ColumnWidths = "45%,15%,0,15%",
    ColumnTitles = { "Description","Area","Key","Filemask" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    Flags = F.PMFLAGS_FULLSCREEN,
  }
  MacroPanelModes = { m2,m1,m2, m1,m2,m1, m2,m1,m2, m1 }
end

local EventPanelModes do
  local m1 = {
    ColumnTypes = "N,C0",
    ColumnWidths = "60%,0",
    ColumnTitles = { "Description", "Group" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    Flags = 0,
  }
  local m2 = {
    ColumnTypes = "N,C0,C4",
    ColumnWidths = "0,20%,20%",
    ColumnTitles = { "Description","Group","Filemask" },
    StatusColumnTypes = "N",
    StatusColumnWidths = "0",
    Flags = F.PMFLAGS_FULLSCREEN,
  }
  EventPanelModes = { m2,m1,m2, m1,m2,m1, m2,m1,m2, m1 }
end

function export.GetOpenPanelInfo (object, handle)
--far.MacroPost[[print"."]]
  return {
    Flags            = OpenPanelInfoFlags,
    PanelTitle       = ("%s (%s)"):format(Title, object.type),
    PanelModesArray  = object.type=="macros" and MacroPanelModes or EventPanelModes,
    PanelModesNumber = 10,
    StartPanelMode   = Settings.LastPanelMode,
    StartSortMode    = Settings.LastSortMode,
    StartSortOrder   = Settings.LastSortOrder,
    ShortcutData     = object.type,
  }
end

function export.Compare (object, handle, Item1, Item2, Mode)
  local r
  if object.type == "macros" then
    if Mode == F.SM_EXT then
      r = LStricmp(Item1.CustomColumnData[P_AREA], Item2.CustomColumnData[P_AREA])
      if r ~= 0 then return r end
      r = LStricmp(Item1.FileName, Item2.FileName)
      if r ~= 0 then return r end
      return LStricmp(Item1.CustomColumnData[P_KEY], Item2.CustomColumnData[P_KEY])
    elseif Mode == F.SM_MTIME then
      r = LStricmp(Item2.CustomColumnData[P_KEY], Item1.CustomColumnData[P_KEY]) -- order changed on purpose
      if r ~= 0 then return r end
      r = LStricmp(Item2.FileName, Item1.FileName)
      if r ~= 0 then return r end
      return LStricmp(Item2.CustomColumnData[P_AREA], Item1.CustomColumnData[P_AREA])
    else
      r = LStricmp(Item1.FileName, Item2.FileName)
      if r ~= 0 then return r end
      r = LStricmp(Item1.CustomColumnData[P_AREA], Item2.CustomColumnData[P_AREA])
      if r ~= 0 then return r end
      return LStricmp(Item1.CustomColumnData[P_KEY], Item2.CustomColumnData[P_KEY])
    end

  elseif object.type == "events" then
    if Mode == F.SM_EXT then
      r = LStricmp(Item1.CustomColumnData[P_GROUP], Item2.CustomColumnData[P_GROUP])
      if r ~= 0 then return r end
      return LStricmp(Item1.FileName, Item2.FileName)
    else
      r = LStricmp(Item1.FileName, Item2.FileName)
      if r ~= 0 then return r end
      return LStricmp(Item1.CustomColumnData[P_GROUP], Item2.CustomColumnData[P_GROUP])
    end
  end

end

function export.ProcessPanelEvent (object, handle, Event, Param)
  if Event == F.FE_IDLE then
    panel.UpdatePanel(handle,nil,true)
    panel.RedrawPanel(handle)
  elseif Event == F.FE_CHANGEVIEWMODE then
    local info = panel.GetPanelInfo(handle)
    Settings.LastPanelMode = tostring(info.ViewMode):byte()
  elseif Event == F.FE_CHANGESORTPARAMS then
    local info = panel.GetPanelInfo(handle)
    Settings.LastSortMode = info.SortMode
    Settings.LastSortOrder = band(info.Flags,F.PFLAGS_REVERSESORTORDER)==0 and 0 or 1
  end
end

function export.ProcessPanelInput (object, handle, Rec)
  if not (Rec.EventType==F.KEY_EVENT and Rec.KeyDown) then return end

  local Key = Rec.VirtualKeyCode
  local ALT  = bor(F.LEFT_ALT_PRESSED, F.RIGHT_ALT_PRESSED)
  local CTRL = bor(F.LEFT_CTRL_PRESSED, F.RIGHT_CTRL_PRESSED)
  local A = (0 ~= band(Rec.ControlKeyState, ALT))
  local C = (0 ~= band(Rec.ControlKeyState, CTRL))
  local S = (0 ~= band(Rec.ControlKeyState, F.SHIFT_PRESSED))

  -- suppress the silly Far error message
  if not (A or C or S) and Key == VK.F7 then
    return true
  end

  -- F3:view or F4:edit macrofile
  if not (A or C or S) and (Key==VK.F3 or Key==VK.CLEAR or Key==VK.F4) then
    local item = panel.GetCurrentPanelItem(handle)
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      local flags = bor(F.EF_NONMODAL, F.EF_IMMEDIATERETURN, F.EF_ENABLE_F6)
      local ret = editor.Editor(cdata[P_FILENAME], nil,nil,nil,nil,nil, flags, cdata[P_STARTLINE])
      if Key ~= VK.F4 and ret == F.EEC_MODIFIED then
        --editor.SetPosition(nil, { TopScreenLine = math.max(1,startline-4) })
        far.MacroPost[[Keys"F6"]] -- a trick for proper setting position in viewer
      end
    end

  -- AltShiftF3: go to macrofile in passive panel
  elseif (A and not C and S) and Key == VK.F3 then
    local item = panel.GetCurrentPanelItem(handle)
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      if LocateFile(cdata[P_FILENAME], 0) then
        panel.SetActivePanel(nil, 0)
      end
      return true
    end

  -- CtrlPgUp: go to macrofile in active panel
  elseif (not A and C and not S) and (Key==VK.PRIOR or Key==VK.NUMPAD9) then
    local item = panel.GetCurrentPanelItem(handle)
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      LocateFile(cdata[P_FILENAME], 1)
      return true
    end

  end
end

function export.GetFiles (object, handle, PanelItems, Move, DestPath, OpMode)
  -- quick view
  if 0 ~= band(OpMode, F.OPM_QUICKVIEW) then
    local item = PanelItems[1]
    local cdata = item.CustomColumnData
    if cdata and cdata[P_FILENAME] then
      return win.CopyFile(cdata[P_FILENAME], DestPath.."\\"..item.FileName) and 1 or 0
    end
  end
end

function export.ClosePanel (object, handle)
  SaveSettings()
end

-- function export.ExitFAR()
--   SaveSettings()
-- end
