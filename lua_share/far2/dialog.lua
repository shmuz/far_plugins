-- Dialog module

local F = far.Flags
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
  Type=1, X1=2, Y1=3, X2=4, Y2=5,
  Selected=6, ListItems=6, VBuf=6,
  History=7, Mask=8, Flags=9, Data=10, MaxLength=11, UserData=12
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

function item_map:GetCheckState (hDlg)
  return SendDlgMessage(hDlg,"DM_GETCHECK",self.id,0)
end

function item_map:GetCheck (hDlg)
  return (1 == self:GetCheckState(hDlg))
end

function item_map:SaveCheck (hDlg, tData)
  local v = self:GetCheckState(hDlg)
  tData[self.name] = (v > 1) and v or (v == 1)
end

function item_map:SetCheck (hDlg, check)
  SendDlgMessage(hDlg, "DM_SETCHECK", self.id, tonumber(check) or (check and 1) or 0)
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

function item_map:SetListCurPos (hDlg, pos)
  return SendDlgMessage(hDlg, "DM_LISTSETCURPOS", self.id, {SelectPos=pos})
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
        item.id = #self+1 --> id is 1-based
        setmetatable (item, item_meta)
        rawset (self, #self+1, item) -- table.insert (self, item)
        self[mapkey][item_name] = item
      end,

  __index = function (self, key) return rawget (self, mapkey)[key] end
}


-- Dialog constructor
local function NewDialog ()
  return setmetatable ({ [mapkey]={} }, dialog_meta)
end

local function LoadData (aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautoload or item._noauto) then
      local v = aData[item.name]
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
        item[6] = v==nil and (item[6] or 0) or v==false and 0 or tonumber(v) or 1
      elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
        item[10] = v or item[10] or ""
      elseif CheckItemType(item, "DI_LISTBOX", "DI_COMBOBOX") then
        if v and v.SelectIndex then
          item[6].SelectIndex = v.SelectIndex
        end
      end
    end
  end
end

local function SaveData (aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautosave or item._noauto) then
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
        local v = item[6]
        aData[item.name] = (v > 1) and v or (v == 1)
      elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
        aData[item.name] = item[10]
      elseif CheckItemType(item, "DI_LISTBOX", "DI_COMBOBOX") then
        aData[item.name] = aData[item.name] or {}
        aData[item.name].SelectIndex = item[6].SelectIndex
      end
    end
  end
end

local function LoadDataDyn (hDlg, aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautoload or item._noauto) then
      local name = item.name
      if aData[name] ~= nil then
        if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
          aDialog[name]:SetCheck(hDlg, aData[name])
        elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
          aDialog[name]:SetText(hDlg, aData[name])
        end
      end
    end
  end
end

local function SaveDataDyn (hDlg, aDialog, aData)
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

return {
  CheckItemType = CheckItemType,
  NewDialog = NewDialog,
  LoadData = LoadData,
  SaveData = SaveData,
  LoadDataDyn = LoadDataDyn,
  SaveDataDyn = SaveDataDyn,
}

-- Adding item example:
-- dlg = dialog.NewDialog()
-- dlg.cbxCase = { "DI_CHECKBOX",  10,4,0,0,  0,"","",0,"&Case sensitive" }
