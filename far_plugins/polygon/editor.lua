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


function myeditor:update()
  -- Get edited row id
  local item = panel.GetCurrentPanelItem(nil, 1)
  if not item or item.FileName == ".." then return; end

  local row_id = tostring(item.AllocationSize)

  local db_data = {}
  local query = ("select * from %s where %s=%s"):format(self._table_name:normalize(),
                                                        self._rowid_name, row_id)
  local db = self._dbx:db()
  local stmt = db:prepare(query)
  if not stmt or stmt:step() ~= sql3.ROW then
    if stmt then stmt:finalize() end
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return
  end

  -- Read current row data
     -- struct sq_column {
     --   wstring name;        ///< Name
     --   col_type type;        ///< Type
     -- };
     ---- struct field {
     ----   sqlite::sq_column column;
     ----   wstring value;
     ---- };
  local col_num = stmt:columns()
  for i = 0, col_num-1 do
    local f = { column={}, value="" }
    f.column.name = stmt:get_name(i)
    local tp = stmt:get_column_type(i)
    if     tp == sql3.INTEGER then f.column.type = sqlite.ct_integer
    elseif tp == sql3.FLOAT   then f.column.type = sqlite.ct_float
    elseif tp == sql3.TEXT    then f.column.type = sqlite.ct_text
    else                           f.column.type = sqlite.ct_blob
    end

    f.value = exporter.get_text(stmt, i)
    table.insert(db_data, f)
  end
  stmt:finalize()

  local newdata = myeditor.edit(db_data, false)
  if newdata and self:exec_update(row_id, newdata) then
    panel.UpdatePanel(nil, 1)
    panel.RedrawPanel(nil, 1)
  end
end


function myeditor:insert()
  local db_data = {}

  -- Get columns description
  local columns_descr = self._dbx:read_column_description(self._table_name)
  if not columns_descr then
    ErrMsg(M.ps_err_read.."\n"..self._dbx:last_error())
    return
  end
  for _,v in ipairs(columns_descr) do
    local f = { column=v, value="" }
    if f.column.type == sqlite.ct_blob then
      f.column.type = sqlite.ct_text  -- Allow edit
    end
    table.insert(db_data, f)
  end

  local newdata = myeditor.edit(db_data, true)
  if newdata and self:exec_update(nil, newdata) then
    panel.UpdatePanel(nil, 1, true)
    panel.RedrawPanel(nil, 1)
  end
end


