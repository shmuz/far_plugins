-- coding: UTF-8

local sql3   = require "lsqlite3"
local M      = require "modules.string_rc"
local sqlite = require "modules.sqlite"
local utils  = require "modules.utils"

local F = far.Flags
local ErrMsg, Norm = utils.ErrMsg, utils.Norm
local NULLTEXT = "NULL"


-- This file's module. Could not be called "editor" due to existing LuaFAR global "editor".
local myeditor = {}
local mt_editor = {__index=myeditor}


function myeditor.neweditor(dbx, schema, table_name, rowid_name)
  local self = setmetatable({}, mt_editor)
  self._dbx = dbx
  self._db = dbx:db()
  self._schema = schema
  self._table_name = table_name
  self._rowid_name = rowid_name
  return self
end


function myeditor:edit_item(handle)
  -- Get edited row id
  local item = panel.GetCurrentPanelItem(handle)
  if not item or item.FileName == ".." then return; end

  local row_id = tostring(item.AllocationSize)
  local query = ("select * from %s.%s where %s=%s"):format(
                Norm(self._schema), Norm(self._table_name), self._rowid_name, row_id)
  local stmt = self._db:prepare(query)
  if stmt then
    if stmt:step() == sql3.ROW then
      -- Read current row data
      local db_data = {}
      for i = 0, stmt:columns()-1 do
        local f = {
          colname = stmt:get_name(i);
          coltype = stmt:get_column_type(i);
          value = nil;
        }
        if f.coltype == sql3.NULL then
          f.value = NULLTEXT
        elseif f.coltype == sql3.INTEGER or f.coltype == sql3.FLOAT then
          f.value = stmt:get_column_text(i)
        elseif f.coltype == sql3.TEXT then
          f.value = Norm(stmt:get_column_text(i))
        elseif f.coltype == sql3.BLOB then
          local s = string.gsub(stmt:get_value(i), ".",
            function(c)
              return string.format("%02x", string.byte(c))
            end)
          f.value = "x'" .. s .. "'"
        end
        table.insert(db_data, f)
      end

      if self:dialog(db_data, row_id) then
        panel.UpdatePanel(handle)
        panel.RedrawPanel(handle)
      end
    else
      ErrMsg(M.ps_err_read .. "\n" .. self._dbx:last_error())
    end
    stmt:finalize()
  end
end


function myeditor:insert_item(handle)
  local columns_descr = self._dbx:read_column_description(self._schema, self._table_name)
  if columns_descr then
    local db_data = {}
    for _,v in ipairs(columns_descr) do
      local f = {
        colname = v.name;
        coltype = sql3.NULL;
        value = NULLTEXT;
      }
      table.insert(db_data, f)
    end

    if self:dialog(db_data, nil) then
      panel.UpdatePanel(handle, nil, true)
      panel.RedrawPanel(handle, nil)
    end
  end
end


function myeditor:dialog(db_data, row_id)
  -- Calculate dialog's size
  local rect = far.AdvControl("ACTL_GETFARRECT")
  local dlg_maxw   = rect and (rect.Right - rect.Left + 1) or 80
  local reserved   = 5 -- 2=box + 3=space-delimiters
  local edge_space = 3 -- horisontal spaces (3 from each side) - do not change (problems with separators)
  local label_maxw = 0
  local value_maxw = math.floor(dlg_maxw / 2)

  for _,v in ipairs(db_data) do
    label_maxw = math.max(label_maxw, v.colname:len())
  end
  label_maxw = math.min(label_maxw, dlg_maxw - value_maxw - reserved)

  local dblbox_width = label_maxw + value_maxw + reserved
  local dlg_width    = dblbox_width + 2*edge_space
  local dlg_height   = 6 + #db_data

  -- Build dialog
  local dlg_items = {}
  local title = row_id and M.ps_edit_row_title or M.ps_insert_row_title
  table.insert(dlg_items, {F.DI_DOUBLEBOX, edge_space, 1, edge_space+dblbox_width-1, dlg_height-2,
               0, 0, 0, 0, title })

  for i,v in ipairs(db_data) do
    local label, field = myeditor.create_row_control(
      v.colname, v.value or NULLTEXT, i+1, label_maxw, value_maxw)
    table.insert(dlg_items, label)
    table.insert(dlg_items, field)

    field.colname = v.colname
    field.orig    = v.value
  end

  table.insert(dlg_items, {F.DI_TEXT,   0,dlg_height-4,0,0, 0,0,0,F.DIF_SEPARATOR, ""})
  table.insert(dlg_items, {F.DI_BUTTON, 0,dlg_height-3,0,0, 0,0,0,
                                                F.DIF_CENTERGROUP+F.DIF_DEFAULTBUTTON,M.ps_save})
  table.insert(dlg_items, {F.DI_BUTTON, 0,dlg_height-3,0,0, 0,0,0,F.DIF_CENTERGROUP,M.ps_cancel})

  local id_save = #dlg_items-1

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_CONTROLINPUT and Param2.EventType == F.KEY_EVENT then
      local id = hDlg:send(F.DM_GETFOCUS)
      local item = dlg_items[id]
      if item.colname and far.InputRecordToName(Param2)=="CtrlN" then
        local txt = hDlg:send(F.DM_GETTEXT, id)
        if txt:upper() ~= NULLTEXT:upper() then
          hDlg:send(F.DM_SETTEXT, id, NULLTEXT)
        else
          hDlg:send(F.DM_SETTEXT, id, item.orig or "")
        end
      end

    elseif Msg == F.DN_CLOSE and Param1 == id_save then
      local out = {}
      for index,item in ipairs(dlg_items) do
        if item[1] == F.DI_EDIT then
          local txt = hDlg:send(F.DM_GETTEXT, index)
          if (not row_id) or (txt ~= item.orig) then
            table.insert(out, {
              colname = item.colname;
              value = txt;
            })
          end
        end
      end
      if not self:exec_update(row_id, out) then
        return 0
      end
    end
  end

  local guid = win.Uuid("866927E1-60F1-4C87-A09D-D481D4189534")
  local rc = far.Dialog(guid, -1, -1, dlg_width, dlg_height, "EditInsertRow", dlg_items, nil, DlgProc)
  return rc == id_save
