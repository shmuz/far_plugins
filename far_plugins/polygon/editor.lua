-- editor.lua
-- luacheck: globals ErrMsg

local sql3 = require "lsqlite3"
local F = far.Flags

local Params = ...
local M        = Params.M
local sqlite   = Params.sqlite
local exporter = Params.exporter


-- This file's module. Could not be called "editor" due to existing LuaFAR global "editor".
local myeditor = {}
local mt_editor = {__index=myeditor}


function myeditor.neweditor(dbx, table_name, rowid_name)
  local self = setmetatable({}, mt_editor)
  self._dbx = dbx
  self._table_name = table_name or ""
  self._rowid_name = rowid_name
  return self
end


function myeditor:edit_item(handle)
  -- Get edited row id
  local item = panel.GetCurrentPanelItem(handle)
  if not item or item.FileName == ".." then return; end

  local row_id = tostring(item.AllocationSize)
  local query = ("select * from %s where %s=%s"):format(
                self._table_name:normalize(), self._rowid_name, row_id)
  local stmt = self._dbx:db():prepare(query)
  if stmt and stmt:step() == sql3.ROW then
    -- Read current row data
    -- struct field { colname=nm; coltype=tp; value=v; }
    local db_data = {}
    local col_num = stmt:columns()
    for i = 0, col_num-1 do
      local f = { value="" }
      f.colname = stmt:get_name(i)
      local tp = stmt:get_column_type(i) -- type of data stored in the cell (1...5)
    --local tp2 = stmt:get_type(i) -- type of column definition (as it declared in CREATE TABLE)
    --far.Show(tp,tp2)
      f.coltype = tp
      if tp==sql3.NULL then f.value = nil
      else                  f.value = exporter.get_text(stmt,i,true)
      end
      table.insert(db_data, f)
    end
    stmt:finalize()

    if self:dialog(db_data, row_id) then
      panel.UpdatePanel(handle)
      panel.RedrawPanel(handle)
    end
  else
    if stmt then stmt:finalize() end
    ErrMsg(M.ps_err_read .. "\n" .. self._dbx:last_error())
  end
end


