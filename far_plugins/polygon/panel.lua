-- panel.lua

local sql3 = require "lsqlite3"
local F = far.Flags
local VK = win.GetVirtualKeys()

local Params = ...
local M        = Params.M
local sqlite   = Params.sqlite
local progress = Params.progress
local exporter = Params.exporter
local myeditor = Params.myeditor

--! Panel modes.
--enum panel_mode {
local pm_db    = 0
local pm_table = 1
local pm_view  = 2
local pm_query = 3


local mypanel = {}
local mt_panel = {__index=mypanel}


function mypanel.open(file_name, silent, foreign_keys) -- function, not method
  local self = {
    _file_name      = file_name;
    _last_sql_query = "";
    _column_descr   = {};
  }

  self._panel_info = { -- Panel info description
    title      = "";
    col_types  = "";
    col_widths = "";
    col_titles = {};
    modes      = {};
    key_bar    = {};
  }
  setmetatable(self, mt_panel)

  self._db = sqlite.newsqlite();
  if not (self._db:open(file_name, foreign_keys) and self:open_database()) then
    self = nil
    if not silent then
      ErrMsg(M.ps_err_open.."\n"..file_name)
    end
  end

  return self
end


function mypanel:open_database()
  self._panel_mode = pm_db
  self._curr_object = ""
  self:prepare_panel_info()
  return true
end


function mypanel:open_object(object_name)
  local tp = self._db:get_object_type(object_name)
  if tp==sqlite.ot_master or tp==sqlite.ot_table then
    self._panel_mode = pm_table
  elseif tp==sqlite.ot_view then
    self._panel_mode = pm_view
  else
    return false
  end

  self._curr_object = object_name

  self._column_descr = {}
  if not self._db:read_column_description(object_name, self._column_descr) then
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  self:prepare_panel_info()
  return true
end


function mypanel:open_query(query)
  if not query or query=="" then return false; end

  self._last_sql_query = query

  -- Check query for select
  local select_word = query:match("^%s*(%w*)");
  if select_word:lower() ~= "select" then
    -- Update query - just execute without read result
    local prg_wnd = progress.newprogress(M.ps_execsql)
    if not self._db:execute_query(query) then
      prg_wnd:hide()
      local err_descr = self._db:last_error()
      ErrMsg(M.ps_err_sql.."\n"..query.."\n"..err_descr)
      return false
    end
    prg_wnd:hide()
  else
    -- Get column description
    local db = self._db:db()
    local stmt = db:prepare(query)
    if (not stmt) or (stmt:step() ~= sql3.ROW and stmt.step() ~= sql3.DONE) then
      local err_descr = self._db:last_error()
      ErrMsg(M.ps_err_sql.."\n"..query.."\n"..err_descr)
      if stmt then stmt:finalize() end
      return false
    end

    self._panel_mode = pm_query
    self._curr_object = query

    self._column_descr = {}
    local col_count = stmt:columns()
    for i = 0, col_count-1 do
      local col = {
        name = stmt:get_name(i);
        type = sqlite.ct_text;
      }  
      table.insert(self._column_descr, col)
    end

    stmt:finalize()
    self:prepare_panel_info()
  end

  panel.UpdatePanel(nil, 1)
  panel.RedrawPanel(nil, 1)

  return true
end


function mypanel:get_panel_info()
  local info = {}
  info.Flags = bit64.bor(F.OPIF_DISABLESORTGROUPS, F.OPIF_DISABLEFILTER)
  info.PanelTitle = self._panel_info.title
  info.CurDir = self._curr_object
  info.HostFile = self._file_name

  info.StartPanelMode = ("0"):byte()
  info.PanelModesArray = self._panel_info.modes
  info.PanelModesNumber = #self._panel_info.modes
  info.KeyBar = self._panel_info.key_bar

  return info
end


function mypanel:get_panel_list()
  local rc = false
  if self._panel_mode==pm_db then
    rc = self:get_panel_list_db()
  elseif self._panel_mode==pm_table or self._panel_mode==pm_view then
    rc = self:get_panel_list_obj()
  elseif self._panel_mode == pm_query then
    rc = self:get_panel_list_query()
  end
  return rc
end


function mypanel:get_panel_list_db()
  local prg_wnd = progress.newprogress(M.ps_reading)

  local db_objects = {}
  if not self._db:get_objects_list(db_objects) then
    prg_wnd:hide()
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..self._file_name.."\n"..err_descr)
    return false
  end
  local items = { {} }

  -- All dots (..)
  items[1].FileName = ".."

  for i,obj in ipairs(db_objects) do
    local item = {}
    items[i+1] = item
    item.FileSize = obj.row_count
    if obj.type == sqlite.ot_master or obj.type == sqlite.ot_table or obj.type == sqlite.ot_view then
      item.FileAttributes = "d"
    end
    item.FileName = obj.name
    item.AllocationSize = obj.type  -- This field used as type id

    item.CustomColumnData = {}
    local tp = "?"
    if     obj.type==sqlite.ot_master then tp="metadata"
    elseif obj.type==sqlite.ot_table  then tp="table"
    elseif obj.type==sqlite.ot_view   then tp="view"
    elseif obj.type==sqlite.ot_index  then tp="index"
    end
    item.CustomColumnData[1] = tp
    item.CustomColumnData[2] = ("% 9d"):format(obj.row_count)
  end

  prg_wnd:hide()
  return items
