-- coding: UTF-8

local sql3    = require "lsqlite3"
local sdialog = require "far2.simpledialog"
local M       = require "modules.string_rc"
local sqlite  = require "modules.sqlite"
local utils   = require "modules.utils"

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


local function create_row_control(name, value, width_name, width_val)
  local label, edit = {}, {}

  label.tp = "text"
  label.x1 = 5
  label.x2 = label.x1 + width_name - 1
  label.text = (name:len() <= width_name) and name or (name:sub(1,width_name-3) .. "...")

  edit.tp = "edit"
  edit.x1 = label.x2 + 2
  edit.x2 = edit.x1 + width_val - 1
  edit.text = value
  edit.ystep = 0

  return label, edit
end


function myeditor:row_dialog(db_data, row_id)
  -- Calculate dialog's size
  local rect = far.AdvControl("ACTL_GETFARRECT")
  local dlg_maxw   = rect and (rect.Right - rect.Left + 1) or 80
  local reserved   = 5 -- 2=box + 3=space-delimiters
  local label_maxw = 0
  local value_maxw = math.floor(dlg_maxw / 2)

  for _,v in ipairs(db_data) do
    label_maxw = math.max(label_maxw, v.colname:len())
  end
  label_maxw = math.min(label_maxw, dlg_maxw - value_maxw - reserved)

  -- Build dialog
  local title = row_id and M.edit_row_title or M.insert_row_title
  title = utils.lang(title, {self._table_name})
  local Items = {
    guid  = "866927E1-60F1-4C87-A09D-D481D4189534";
    help  = "EditInsertRow";
    width = label_maxw + value_maxw + reserved;
    [1]   = { tp="dbox"; text=title; }
  }

  for _,v in ipairs(db_data) do
    local label, edit = create_row_control(v.colname, v.value or NULLTEXT, label_maxw, value_maxw)
    table.insert(Items, label)
    table.insert(Items, edit)
    edit.Colname = v.colname
    edit.Orig = v.value
    edit.ext = "txt"
  end

  table.insert(Items, { tp="sep" })
  table.insert(Items, { tp="butt"; text=M.save;   centergroup=1; default=1; })
  table.insert(Items, { tp="butt"; text=M.cancel; centergroup=1; cancel=1;  })

  Items.keyaction = function (hDlg, Param1, key)
    local pos = hDlg:send(F.DM_GETFOCUS)
    local item = Items[pos]
    local txt = item.Colname and hDlg:send(F.DM_GETTEXT, pos)
    -- toggle original row text and NULLTEXT
    if txt and key == "CtrlN" then
      if txt:upper() == NULLTEXT:upper() then
        hDlg:send(F.DM_SETTEXT, pos, item.Orig or "")
      else
        hDlg:send(F.DM_SETTEXT, pos, NULLTEXT)
      end
    -- view row in the viewer
    elseif txt and key == "F3" then
      local fname = utils.get_temp_file_name("txt")
      local fp = io.open(fname, "w")
      if fp then
        fp:write(txt)
        fp:close()
        viewer.Viewer(fname, item.Colname, nil,nil,nil,nil,
                      bit64.bor(F.VF_DELETEONCLOSE,F.VF_DISABLEHISTORY), 65001)
      end
    end
  end

  Items.closeaction = function(hDlg, Par1, tOut)
    local out = {}
    for pos,item in ipairs(Items) do
      if item.Colname then
        local txt = hDlg:send(F.DM_GETTEXT, pos)
        if (not row_id) or (txt ~= item.Orig) then
          table.insert(out, { colname=item.Colname; value=txt; })
        end
      end
    end
    if not self:exec_update(row_id, out) then
      return 0
    end
  end

  return sdialog.Run(Items) and true
end


function myeditor:edit_row(handle)
  -- Get edited row id
  local item = panel.GetCurrentPanelItem(handle)
  if not item or item.FileName == ".." then return; end

  local row_id = tostring(item.AllocationSize)
  local query = ("SELECT * FROM %s.%s WHERE %s=%s"):
    format(Norm(self._schema), Norm(self._table_name), self._rowid_name, row_id)
  local stmt = self._db:prepare(query)
  if stmt then
    if stmt:step() == sql3.ROW then
      -- Read current row data
      local db_data = {}
      for i = 0, stmt:columns()-1 do
        local value
        local coltype = stmt:get_column_type(i)
        if coltype == sql3.NULL then
          value = NULLTEXT
        elseif coltype == sql3.INTEGER or coltype == sql3.FLOAT then
          value = stmt:get_column_text(i)
        elseif coltype == sql3.TEXT then
          value = Norm(stmt:get_column_text(i))
        elseif coltype == sql3.BLOB then
          local s = string.gsub(stmt:get_value(i), ".",
            function(c) return string.format("%02x", string.byte(c)); end)
          value = "x'" .. s .. "'"
        end
        table.insert(db_data, { colname=stmt:get_name(i); coltype=coltype; value=value; })
      end

      if self:row_dialog(db_data, row_id) then
        panel.UpdatePanel(handle)
        panel.RedrawPanel(handle)
      end
    else
      ErrMsg(M.err_read .. "\n" .. self._dbx:last_error())
    end
    stmt:finalize()
  end
end


function myeditor:insert_row(handle)
  local info = self._dbx:read_columns_info(self._schema, self._table_name)
  if info then
    local col_data = {}
    for _,v in ipairs(info) do
      table.insert(col_data, { colname=v.name; coltype=sql3.NULL; value=NULLTEXT; })
    end
    if self:row_dialog(col_data, nil) then
      panel.UpdatePanel(handle, nil, true)
      panel.RedrawPanel(handle, nil)
    end
  end
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
      local msg = self._dbx:last_error().."\n"..M.err_sql
      self._db:exec("ROLLBACK TRANSACTION;")
      ErrMsg(msg)
      return false
    end

  end

  return true
end


function myeditor:exec_update(row_id, db_data)
  local query
  if row_id then
    -- Update query
    if db_data[1] == nil then
      return true -- no changed columns
    end
    query = ("UPDATE %s.%s SET "):format(Norm(self._schema), Norm(self._table_name))
    for i,v in ipairs(db_data) do
      if i>1 then query = query..',' end
      query = query..Norm(v.colname).."="..v.value
    end
    query = query.." WHERE "..self._rowid_name.."="..row_id

  else
    -- Insert query
    query = ("INSERT INTO %s.%s ("):format(Norm(self._schema), Norm(self._table_name))
    for i,v in ipairs(db_data) do
      if i>1 then query = query.."," end
      query = query .. Norm(v.colname)
    end
    query = query .. ") VALUES ("
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


return myeditor
