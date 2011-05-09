-- Dialog module

local Package = {}
local F = far.GetFlags()
local SendDlgMessage = far.SendDlgMessage

--------------------------------------------------------------------------------
-- @param item : dialog item (a table)
-- @param ...  : sequence of item types, to check if `item' belongs to any of them
-- @return     : whether `item' belongs to one of the given types (a boolean)
--------------------------------------------------------------------------------
local function CheckItemType(item, ...)
  for i=1,select("#", ...) do
    local tp = select(i, ...)
    if tp==item[1] or F[tp]==item[1] then return true end
  end
  return false
end


-- Bind dialog item names (see struct FarDialogItem) to their indexes.
local item_map = {
  Type=1, X1=2, Y1=3, X2=4, Y2=5, Focus=6,
  Selected=7, History=7, Mask=7, ListItems=7, ListPos=7, VBuf=7,
  Flags=8, DefaultButton=9,
  Data=10, Ptr=10,
}


-- Metatable for dialog items. All writes and reads at keys contained
-- in item_map (see above) are redirected to corresponding indexes.
local item_meta = {
  __index    = function (self, key)
                 local ind = item_map[key]
                 return rawget (self, ind) or ind
               end,
  __newindex = function (self, key, val)
                 rawset (self, item_map[key] or key, val)
               end,
}

function item_map:GetCheck (hDlg)
  return (F.BSTATE_CHECKED==SendDlgMessage(hDlg,"DM_GETCHECK",self.id,0))
end

function item_map:SaveCheck (hDlg, tData)
  tData[self.name] = self:GetCheck(hDlg)
end

function item_map:SetCheck (hDlg, check)
  SendDlgMessage(hDlg, "DM_SETCHECK", self.id,
    check and F.BSTATE_CHECKED or F.BSTATE_UNCHECKED)
end

function item_map:Enable (hDlg, enbl)
  SendDlgMessage(hDlg, "DM_ENABLE", self.id, enbl and 1 or 0)
end

function item_map:GetText (hDlg)
  return SendDlgMessage(hDlg, "DM_GETTEXT", self.id)
end

function item_map:SaveText (hDlg, tData)
  tData[self.name] = self:GetText(hDlg)
end

function item_map:SetText (hDlg, str)
  return SendDlgMessage(hDlg, "DM_SETTEXT", self.id, str)
end

function item_map:GetListCurPos (hDlg)
  local pos = SendDlgMessage(hDlg, "DM_LISTGETCURPOS", self.id, 0)
  return pos.SelectPos
end

-- A key for the "map" (an auxilliary table contained in a dialog table).
-- *  Both dialog and map tables contain all dialog items:
--    the dialog table is an array (for access by index by FAR API),
--    the map table is a dictionary (for access by name from Lua script).
-- *  A unique key is used, to prevent accidental collision with dialog
--    item names.
local mapkey = {}


-- Metatable for dialog.
-- *  When assigning an item to a (string) field of the dialog, the item is also
--    added to the array part.
-- *  Normally, give each item a unique name, though if 2 or more items do not
--    need be accessed by the program via their names, they can share the same
--    name, e.g. "sep" for separator, "lab" for label, or even "_".
local dialog_meta = {
  __newindex =
      function (self, item_name, item)
        item.name = item_name
        item.id = #self --> id is 0-based
        setmetatable (item, item_meta)
        rawset (self, #self+1, item) -- table.insert (self, item)
        self[mapkey][item_name] = item
      end,

  __index = function (self, key) return rawget (self, mapkey)[key] end
}


-- Dialog constructor
function Package.NewDialog ()
  return setmetatable ({ [mapkey]={} }, dialog_meta)
end

function Package.LoadData (aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautoload or item._noauto) then
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
        if aData[item.name] == nil then --> nil==no data; false==valid data
          item[7] = item[7] or 0
        else
          item[7] = aData[item.name] and 1 or 0
        end
      elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
        item[10] = aData[item.name] or item[10] or ""
      elseif CheckItemType(item, "DI_LISTBOX", "DI_COMBOBOX") then
        local SelectIndex = aData[item.name] and aData[item.name].SelectIndex
        if SelectIndex then item[7].SelectIndex = SelectIndex end
      end
    end
  end
end

function Package.SaveData (aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautosave or item._noauto) then
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
        aData[item.name] = (item[7] ~= 0)
      elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
        aData[item.name] = item[10]
      elseif CheckItemType(item, "DI_LISTBOX", "DI_COMBOBOX") then
        aData[item.name] = aData[item.name] or {}
        aData[item.name].SelectIndex = item[7].SelectIndex
      end
    end
  end
end

function Package.LoadDataDyn (hDlg, aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautoload or item._noauto) then
      local name = item.name
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
        aDialog[name]:SetCheck(hDlg, aData[name])
      elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
        aDialog[name]:SetText(hDlg, aData[name])
      end
    end
  end
end

function Package.SaveDataDyn (hDlg, aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautosave or item._noauto) then
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
        aDialog[item.name]:SaveCheck(hDlg, aData)
      elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
        aDialog[item.name]:SaveText(hDlg, aData)
      end
    end
  end
end

return Package

-- Adding item example:
-- dlg = dialog.NewDialog()
-- dlg.cbxCase = { "DI_CHECKBOX", 10, 4, 0, 0, 0, 0, 0, 0, "&Case sensitive" }