function myeditor.edit(db_data, create_mode)
  -- Calculate dialog's size
  local max_wnd_width = 80
  local rc_far_wnd = far.AdvControl("ACTL_GETFARRECT")
  if rc_far_wnd then
    max_wnd_width = rc_far_wnd.Right + 1
  end
  local max_label_length = 0
  local max_value_length = 0
  for _,v in ipairs(db_data) do
    local label_len = v.column.name:len()
    local value_len = v.value:len()
    if max_label_length < label_len then
      max_label_length = label_len
    end
    if max_value_length < value_len then
      max_value_length = value_len
    end
  end
  if max_value_length < 40 then
    max_value_length = 40
  end
  if max_value_length + max_label_length + 12 > max_wnd_width then
    max_value_length = max_wnd_width - max_label_length - 12
  end
  local dlg_height = 6 + #db_data
  local dlg_width = 12 + max_label_length + max_value_length
  if dlg_width < 30 then
    dlg_width = 30
  end

  -- Build dialog
  local dlg_items = {}

  local title = create_mode and M.ps_insert_row_title or M.ps_edit_row_title
  local dlg_item = {F.DI_DOUBLEBOX, 3,1,dlg_width-4,dlg_height-2, 0,0,0,0, title }
  table.insert(dlg_items, dlg_item)

  local editor_fields = {}
  local y_pos = 2
  for i,v in ipairs(db_data) do
    local val = v.value
    local row_ctl = myeditor.create_row_control(v.column.name, val, y_pos, max_label_length,
                    max_value_length, v.column.type == sqlite.ct_blob)
    y_pos = y_pos + 1
    if i == 1 then
      row_ctl.field[9] = bit64.bor(row_ctl.field[9], F.DIF_FOCUS)
    end
    table.insert(dlg_items, row_ctl.label)
    table.insert(dlg_items, row_ctl.semi)
    table.insert(dlg_items, row_ctl.field)
    table.insert(editor_fields, { colname=v.column.name, index=#dlg_items })
  end

  dlg_item = {F.DI_TEXT, 0,dlg_height-4,0,0, 0,0,0,F.DIF_SEPARATOR, ""}
  table.insert(dlg_items, dlg_item)
  dlg_item = {F.DI_BUTTON, 0,dlg_height-3,0,0, 0,0,0,F.DIF_CENTERGROUP+F.DIF_DEFAULTBUTTON,M.ps_save}
  table.insert(dlg_items, dlg_item)
  dlg_item = {F.DI_BUTTON, 0,dlg_height-3,0,0, 0,0,0,F.DIF_CENTERGROUP,M.ps_cancel}
  table.insert(dlg_items, dlg_item)

  local guid = win.Uuid("866927E1-60F1-4C87-A09D-D481D4189534")
  local dlg = far.DialogInit(guid, -1, -1, dlg_width, dlg_height, nil, dlg_items)
  local rc = far.DialogRun(dlg)
  if rc < 1 or rc == #dlg_items --[[ cancel ]] then
    far.DialogFree(dlg)
    return false
  end

  -- Get changed data
  local out = {}
  for _,v in ipairs(editor_fields) do
    if far.SendDlgMessage(dlg, F.DM_EDITUNCHANGEDFLAG, v.index, -1) == 0 then
      local f = { column={} }
      f.column.name = v.colname
      f.value = far.SendDlgMessage(dlg, F.DM_GETTEXT, v.index)
      table.insert(out, f)
    end
  end

  far.DialogFree(dlg)
  return #out > 0 and out
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
      if     items[i].AllocationSize == sqlite.ot_table then query = query .. "table"
      elseif items[i].AllocationSize == sqlite.ot_view  then query = query .. "view"
      elseif items[i].AllocationSize == sqlite.ot_index then query = query .. "index"
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
    local query = ("delete from %s where %s in ("):format(self._table_name:normalize(),
                                                          self._rowid_name)
    for i = 1, items_count do
      if i > 1 then query = query .. "," end
      query = query .. items[i].AllocationSize
    end
    query = query .. ")"

    if not self._dbx:execute_query(query) then
      local err_descr = self._dbx:last_error()
      ErrMsg(M.ps_err_sql.."\n"..query.."\n"..err_descr)
    end
  end

  return true
end


function myeditor:exec_update(row_id, db_data) -- !!! 'db_data' is in/out !!!
  local query

  if row_id and row_id ~= "" then
    -- Update query
    query = "update "..self._table_name:normalize().." set "
    for i,v in ipairs(db_data) do
      if i>1 then query = query..',' end
      query = query..v.column.name:normalize().."=?"
    end
    query = query.." where "..self._rowid_name.."="..row_id
  else
    -- Insert query
    query = "insert into "..self._table_name:normalize().." ("
    for i,v in ipairs(db_data) do
      if i>1 then query = query.."," end
      query = query .. v.column.name:normalize()
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
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_sql.."\n"..err_descr)
    return false
  end
  local idx = 0
  for _,v in ipairs(db_data) do
    idx = idx + 1
    local bind_rc
    if v.column.type == sqlite.ct_float then
      bind_rc = stmt:bind(idx, tonumber(v.value))
    elseif v.column.type == sqlite.ct_integer then
      bind_rc = stmt:bind(idx, tonumber(v.value))
    else
      bind_rc = stmt:bind(idx, v.value)
    end
    if bind_rc ~= sql3.OK then
      stmt:finalize()
      local err_descr = self._dbx:last_error()
      ErrMsg(M.ps_err_sql.."\n"..err_descr)
      return false
    end
  end
  if stmt:step() ~= sql3.DONE then
    stmt:finalize()
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_sql.."\n"..err_descr)
    return false
  end
  stmt:finalize()
  return true
end


function myeditor.create_row_control(name, value, poz_y, width_name, width_val, ro)
  local rc = {label={}, semi={}, field={}}
  for _,v in pairs(rc) do
    for k=1,10 do v[k]=0 end
  end

  rc.label[1] = F.DI_TEXT
  rc.label[2] = 5
  rc.label[4] = 5 + width_name - 1
  rc.label[3] = poz_y
  rc.label[10] = name

  rc.semi[1] = F.DI_TEXT
  rc.semi[2] = rc.label[4] + 1;
  rc.semi[4] = rc.semi[2]
  rc.semi[3] = poz_y
  rc.semi[10] = ":"

  rc.field[1] = F.DI_EDIT
  rc.field[2] = rc.semi[2] + 2
  rc.field[4] = rc.field[2] + width_val - 1
  rc.field[3] = poz_y
  rc.field[10] = value
  if ro then
    rc.field[9] = F.DIF_READONLY
  end

  return rc
end


return myeditor