end


function myeditor:remove(items)
  local items_count = #items
  if items_count == 1 and items[1].FileName == ".." then
    return false
  end

  local schema_norm = Norm(self._schema)
  if self._table_name == "" then
    for _,item in ipairs(items) do
      local what = nil
      local tp = item.AllocationSize
      if     tp == sqlite.ot_master  then what = "table"
      elseif tp == sqlite.ot_table   then what = "table"
      elseif tp == sqlite.ot_view    then what = "view"
      elseif tp == sqlite.ot_index   then what = "index"
      elseif tp == sqlite.ot_trigger then what = "trigger"
      end
      if what then
        local name_norm = Norm(item.FileName)
        local query = ("drop %s %s.%s;"):format(what, schema_norm, name_norm)
        if not self._dbx:execute_query(query, true) then
          break
        end
      end
    end
  else
    local query_start = ("delete from %s.%s where %s in ("):format(
                          schema_norm, Norm(self._table_name), self._rowid_name)

    self._db:exec("BEGIN TRANSACTION;")
    local cnt = 0
    while cnt < items_count do
      local tt = {}
      local upper = math.min(cnt+1000, items_count) -- process up to 1000 rows at a time
      for i = cnt+1, upper do tt[i-cnt] = items[i].AllocationSize; end
      local query = query_start .. table.concat(tt, ",") .. ")"

      if not self._dbx:execute_query(query, true) then
        break
      end
      cnt = upper
    end
    if self._db:exec("END TRANSACTION;") ~= sql3.OK then
      local msg = self._dbx:last_error().."\n"..M.ps_err_sql
      self._db:exec("ROLLBACK TRANSACTION;")
      ErrMsg(msg)
      return false
    end

  end

  return true
end


function myeditor:exec_update(row_id, db_data)
  local query
  if row_id and row_id ~= "" then
    -- Update query
    if db_data[1] == nil then
      return true -- no changed columns
    end
    query = ("update %s.%s set "):format(Norm(self._schema), Norm(self._table_name))
    for i,v in ipairs(db_data) do
      if i>1 then query = query..',' end
      query = query..Norm(v.colname).."="..v.value
    end
    query = query.." where "..self._rowid_name.."="..row_id

  else
    -- Insert query
    query = ("insert into %s.%s ("):format(Norm(self._schema), Norm(self._table_name))
    for i,v in ipairs(db_data) do
      if i>1 then query = query.."," end
      query = query .. Norm(v.colname)
    end
    query = query .. ") values ("
    for i,v in ipairs(db_data) do
      if i>1 then query = query.."," end
      query = query .. v.value
    end
    query = query .. ")"

  end

  if self._db:exec(query) == sql3.OK then
    return true
  else
    self._dbx:SqlErrMsg(query)
    return false
  end
end


function myeditor.create_row_control(name, value, poz_y, width_name, width_val)
  local label, field = {}, {}
  for k=1,10 do label[k],field[k] = 0,0; end

  local namelen = name:len()
  label[1]  = F.DI_TEXT
  label[2]  = 5
  label[4]  = label[2] + width_name - 1
  label[3]  = poz_y
  label[10] = (namelen <= width_name) and name or (name:sub(1,width_name-3) .. "...")

  field[1]  = F.DI_EDIT
  field[2]  = label[4] + 2
  field[4]  = field[2] + width_val - 1
  field[3]  = poz_y
  field[10] = value

  return label, field
end


return myeditor
