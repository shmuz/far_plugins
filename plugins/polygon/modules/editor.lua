-- coding: UTF-8

local sql3    = require "lsqlite3"
local sdialog = require "far2.simpledialog"
local M       = require "modules.string_rc"
local sqlite  = require "modules.sqlite"
local utils   = require "modules.utils"

local F = far.Flags
local ErrMsg, Norm = utils.ErrMsg, utils.Norm
local NULLTEXT = "NULL"
local KEEP_DIALOG_OPEN = 0


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


function myeditor:row_dialog(db_data, row_id)
  -- Calculate dialog's size
  local rect = far.AdvControl("ACTL_GETFARRECT")
  local DLG_MAXW   = rect and (rect.Right - rect.Left + 1) or 80
  local RESERVED   = 5 -- 2=box + 3=space-delimiters
  local width_label = 0
  local width_edit = math.floor(DLG_MAXW / 2)

  for _,v in ipairs(db_data) do
    width_label = math.max(width_label, v.colname:len())
  end
  width_label = math.min(width_label, DLG_MAXW - RESERVED - width_edit)

  -- Build dialog
  local title = utils.lang(row_id and M.edit_row_title or M.insert_row_title, {self._table_name})
  local Items = {
    guid  = "866927E1-60F1-4C87-A09D-D481D4189534";
    help  = "EditInsertRow";
    width = width_label + width_edit + RESERVED;
    [1]   = { tp="dbox"; text=title; }
  }

  for _,v in ipairs(db_data) do
    local nm = v.colname
    if nm:len() > width_label then nm = nm:sub(1,width_label-3) .. "..." end
    local label = { tp="text"; x1=5; x2=4+width_label; text=nm; }
    local edit  = { tp="edit"; x1=label.x2+2; x2=label.x2+1+width_edit; ystep=0;
                    text=v.value or NULLTEXT; ext="txt"; Colname=v.colname; Orig=v.value; }
    table.insert(Items, label)
    table.insert(Items, edit)
  end

  table.insert(Items, { tp="sep" })
  table.insert(Items, { tp="butt"; text=M.save;   centergroup=1; default=1; })
  table.insert(Items, { tp="butt"; text=M.cancel; centergroup=1; cancel=1;  })

  Items.keyaction = function (hDlg, Param1, key)
    local pos = hDlg:send(F.DM_GETFOCUS)
    local item = Items[pos]
    local txt = item.Colname and hDlg:send(F.DM_GETTEXT, pos)
    if not txt then return end
    -- toggle original row text and NULLTEXT
    if key == "CtrlN" then
      if txt:upper() == NULLTEXT:upper() then
        hDlg:send(F.DM_SETTEXT, pos, item.Orig or "")
      else
        hDlg:send(F.DM_SETTEXT, pos, NULLTEXT)
      end
    -- toggle normalization (it's especially handy when typing a ' requires language switching)
    elseif key == "CtrlO" then
      local s = txt:match("^'(.*)'$")
      if s then -- already normalized -> denormalize
        s = s:gsub("''", "'")
        hDlg:send(F.DM_SETTEXT, pos, s)
      else -- normalize
        hDlg:send(F.DM_SETTEXT, pos, Norm(txt))
      end
    -- view row in the viewer
    elseif key == "F3" then
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
      return KEEP_DIALOG_OPEN
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

      -- finalize before popping up the dialog otherwise other
      -- connections may have hard time trying to access this DB
      stmt:finalize()
      if self:row_dialog(db_data, row_id) then
        panel.UpdatePanel(handle)
        panel.RedrawPanel(handle)
      end
    else
      ErrMsg(M.err_read .. "\n" .. self._dbx:last_error())
    end
    if stmt:isopen() then stmt:finalize() end
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
      local pos
      panel.UpdatePanel(handle, nil, true)

      -- Find position of the newly inserted item in order to place the cursor on it.
      -- Don't search on very big tables to avoid slow operation.
      local info = panel.GetPanelInfo(handle)
      if info.ItemsNumber <= 10000 then
        local row_id = self._db:last_insert_rowid()
        if row_id and row_id ~= 0 then
          for k=1,info.ItemsNumber do
            local item = panel.GetPanelItem(handle,nil,k)
            if utils.get_rowid(item) == row_id then pos=k; break; end
          end
        end
      end

      panel.RedrawPanel(handle, nil, pos and { CurrentItem=pos; })
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
    -- compose "Update" query
    if db_data[1] == nil then
      return true -- no changed columns
    end
    local t = {}
    for i,v in ipairs(db_data) do t[i] = Norm(v.colname).."="..v.value end
    query = ("UPDATE %s.%s SET %s WHERE %s=%s"):format(
        Norm(self._schema), Norm(self._table_name),
        table.concat(t,","), self._rowid_name, row_id)
  else
    -- compose "Insert" query
    local t1, t2 = {},{}
    for i,v in ipairs(db_data) do t1[i] = Norm(v.colname) end
    for i,v in ipairs(db_data) do t2[i] = v.value end
    query = ("INSERT INTO %s.%s (%s) VALUES (%s)"):format(
        Norm(self._schema), Norm(self._table_name),
        table.concat(t1,","), table.concat(t2,","))
  end

  if self._db:exec(query) == sql3.OK then return true end
  self._dbx:SqlErrMsg(query)
  return false
end


return myeditor