function myeditor:insert_item(handle)
  local db_data = {}

  -- Get columns description
  local columns_descr = self._dbx:read_column_description(self._table_name)
  if not columns_descr then
    ErrMsg(M.ps_err_read.."\n"..self._dbx:last_error())
    return
  end
  for _,v in ipairs(columns_descr) do
    local f = { colname=v.name, coltype=v.type, value="" }
    if f.coltype == sql3.BLOB then
      f.coltype = sql3.TEXT  -- Allow edit
    end
    table.insert(db_data, f)
  end

  if self:dialog(db_data, nil) then
    panel.UpdatePanel(handle, nil, true)
    panel.RedrawPanel(handle, nil)
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
  local nulltext = "<NULL>"
  local dlg_items = {}
  local title = row_id and M.ps_edit_row_title or M.ps_insert_row_title
  table.insert(dlg_items, {F.DI_DOUBLEBOX, edge_space, 1, edge_space+dblbox_width-1, dlg_height-2,
               0, 0, 0, 0, title })

  for i,v in ipairs(db_data) do
    local readonly = (v.coltype == sql3.BLOB or v.coltype == sql3.NULL)
    local label, field = myeditor.create_row_control(
      v.colname, v.value or nulltext, i+1, label_maxw, value_maxw, readonly)
    table.insert(dlg_items, label)
    table.insert(dlg_items, field)

    field.coltype  = v.coltype
    field.colname  = v.colname
    field.value    = v.value
    field.prev     = v.value
    field.readonly = readonly
  end

  table.insert(dlg_items, {F.DI_TEXT,   0,dlg_height-4,0,0, 0,0,0,F.DIF_SEPARATOR, ""})
  table.insert(dlg_items, {F.DI_BUTTON, 0,dlg_height-3,0,0, 0,0,0,
                                                F.DIF_CENTERGROUP+F.DIF_DEFAULTBUTTON,M.ps_save})
  table.insert(dlg_items, {F.DI_BUTTON, 0,dlg_height-3,0,0, 0,0,0,F.DIF_CENTERGROUP,M.ps_cancel})

  local id_save = #dlg_items-1

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_EDITCHANGE then
      dlg_items[Param1].modified = true

    elseif Msg == F.DN_CONTROLINPUT and Param2.EventType == F.KEY_EVENT then
      local id = hDlg:send(F.DM_GETFOCUS)
      local item = dlg_items[id]
      if item[1]==F.DI_EDIT and far.InputRecordToName(Param2)=="CtrlN" then
        if item.value then
          -- set to NULL
          item.prev = item.value
          item.value = nil
          item[9] = F.DIF_READONLY
          item[10] = nulltext
          item.modified = (item.coltype ~= sql3.NULL)
        else
          -- restore
          item.value = item.prev or ""
          item[9] = item.coltype==sql3.BLOB and F.DIF_READONLY or 0
          item[10] = item.prev or ""
          item.prev = nil
          item.modified = (item.coltype == sql3.NULL)
        end
        far.SetDlgItem(hDlg, id, item)
      end

    elseif Msg == F.DN_CLOSE and Param1 == id_save then
      local out = {}
      for index,item in ipairs(dlg_items) do
        if item[1] == F.DI_EDIT then
          if (not row_id) or item.modified then
            table.insert(out, {
              --coltype = item.coltype;
              coltype = sql3.TEXT;
              colname = item.colname;
              value = item.value and hDlg:send(F.DM_GETTEXT, index)
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
  local dlg = far.DialogInit(guid, -1, -1, dlg_width, dlg_height, "EditInsertRow", dlg_items, nil, DlgProc)
  local rc = far.DialogRun(dlg)
  far.DialogFree(dlg)
  return rc == id_save
end


function myeditor:remove(items, items_count)
  if items_count == 1 and items[1].FileName == ".." then
    return false
  end

  local guid = win.Uuid("4472C7D8-E2B2-46A0-A005-B10B4141EBBD") -- for macros
  if far.Message(M.ps_drop_question, M.ps_title_short, ";YesNo", "w", nil, guid) ~= 1 then
    return false
  end

  if self._table_name == "" then
    for i=1, items_count do
      local query = "drop "
      local tp = items[i].AllocationSize
      if     tp == sqlite.ot_master  then query = query .. "table"
      elseif tp == sqlite.ot_table   then query = query .. "table"
      elseif tp == sqlite.ot_view    then query = query .. "view"
      elseif tp == sqlite.ot_index   then query = query .. "index"
      elseif tp == sqlite.ot_trigger then query = query .. "trigger"
      else query = nil
      end
      if query then
        query = query .. " " .. items[i].FileName:normalize() .. ";"
        if not self._dbx:execute_query(query) then
          local err_descr = self._dbx:last_error()
          ErrMsg(M.ps_err_sql.."\n"..query.."\n"..err_descr)
          break
        end
      end
    end
  else
    local query_start = ("delete from %s where %s in ("):format(
                          self._table_name:normalize(), self._rowid_name)
    local db = self._dbx:db()

    db:exec("BEGIN TRANSACTION;")
    local cnt = 0
    while cnt < items_count do
      local tt = {}
      local upper = math.min(cnt+1000, items_count) -- process up to 1000 rows at a time
      for i = cnt+1, upper do tt[i-cnt] = items[i].AllocationSize; end
      local query = query_start .. table.concat(tt, ",") .. ")"

      if not self._dbx:execute_query(query) then
        local err_descr = self._dbx:last_error()
        ErrMsg(M.ps_err_sql.."\n"..query.."\n"..err_descr)
        break
      end
      cnt = upper
    end
    if db:exec("END TRANSACTION;") ~= sql3.OK then
      local msg = M.ps_err_sql.."\n"..self._dbx:last_error()
      db:exec("ROLLBACK TRANSACTION;")
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
    query = "update "..self._table_name:normalize().." set "
    for i,v in ipairs(db_data) do
      if i>1 then query = query..',' end
      query = query..v.colname:normalize().."=?"
    end
    query = query.." where "..self._rowid_name.."="..row_id

  else
    -- Insert query
    query = "insert into "..self._table_name:normalize().." ("
    for i,v in ipairs(db_data) do
      if i>1 then query = query.."," end
      query = query .. v.colname:normalize()
    end
    query = query .. ") values ("
    for i = 1, #db_data do
      if i>1 then query = query.."," end
      query = query .. "?"
    end
    query = query .. ")"
  end

  local db = self._dbx:db()
  local stmt = db:prepare(query)
  if not stmt then
    ErrMsg(self._dbx:last_error(), M.ps_err_sql)
    return false
  end

  for idx,v in ipairs(db_data) do
    local bind_rc
    if v.value == nil then
      bind_rc = stmt:bind(idx, nil)
    elseif v.coltype == sql3.FLOAT then
      bind_rc = stmt:bind(idx, tonumber(v.value) or v.value)
    elseif v.coltype == sql3.INTEGER then
      bind_rc = stmt:bind(idx, tonumber(v.value) or v.value)
    else
      bind_rc = stmt:bind(idx, v.value)
    end
    if bind_rc ~= sql3.OK then
      stmt:finalize()
      ErrMsg(self._dbx:last_error(), M.ps_err_sql)
      return false
    end
  end
  if stmt:step() ~= sql3.DONE then
    stmt:finalize()
    ErrMsg(self._dbx:last_error(), M.ps_err_sql)
    return false
  end
  stmt:finalize()
  return true
end


function myeditor.create_row_control(name, value, poz_y, width_name, width_val, readonly)
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
  field[9]  = readonly and F.DIF_READONLY or 0
  field[10] = value

  return label, field
end


return myeditor