end


function mypanel:get_panel_list_obj()
  local row_count = self._db:get_row_count(self._curr_object)
  if not row_count then
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  local prg_wnd = progress.newprogress(M.ps_reading, row_count)

  local dot_item = {}
  local items = { dot_item }

  -- All dots (..)
  dot_item.FileName = ".."
  local dot_col_num = #self._column_descr
  local dot_custom_column_data = {}
  for j = 1, dot_col_num do
    dot_custom_column_data[j] = ".."
  end
  dot_item.CustomColumnData = dot_custom_column_data

  -- Find a name to use for ROWID (self._rowid_name)
  local db = self._db:db()
  local query = "select * from '"..self._curr_object.."'"
  local stmt = db:prepare(query)
  if not stmt then return false end
  local col_names = stmt:get_names()
  stmt:finalize()
  for _,v in ipairs(col_names) do col_names[v:lower()]=true; end
  self._rowid_name = nil
  for _,v in ipairs {"rowid", "oid", "_rowid_"} do
    if col_names[v] == nil then self._rowid_name = v; break; end
  end

  -- Find if ROWID exists
  self._has_rowid = true
  stmt = nil
  if self._rowid_name then
    query = "select "..self._rowid_name..",* from '"..self._curr_object.."'"
    stmt = db:prepare(query)
  end
  if not stmt then
    query = "select * from '"..self._curr_object.."'"
    stmt = db:prepare(query)
    if stmt then
      self._has_rowid = false
    else
      prg_wnd:hide()
      local err_descr = self._db:last_error()
      ErrMsg(M.ps_err_read.."\n"..err_descr)
      return false
    end
  end

  local col_num = #self._column_descr
  for row = 1, row_count do
    if (row-1) % 100 == 0 then
      prg_wnd:update(row-1)
    end
    if stmt:step() ~= sql3.ROW then
      prg_wnd:hide()
      local err_descr = self._db:last_error()
      ErrMsg(M.ps_err_read.."\n"..err_descr)
      stmt:finalize()  
      return false
    end
    if progress.aborted() then
      prg_wnd:hide()
      stmt:finalize()  
      return items  -- Show incomplete data
    end

    -- Use leftmost column cell as file name, otherwise FAR cannot properly handle selections on the panel
    local FileName = exporter.get_text(stmt,0)
    if self._has_rowid then
      -- Prepend zero characters to make sorting by name sort by rowid
      if #FileName < 10 then FileName = ("0"):rep(10-#FileName)..FileName; end
    end

    local item = { FileName=FileName; }
    items[row+1] = item -- shift by 1, as items[1] is dot_item
    local custom_column_data = {}
    local adjust = self._has_rowid and 0 or 1
    for j = 1, col_num do
      custom_column_data[j] = exporter.get_text(stmt, j-adjust)
    end
    if self._has_rowid then
      item.AllocationSize = stmt:get_value(0)  -- This field used as row id
    end
    item.CustomColumnData = custom_column_data
  end
  prg_wnd:update(row_count)

  prg_wnd:hide()
  stmt:finalize()  
  return items
