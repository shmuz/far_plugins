-- coding: UTF-8

local sql3     = require "lsqlite3"
local sdialog  = require "far2.simpledialog"
local M        = require "modules.string_rc"
local dbx      = require "modules.sqlite"
local utils    = require "modules.utils"
local progress = require "modules.progress"

local F = far.Flags
local ErrMsg, Norm = utils.ErrMsg, utils.Norm
local NULLTEXT = "NULL"
local KEEP_DIALOG_OPEN = 0


local function process_field(text)
  if text:find("^[xX]?['\"]")                 -- either BLOB or normalized TEXT
    or #text == 4 and text:upper() == "NULL"  -- NULL
    or tonumber(text)                         -- NUMERIC
    then return text
  else
    return Norm(text)
  end
end


local function get_default_value(affinity)
  local val = 0
  if     affinity == "NUMERIC" then val = 0
  elseif affinity == "INTEGER" then val = 0
  elseif affinity == "TEXT"    then val = "'text'" -- make it visible
  elseif affinity == "BLOB"    then val = "x'00'"
  elseif affinity == "REAL"    then val = 0.0
  end
  return val
end


local function exec_update(db, schema, table_name, rowid_name, row_id, db_data)
  local query
  if row_id then -- compose "Update" query
    if db_data[1] == nil then
      return true -- no changed columns
    end
    local t = {}
    for i,v in ipairs(db_data) do t[i] = Norm(v.colname).."="..process_field(v.value) end
    query = ("UPDATE %s.%s SET %s WHERE %s=%s"):format(
        Norm(schema), Norm(table_name), table.concat(t,","), rowid_name, row_id)
  else -- compose "Insert" query
    local info = dbx.read_columns_info(db, schema, table_name)
    if not info then
      return false
    end
    local t1, t2, j = {},{},0
    for i,v in ipairs(db_data) do
      local val = v.value:upper()
      if val ~= "NULL" or info[i].notnull==0 then
        j = j + 1
        t1[j] = Norm(v.colname)
        t2[j] = process_field(v.value)
      elseif (not info[i].dflt_value) and (info[i].pk == 0) then
        j = j + 1
        t1[j] = Norm(v.colname)
        t2[j] = get_default_value(info[i].affinity)
      end
    end
    if next(t1) then
      query = ("INSERT INTO %s.%s (%s) VALUES (%s)"):format(
          Norm(schema), Norm(table_name), table.concat(t1,","), table.concat(t2,","))
    else
      query = ("INSERT INTO %s.%s DEFAULT VALUES"):format(Norm(schema), Norm(table_name))
    end
  end
  local ok = true
  db:exec("BEGIN")
  for _=1,db_data.quan do
    if db:exec(query) ~= sql3.OK then
      ok = false; break
    end
  end
  if ok and db:exec("COMMIT") == sql3.OK then
    return true
  else
    dbx.err_message(db, query)
    db:exec("ROLLBACK")
    return false
  end
end


local function row_dialog(db, schema, table_name, rowid_name, db_data, row_id)
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

  -- Build the dialog
  local title = utils.lang(row_id and M.edit_row_title or M.insert_row_title, {table_name} )
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
  if row_id then
    table.insert(Items, { tp="butt"; text=M.save;   centergroup=1; default=1; })
    table.insert(Items, { tp="butt"; text=M.cancel; centergroup=1; cancel=1;  })
  else
    local x1 = M.insert_row_quan:gsub("&",""):len() + 6
    table.insert(Items, { tp="text"; text=M.insert_row_quan; })
    table.insert(Items, { tp="fixedit"; val="1"; x1=x1; x2=x1+3; mask="9999"; ystep=0; name="quan"; })
    table.insert(Items, { tp="butt"; text=M.save;   centergroup=1; default=1; ystep=0; })
    table.insert(Items, { tp="butt"; text=M.cancel; centergroup=1; cancel=1;  })
  end

  local keyaction = function (hDlg, Param1, key)
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
    -- convert blob to text and show it
    elseif key == "AltF3" then
      local s = txt:match("^[xX]'(.+)'$")
      s = s and string.gsub(s, "%x%x", function(c) return string.char(tonumber(c,16)) end)
      s = s and string.gsub(s, "%z", " ") or txt
      if 2 == far.Message(s, nil, "Cancel;Copy", "l") then far.CopyToClipboard(s) end
    end
  end

  local closeaction = function(hDlg, Par1, tOut)
    local out = { quan = math.max(1, tonumber(tOut.quan) or 1) }
    for pos,item in ipairs(Items) do
      if item.Colname then
        local txt = hDlg:send(F.DM_GETTEXT, pos)
        if (not row_id) or (txt ~= item.Orig) then
          table.insert(out, { colname=item.Colname; value=txt; })
        end
      end
    end
    if not exec_update(db, schema, table_name, rowid_name, row_id, out) then
      return KEEP_DIALOG_OPEN
    end
  end

  Items.proc = function(hDlg, Msg, Par1, Par2)
    if Msg == "EVENT_KEY" then
      keyaction(hDlg, Par1, Par2)
    elseif Msg == F.DN_CLOSE then
      return closeaction(hDlg, Par1, Par2)
    end
  end

  return sdialog.New(Items):Run() and true
