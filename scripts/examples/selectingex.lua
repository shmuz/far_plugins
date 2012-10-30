-- coding=UTF-8
-- Started: August 2011
-- Used portions of code by SimSU (see bottom part of the file)

local F = far.Flags
local band, bor, bnot = bit64.band, bit64.bor, bit64.bnot
local patternExt = "%.[^.]+$"

local items = {
  { text = "&C Копировать",       act = "clipCopy" },
  { text = "&M Пометить",         act = "clipSelect" },
  { text = "&R Снять пометку",    act = "clipDeselect" },
  { text = "&S Синхронизировать", act = "syncPanels" },
  { text = "&A +Имена",           act = "selectByName" },
  { text = "&T +Расширения",      act = "selectByExt" },
  { text = "&B -Имена",           act = "deselectByName" },
  { text = "&U -Расширения",      act = "deselectByExt" },
  { text = "&F Первый",           act = "jumpFirst" },
  { text = "&P Предыдущий",       act = "jumpPrevious" },
  { text = "&N Следующий",        act = "jumpNext" },
  { text = "&L Последний",        act = "jumpLast" },
  { text = "&+ Выделить",         act = "dialogSelect" },
  { text = "&- Снять выделение",  act = "dialogDeselect" }
}

local item = far.Menu({Title="Пометка файлов", Flags="FMENU_WRAPMODE"}, items)
if not item then return end

local APanel = panel.GetPanelInfo(nil, 1)

local function jump (from, to, step)
  if APanel.SelectedItemsNumber > 0 then
    for i = from, to, step do
      local item = panel.GetPanelItem(nil, 1, i)
      if band(item.Flags, F.PPIF_SELECTED) ~= 0 then
        local bottomItem = APanel.TopPanelItem + APanel.PanelRect.bottom - APanel.PanelRect.top
        local topItem = (i>=APanel.TopPanelItem and i<=bottomItem) and APanel.TopPanelItem or nil
        panel.RedrawPanel(nil, 1, { CurrentItem=i, TopPanelItem=topItem })
        break
      end
    end
  end
end

if item.act=="clipCopy" then
  far.MacroPost("Keys'CtrlShiftIns'")

elseif item.act=="clipSelect" or item.act=="clipDeselect" then
  local clip = far.PasteFromClipboard()
  if clip then
    local select = (item.act=="clipSelect")
    local in_clip = {}
    for nm in clip:gmatch("[^\r\n]+") do
      in_clip[regex.gsub(nm, '^"|"$', ''):lower()] = true
    end
    for i=1,APanel.ItemsNumber do
      local item = panel.GetPanelItem(nil, 1, i)
      if in_clip[item.FileName:lower()] then
        panel.SetSelection(nil, 1, i, select)
      end
    end
  end

elseif item.act=="syncPanels" then
  local PPanel = panel.GetPanelInfo(nil, 0)
  if band(PPanel.Flags, F.PFLAGS_VISIBLE) ~= 0 then
    local in_active = {}
    for i=1,APanel.ItemsNumber do
      local item = panel.GetPanelItem(nil, 1, i)
      in_active[item.FileName:lower()] = i
      panel.SetSelection(nil, 1, i, false)
    end
    for i=1,PPanel.ItemsNumber do
      local item = panel.GetPanelItem(nil, 0, i)
      local j = in_active[item.FileName:lower()]
      if j then
        panel.SetSelection(nil, 1, j, true)
        panel.SetSelection(nil, 0, i, true)
      else
        panel.SetSelection(nil, 0, i, false)
      end
    end
  end

elseif item.act=="selectByName" or item.act=="deselectByName" then
  local function getname(str)
    return str:gsub("^.*\\", ""):gsub(patternExt, ""):lower()
  end
  local select = (item.act=="selectByName")
  local name = getname(panel.GetCurrentPanelItem(nil, 1).FileName)
  for i=1,APanel.ItemsNumber do
    local nm = getname(panel.GetPanelItem(nil, 1, i).FileName)
    if nm == name then panel.SetSelection(nil, 1, i, select) end
  end