end


function mypanel:get_panel_list_query()
  local prg_wnd = progress.newprogress(M.ps_reading)

  -- Read all data to buffer - we don't know rowset size
  local buff = {}

  -- All dots (..)
  local dot_item = {}

  -- All dots (..)
  dot_item.FileName = ".."
  local dot_col_num = #self._column_descr
  local dot_custom_column_data = {}
  for j = 1, dot_col_num do
    dot_custom_column_data[j] = ".."
  end
  dot_item.CustomColumnData = dot_custom_column_data
  table.insert(buff, dot_item)

  local db = self._db:db()
  local stmt = db:prepare(self._curr_object)
  if not stmt then
    prg_wnd:hide()
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  local state = sql3.OK
  while true do
    state = stmt:step()
    if state ~= sql3.ROW then
      break
    end
    if progress.aborted() then
      state = sql3.DONE
      break  -- Show incomplete data
    end

    local item = {}
    local col_count = stmt:columns()
    local custom_column_data = {}
    for j = 1, col_count do
      custom_column_data[j] = exporter.get_text(stmt, j-1)
    end
    item.CustomColumnData = custom_column_data
    table.insert(buff, item)
  end

  if state ~= sql3.DONE then
    prg_wnd:hide()
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    stmt:finalize()  
    return false
  end

  prg_wnd:hide()
  stmt:finalize()
  return buff
end


function mypanel:prepare_panel_info()
--  struct {
--    wstring                 title    ///< Panel title
--    wstring                 col_types
--    wstring                 col_widths
--    vector<const wchar_t*>  col_titles
--    const wchar_t*          status_types
--    const wchar_t*          status_widths
--    vector<PanelMode>       modes
--    vector<KeyBarLabel>     key_bar
--  }    _panel_info    ///< Panel info description
  self._panel_info.col_types = ""
  self._panel_info.col_widths = ""
  self._panel_info.col_titles = {}
  self._panel_info.key_bar = {}
  self._panel_info.status_types = nil
  self._panel_info.status_widths = nil
  self._panel_info.title = M.ps_title_short .. ": " .. self._file_name:match("[^\\/]*$")