end


local function get_row_data(db, schema, table_name, rowid_name, handle)
  -- Get edited row id
  local item = panel.GetCurrentPanelItem(handle)
  if not item or item.FileName == ".." then return; end

  local row_id = item.Owner
  local query = ("SELECT * FROM %s.%s WHERE %s=%s"):
    format(Norm(schema), Norm(table_name), rowid_name, row_id)
  local stmt = db:prepare(query)
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
      return db_data, row_id
    else
      ErrMsg(M.err_read .. "\n" .. dbx.last_error(db))
    end
    if stmt:isopen() then stmt:finalize() end
  end
end


local function edit_row(db, schema, table_name, rowid_name, handle)
  local db_data, row_id = get_row_data(db, schema, table_name, rowid_name, handle)
  if db_data then
    if row_dialog(db, schema, table_name, rowid_name, db_data, row_id) then
      panel.UpdatePanel(handle, nil, true) -- keep selection
      panel.RedrawPanel(handle)
    end
  end
end


local function call_insert_dialog(db, schema, table_name, rowid_name, col_data, handle)
  if row_dialog(db, schema, table_name, rowid_name, col_data, nil) then
    panel.UpdatePanel(handle, nil, true) -- keep selection

    -- Find position of the newly inserted item in order to place the cursor on it.
    -- Don't search on very big tables to avoid slow operation.
    local pos
    local pInfo = panel.GetPanelInfo(handle)
    if pInfo.ItemsNumber <= 10000 then
      local row_id = db:last_insert_rowid()
      if row_id then
        row_id = tostring(bit64.new(row_id))
        for k=1,pInfo.ItemsNumber do
          local item = panel.GetPanelItem(handle,nil,k)
          if utils.get_rowid(item) == row_id then pos=k; break; end
        end
      end
    end

    panel.RedrawPanel(handle, nil, pos and { CurrentItem=pos; })
  end
end


local function insert_row(db, schema, table_name, rowid_name, handle)
  local info = dbx.read_columns_info(db, schema, table_name)
  if info then
    local col_data = {}
    for _,v in ipairs(info) do
      table.insert(col_data, {
        colname = v.name;
        value = v.dflt_value
          or (v.pk==0 and v.notnull~=0 and get_default_value(v.affinity))
          or NULLTEXT;
      })
    end
    call_insert_dialog(db, schema, table_name, rowid_name, col_data, handle)
  end
end


local function copy_row(db, schema, table_name, rowid_name, handle)
  local db_data = get_row_data(db, schema, table_name, rowid_name, handle)
  if db_data then
    call_insert_dialog(db, schema, table_name, rowid_name, db_data, handle)
  end
end


local function remove(db, schema, table_name, rowid_name, items)
  local items_count = #items
  if items_count == 1 and items[1].FileName == ".." then
    return false
  end
  if table_name == "" then
    for _,item in ipairs(items) do
      local typename = dbx.decode_object_type(item.AllocationSize)
      if typename then
        local name_norm = Norm(item.FileName)
        local query = ("DROP %s %s.%s"):format(typename, Norm(schema), name_norm)
        if not dbx.execute_query(db, query, true) then
          break
        end
      end
    end
  else
    local prg_wnd = progress.newprogress(M.deleting, items_count)
    local query_start = ("DELETE FROM %s.%s WHERE %s in ("):
      format(Norm(schema), Norm(table_name), rowid_name)
    db:exec("BEGIN TRANSACTION")
    local rollback
    local cnt = 0
    while cnt < items_count do
      if progress.aborted() then
        if 1 == far.Message(M.rollback_operation, M.title_short, ";YesNo", "w") then
          rollback=true; break
        end
      end
      prg_wnd:update(cnt)
      local sbuf = utils.StringBuffer()
      local upper = math.min(cnt+1000, items_count) -- process up to 1000 rows at a time
      for i = cnt+1, upper do sbuf:Add(items[i].Owner); end
      local query = query_start .. sbuf:Concat(",") .. ")"
      if not dbx.execute_query(db, query, true) then
        break
      end
      cnt = upper
    end
    prg_wnd:hide()
    if rollback then
      db:exec("ROLLBACK")
    else
      if db:exec("COMMIT") ~= sql3.OK then
        local msg = dbx.last_error(db).."\n"..M.err_sql
        db:exec("ROLLBACK")
        ErrMsg(msg)
        return false
      end
    end
  end
  return true
end


return {
  copy_row   = copy_row;
  edit_row   = edit_row;
  insert_row = insert_row;
  remove     = remove;
}