elseif item.act=="selectByExt" or item.act=="deselectByExt" then
  local select = (item.act=="selectByExt")
  local Ext = panel.GetCurrentPanelItem(nil, 1).FileName:match(patternExt)
  Ext = Ext and Ext:lower()
  for i=1,APanel.ItemsNumber do
    local item = panel.GetPanelItem(nil, 1, i)
    local ext = item.FileName:match(patternExt)
    ext = ext and ext:lower()
    if ext == Ext then panel.SetSelection(nil, 1, i, select) end
  end

elseif item.act=="jumpFirst"      then jump(1, APanel.ItemsNumber, 1)
elseif item.act=="jumpPrevious"   then jump(APanel.CurrentItem-1, 1, -1)
elseif item.act=="jumpNext"       then jump(APanel.CurrentItem+1, APanel.ItemsNumber, 1)
elseif item.act=="jumpLast"       then jump(APanel.ItemsNumber, 1, -1)

elseif item.act=="dialogSelect"   then far.MacroPost("Keys'Add'")
elseif item.act=="dialogDeselect" then far.MacroPost("Keys'Subtract'")

end

--[[
%comment="Работа с выделением файлов, аля SectingEx. © SimSU";
%comment="Назначается, например, на CtrlShiftS";
%item=Menu.Show("&C Копировать\n&M Пометить\n&R Снять пометку\n&S Синхронизировать\n&A +Имена\n&T +Расширения\n&B -Имена\n&U -Расширения\n&F Первый\n&P Предыдущий\n&N Следующий\n&L Последний\n&+ Выделить\n&- Снять выделение", "Пометка файлов", 0);
$IF (%item=="&C Копировать")  CtrlShiftIns
$ELSE $IF (%item=="&M Пометить") panel.select(0,1,2,clip(0))
$ELSE $IF (%item=="&R Снять пометку") panel.select(0,0,2,clip(0))
$ELSE $IF (%item=="&S Синхронизировать")
  $IF (PPanel.Visible)
    %CT=Clip(5,2); %CV=Clip(0);
    panel.select(0,1)
    CtrlShiftIns
    panel.select(0,0)
    %ASelFiles=Clip(0);
    panel.select(1,1)
    tab CtrlShiftIns tab
    panel.select(1,0)
    %PSelFiles=Clip(0);
    Clip(1,%CV) Clip(5,%CT)
    panel.select(0,1,2,%PSelFiles)
    panel.select(1,1,2,%ASelFiles)
  $END
$ELSE $IF (%item=="&A +Имена") AltAdd
$ELSE $IF (%item=="&T +Расширения") CtrlAdd
$ELSE $IF (%item=="&B -Имена") AltSubtract
$ELSE $IF (%item=="&U -Расширения") CtrlSubtract
$ELSE $IF (%item=="&F Первый") panel.setposidx(0,1,1)
$ELSE $IF (%item=="&P Предыдущий")
  %i=APanel.CurPos-1;
  $WHILE ((%i>0)&&(!panel.item(0, %i, 8))) %i=%i-1; $END
  $IF (%i>0) panel.setposidx(0, %i) $END
$ELSE $IF (%item=="&N Следующий")
  %c=APanel.ItemCount;
  %i=APanel.CurPos+1;
  $WHILE ((%i<=%c)&&(!panel.item(0, %i, 8))) %i=%i+1; $END
  $IF (%i<=%c) panel.setposidx(0, %i) $END
$ELSE $IF (%item=="&L Последний") panel.setposidx(0,APanel.SelCount,1)
$ELSE $IF (%item=="&+ Выделить") Add
$ELSE $IF (%item=="&- Снять выделение") Subtract
$END $END $END $END $END $END $END $END $END $END $END $END $END $END
]]