--  sqlite          _db               ///< Database instance
--  panel_mode      _panel_mode       ///< Current panel mode
--  sqlite::sq_columns  _column_descr ///< Column description
--  wstring        _curr_object       ///< Current viewing object name (directory name for Far)
--  wstring        _file_name         ///< SQLite db file name
--  wstring        _last_sql_query    ///< Last used user's SQL query
  if self._curr_object=="" or self._curr_object==nil then
    self._panel_info.col_types     = "N,C0,C1"
    self._panel_info.status_types  = "N,C0,C1"    
    self._panel_info.col_widths    = "0,8,9"
    self._panel_info.status_widths = "0,8,9"
    table.insert(self._panel_info.col_titles, M.ps_pt_name)
    table.insert(self._panel_info.col_titles, M.ps_pt_type)
    table.insert(self._panel_info.col_titles, M.ps_pt_count)

    self:add_keybar_label("DDL", VK.F4)
    self:add_keybar_label("Pragma", VK.F4, F.SHIFT_PRESSED)
    self:add_keybar_label("Export", VK.F5)
  else
    self._panel_info.title = self._panel_info.title .. " [" .. self._curr_object .. "]"

    local col_num = #self._column_descr
    for i = 1, col_num do
      if self._panel_info.col_types ~= "" then
        self._panel_info.col_types = self._panel_info.col_types .. ","
      end
      self._panel_info.col_types = self._panel_info.col_types .. "C"
      self._panel_info.col_types = self._panel_info.col_types .. (i-1)
      if self._panel_info.col_widths.empty ~= "" then
        self._panel_info.col_widths = self._panel_info.col_widths .. ','
      end
      self._panel_info.col_widths = self._panel_info.col_widths .. '0'
      table.insert(self._panel_info.col_titles, self._column_descr[i].name)
    end
    self:add_keybar_label("Update", VK.F4)
    self:add_keybar_label("Insert", VK.F4, F.SHIFT_PRESSED)
    self:add_keybar_label("", VK.F3)
    self:add_keybar_label("", VK.F3, F.SHIFT_PRESSED)
    self:add_keybar_label("", VK.F5)
  end
  self:add_keybar_label("SQL", VK.F6)
  self:add_keybar_label("", VK.F1, F.SHIFT_PRESSED)
  self:add_keybar_label("", VK.F2, F.SHIFT_PRESSED)
  self:add_keybar_label("", VK.F3, F.SHIFT_PRESSED)
  self:add_keybar_label("", VK.F5, F.SHIFT_PRESSED)
  self:add_keybar_label("", VK.F6, F.SHIFT_PRESSED)
  self:add_keybar_label("", VK.F7)
  self:add_keybar_label("", VK.F3, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  self:add_keybar_label("", VK.F4, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  self:add_keybar_label("", VK.F5, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  self:add_keybar_label("", VK.F6, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  self:add_keybar_label("", VK.F7, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  for i = VK.F1, VK.F12 do
    self:add_keybar_label("", i, F.LEFT_CTRL_PRESSED + F.RIGHT_CTRL_PRESSED)
  end

  -- Configure one panel view for all modes
  self._panel_info.modes = {}
  local pm = {}
  pm.ColumnTypes  = self._panel_info.col_types
  pm.ColumnWidths = self._panel_info.col_widths
  pm.ColumnTitles = self._panel_info.col_titles
  pm.StatusColumnTypes = self._panel_info.status_types
  pm.StatusColumnWidths = self._panel_info.status_widths
  for k=1,10 do self._panel_info.modes[k] = pm; end
end


function mypanel:add_keybar_label(label, vkc, cks)
  local kbl = {}
  kbl.Text = label;
  kbl.LongText = label;
  kbl.VirtualKeyCode = vkc
  kbl.ControlKeyState = cks or 0
  table.insert(self._panel_info.key_bar, kbl)
end


function mypanel:delete_items(items, items_count)
  if self._panel_mode == pm_table and not (self._has_rowid and self._rowid_name) then
    ErrMsg(M.ps_err_del_norowid)
    return false
  end
  if self._panel_mode == pm_table or self._panel_mode == pm_db then
    local ed = myeditor.neweditor(self._db, self._curr_object, self._rowid_name)
    return ed:remove(items, items_count)
  end
  return false
end


function mypanel:handle_keyboard(key_event)
  local rc = false
  local cstate = key_event.ControlKeyState
  local vcode  = key_event.VirtualKeyCode

  -- Ignored keys
  if (cstate == F.LEFT_CTRL_PRESSED or cstate == F.RIGHT_CTRL_PRESSED) and vcode == ("A"):byte() then
    rc = true
  elseif vcode == VK.F7 then
    rc = true
  -- F3 (view table/view data)
  elseif self._panel_mode == pm_db and vcode == VK.F3 then
    self:view_db_object()
    rc = true
  -- F4 (view create statement)
  elseif self._panel_mode == pm_db and cstate == 0 and vcode == VK.F4 then
    self:view_db_create_sql()
    rc = true
  -- Shift-F4 (view pragma statement)
  elseif self._panel_mode == pm_db and cstate == F.SHIFT_PRESSED and vcode == VK.F4 then
    self:view_pragma_statements()
    rc = true
  -- F4 (edit row)
  elseif self._panel_mode == pm_table and cstate == 0 and (vcode == VK.F4 or vcode == VK.RETURN) then
    local can_be_handled = true
    if vcode == VK.RETURN then
      -- Skip for '..'
      local item = panel.GetCurrentPanelItem(nil, 1)
      can_be_handled = item and item.FileName ~= ".."
    end
    if can_be_handled then
      if self._panel_mode == pm_table and not (self._has_rowid and self._rowid_name) then
        ErrMsg(M.ps_err_edit_norowid)
      else
        local re = myeditor.neweditor(self._db, self._curr_object, self._rowid_name)
        re:update()
        rc = true
      end
    end
  -- Shift+F4 (insert row)
  elseif self._panel_mode == pm_table and cstate == F.SHIFT_PRESSED and vcode == VK.F4 then
    local re = myeditor.neweditor(self._db, self._curr_object)
    re:insert()
    rc = true
  -- F5 (export table/view data)
  elseif vcode == VK.F5 then
    if self._panel_mode == pm_db then
      local ex = exporter.newexporter(self._db)
      ex:export_data_with_dialog()
    end
    rc = true
  -- F6 (edit and execute SQL query)
  elseif vcode == VK.F6 then
    self:edit_sql_query()
    rc = true
  end
  return rc
end


function mypanel:view_db_object()
  -- Get selected object name
  local item = panel.GetCurrentPanelItem(nil, 1)
  if not item or item.FileName == ".." then
    return
  end

  local tmp_file_name

  -- For unknown types show create sql only
  if not item.FileAttributes:find("d") then
    local cr_sql = self._db:get_creation_sql(item.FileName)
    if not cr_sql then
      return
    end
    tmp_file_name = exporter.get_temp_file_name("sql")

    local file = io.open(tmp_file_name, "wb")
    if not file then
      ErrMsg(M.ps_err_writef.."\n"..tmp_file_name, "we")
      return
    end
    if not file:write(cr_sql) then
      file:close()
      ErrMsg(M.ps_err_writef.."\n"..tmp_file_name, "we")
      return
    end
    file:close()
  else 
    -- Export data
    local ex = exporter.newexporter(self._db)
    tmp_file_name = exporter.get_temp_file_name("txt")
    local ok = ex:export_data(tmp_file_name, item.FileName, exporter.fmt_text )
    if not ok then return end
  end
  local title = M.ps_title_short .. ": " .. item.FileName
  viewer.Viewer(tmp_file_name, title, 0, 0, -1, -1, bit64.bor(
    F.VF_ENABLE_F6, F.VF_DISABLEHISTORY, F.VF_DELETEONLYFILEONCLOSE, F.VF_IMMEDIATERETURN, F.VF_NONMODAL), 65001)
  viewer.SetMode(nil, { Type=F.VSMT_WRAP,     iParam=0,          Flags=0 })
  viewer.SetMode(nil, { Type=F.VSMT_VIEWMODE, iParam=F.VMT_TEXT, Flags=F.VSMFL_REDRAW })
end


function mypanel:view_db_create_sql()
  -- Get selected object name
  local item = panel.GetCurrentPanelItem(nil, 1)
  if item and item.FileName ~= ".." then
    local cr_sql = self._db:get_creation_sql(item.FileName)
    if cr_sql then
      local tmp_path = far.MkTemp()..".sql"
      local file = io.open(tmp_path, "w")
      if file and file:write(cr_sql) then
        file:close()
        viewer.Viewer(tmp_path, item.FileName, nil, nil, nil, nil,
          F.VF_ENABLE_F6 + F.VF_DISABLEHISTORY + F.VF_DELETEONLYFILEONCLOSE + F.VF_NONMODAL, 65001)
      else
        if file then file:close() end
        ErrMsg(M.ps_err_writef.."\n"..tmp_path, "we")
      end   
    end
  end
end


function mypanel:view_pragma_statements()
  local pst = {
    "auto_vacuum", "automatic_index", "busy_timeout", "cache_size",
    "checkpoint_fullfsync", "encoding", "foreign_keys",
    "freelist_count", "fullfsync", "ignore_check_constraints",
    "integrity_check", "journal_mode", "journal_size_limit",
    "legacy_file_format", "locking_mode", "max_page_count",
    "page_count", "page_size", "quick_check", "read_uncommitted",
    "recursive_triggers", "reverse_unordered_selects",
    "schema_version", "secure_delete", "synchronous", "temp_store",
    "user_version", "wal_autocheckpoint", "wal_checkpoint"
  }
  local pragma_values = {}
  for _,v in ipairs(pst) do
    local query = "pragma " .. v
    local db = self._db:db()
    local stmt = db:prepare(query)
    if stmt then
      if stmt:step() == sql3.ROW then
        local pv = v .. ": "
        if pv:len() < 28 then
          pv = pv:resize(28, ' ')
        end
        pv = pv .. stmt:get_value(0)
        table.insert(pragma_values, pv)
      end
      stmt:finalize()
    end
  end
  if pragma_values[1] == nil then return end

  local list_items = {}
  for i,v in ipairs(pragma_values) do
    list_items[i] = { Text=v }
  end
  list_items[1].Flags = F.LIF_SELECTED
  local list_flags = F.DIF_LISTNOBOX + F.DIF_LISTNOAMPERSAND + F.DIF_FOCUS
  local btn_flags = F.DIF_CENTERGROUP + F.DIF_DEFAULTBUTTON

  local dlg_items = {
    {"DI_DOUBLEBOX", 3, 1,56,18,          0, 0, 0, 0,               M.ps_title_pragma},
    {"DI_LISTBOX",   4, 2,55,15, list_items, 0, 0, list_flags,      ""},
    {"DI_TEXT",      0,16, 0,16,          0, 0, 0, F.DIF_SEPARATOR, ""},
    {"DI_BUTTON",   60,17, 0, 0,          0, 0, 0, btn_flags,       M.ps_cancel}
  }

  local guid = win.Uuid("FF769EE0-2643-48F1-A8A2-239CD3C6691F")
  far.Dialog(guid, -1, -1, 60, 20, nil, dlg_items, F.FDLG_NONE)
end


function mypanel:edit_sql_query()
  local tmp_file_name = exporter.get_temp_file_name("sql")

  -- Save last used query
  if self._last_sql_query ~= "" then
    local file = io.open(tmp_file_name, "w")
    if not (file and file:write(self._last_sql_query)) then
      if file then file:close() end
      ErrMsg(M.ps_err_writef.."\n"..tmp_file_name, "we")
      return
    end   
    file:close()
  end
    
  -- Open query editor
  if editor.Editor(tmp_file_name, "SQLite query", nil, nil, nil, nil, F.EF_DISABLESAVEPOS + F.EF_DISABLEHISTORY,
                   nil, nil, 65001) == F.EEC_MODIFIED then
    -- Read query
    local file = io.open(tmp_file_name, "rb")
    if not file then
      ErrMsg(M.ps_err_read.."\n"..tmp_file_name, "we")
      return
    end
    local file_buff = file:read("*all")
    file:close()
    win.DeleteFile(tmp_file_name)

    -- Remove BOM 
    local a,b,c,d = string.byte(file_buff, 1, 4)
    if a == 0xef and b == 0xbb and c == 0xbf then  -- UTF-8
      file_buff = string.sub(file_buff, 4)
    elseif a == 0xfe and b == 0xff then  -- UTF-16 (BE)
      file_buff = string.sub(file_buff, 3)
    elseif a == 0xff and b == 0xfe then  -- UTF-16 (LE)
      file_buff = string.sub(file_buff, 3)
    elseif a == 0x00 and b == 0x00 and c == 0xfe and d == 0xff then -- UTF-32 (BE)
      file_buff = string.sub(file_buff, 5)
    elseif a == 0x00 and b == 0x00 and c == 0xff and d == 0xfe then -- UTF-32 (LE)
      file_buff = string.sub(file_buff, 5)
    elseif a == 0x2b and b == 0x2f then -- UTF-7
      file_buff = string.sub(file_buff, 5) -- ### suspicious
    end
    if file_buff == "" then return; end

    self._last_sql_query = string.gsub(file_buff, "\r\n", "\n")
    self:open_query(self._last_sql_query)
  end
end


return mypanel
