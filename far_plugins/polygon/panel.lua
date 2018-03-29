-- panel.lua
-- luacheck: globals ErrMsg

local sql3 = require "lsqlite3"
local hist = require "far2.history"
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
    _last_sql_query = ""  ;
    _column_descr   = nil ;
    _dbx            = nil ;
    _panel_mode     = nil ;
    _curr_object    = nil ;
  }

  self._panel_info = { -- Panel info description
    title      = "" ;
    modes      = {} ;
    key_bar    = {} ;
  }

  setmetatable(self, mt_panel)

  self._dbx = sqlite.newsqlite();
  if self._dbx:open(file_name, foreign_keys) and self:open_database() then
    self._hist_obj = hist.newsettings("col_masks", self._file_name:lower(), "PSL_LOCAL")
    self._col_masks = self._hist_obj:field("masks")
    self._use_masks = false
  else
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
  local dbx = self._dbx
  local tp = dbx:get_object_type(object_name)
  if tp == sqlite.ot_master or tp == sqlite.ot_table then
    self._panel_mode = pm_table
  elseif tp == sqlite.ot_view then
    self._panel_mode = pm_view
  else
    return false
  end
  self._curr_object = object_name
  self._column_descr = dbx:read_column_description(object_name)
  if self._column_descr then
    self:prepare_panel_info()
    return true
  else
    ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
    return false
  end
end


function mypanel:open_query(query)
  if not (query and query ~= "") then return false; end

  self._last_sql_query = query

  -- Check query for select
  local select_word = query:match("^%s*(%w*)");
  if select_word:lower() ~= "select" then
    -- Update query - just execute without read result
    local prg_wnd = progress.newprogress(M.ps_execsql)
    if not self._dbx:execute_query(query) then
      prg_wnd:hide()
      local err_descr = self._dbx:last_error()
      ErrMsg(M.ps_err_sql.."\n"..query.."\n"..err_descr)
      return false
    end
    prg_wnd:hide()
  else
    -- Get column description
    local db = self._dbx:db()
    local stmt = db:prepare(query)
    if (not stmt) or (stmt:step() ~= sql3.ROW and stmt.step() ~= sql3.DONE) then
      local err_descr = self._dbx:last_error()
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
  return {
    CurDir           = self._curr_object;
    Flags            = bit64.bor(F.OPIF_DISABLESORTGROUPS, F.OPIF_DISABLEFILTER);
    HostFile         = self._file_name;
    KeyBar           = self._panel_info.key_bar;
    PanelModesArray  = self._panel_info.modes;
    PanelModesNumber = #self._panel_info.modes;
    PanelTitle       = self._panel_info.title;
    StartPanelMode   = ("0"):byte();
  }
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
  if not self._dbx:get_objects_list(db_objects) then
    prg_wnd:hide()
    local err_descr = self._dbx:last_error()
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
  local curr_object = self._curr_object
  local dbx = self._dbx
  local db = dbx:db()

  local row_count = dbx:get_row_count(curr_object)
  if not row_count then
    ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
    return false
  end

  -- Find a name to use for ROWID (self._rowid_name)
  local query = "select * from '"..curr_object.."'"
  local stmt = db:prepare(query)
  if not stmt then
    return false
  end
  local col_names = stmt:get_names()
  stmt:finalize()
  for _,v in ipairs(col_names) do
    col_names[v:lower()]=true
  end
  self._rowid_name = nil
  for _,v in ipairs {"rowid", "oid", "_rowid_"} do
    if col_names[v] == nil then
      self._rowid_name = v
      break
    end
  end

  -- Find if ROWID exists
  self._has_rowid = true
  stmt = nil
  if self._rowid_name then
    query = "select "..self._rowid_name..",* from '"..curr_object.."'"
    stmt = db:prepare(query)
  end
  if not stmt then
    query = "select * from '"..curr_object.."'"
    stmt = db:prepare(query)
    if stmt then
      self._has_rowid = false
    else
      ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
      return false
    end
  end

  -- Add a special item with dots (..) in all columns
  local dot_item = { FileName=".."; CustomColumnData={}; }
  local items = { dot_item }
  for i = 1, #self._column_descr do
    dot_item.CustomColumnData[i] = ".."
  end

  -- Add real items
  local prg_wnd = progress.newprogress(M.ps_reading, row_count)
  for row = 1, row_count do
    if (row-1) % 100 == 0 then
      prg_wnd:update(row-1)
    end
    if stmt:step() ~= sql3.ROW then
      ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
      items = false
      break
    end
    if progress.aborted() then
      break -- Show incomplete data
    end

    -- Use index as file name, otherwise FAR cannot properly handle selections on the panel
    local item = { FileName=("%08d"):format(row); CustomColumnData={}; }
    items[row+1] = item -- shift by 1, as items[1] is dot_item

    local adjust = self._has_rowid and 0 or 1
    for j = 1, #self._column_descr do
      item.CustomColumnData[j] = exporter.get_text(stmt, j-adjust)
    end
    if self._has_rowid then
      item.AllocationSize = stmt:get_value(0)  -- This field used as row id
    end
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

  local db = self._dbx:db()
  local stmt = db:prepare(self._curr_object)
  if not stmt then
    prg_wnd:hide()
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  local state
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
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    stmt:finalize()
    return false
  end

  prg_wnd:hide()
  stmt:finalize()
  return buff
end


function mypanel:set_column_mask()
  -- Build dialog dynamically
  local col_num = #self._column_descr
  local FLAG_DFLT = bit64.bor(F.DIF_CENTERGROUP, F.DIF_DEFAULTBUTTON)
  local FLAG_NOCLOSE = bit64.bor(F.DIF_CENTERGROUP, F.DIF_BTNNOCLOSE)
  local dlg_items = {
    {F.DI_DOUBLEBOX, 3,1,56,col_num+4, 0,0,0,0, M.ps_title_select_columns},
  }
  local mask = self._col_masks and self._col_masks[self._curr_object]
  for i = 1,col_num do
    local text = mask and mask[self._column_descr[i].name]
    local check = text and 1 or 0
    table.insert(dlg_items, { F.DI_FIXEDIT,  5,1+i,7,0,     0,0,0,0, text or "0" })
    table.insert(dlg_items, { F.DI_CHECKBOX, 9,1+i,0,0, check,0,0,0, self._column_descr[i].name })
  end
  table.insert(dlg_items, {F.DI_TEXT,   0,2+col_num,0,0, 0,0,0,F.DIF_SEPARATOR,   ""})
  table.insert(dlg_items, {F.DI_BUTTON, 0,3+col_num,0,0, 0,0,0,FLAG_DFLT,         M.ps_ok})
  table.insert(dlg_items, {F.DI_BUTTON, 0,3+col_num,0,0, 0,0,0,FLAG_NOCLOSE,      M.ps_set_columns})
  table.insert(dlg_items, {F.DI_BUTTON, 0,3+col_num,0,0, 0,0,0,FLAG_NOCLOSE,      M.ps_reset_columns})
  table.insert(dlg_items, {F.DI_BUTTON, 0,3+col_num,0,0, 0,0,0,F.DIF_CENTERGROUP, M.ps_cancel})

  local btnSet, btnReset, btnCancel = 2*col_num+4, 2*col_num+5, 2*col_num+6

  local function SetEnable(hDlg)
    hDlg:send(F.DM_ENABLEREDRAW, 0)
    for pos = 1,col_num do
      local enab = hDlg:send(F.DM_GETCHECK, 2*pos+1)==F.BSTATE_CHECKED and 1 or 0
      hDlg:send(F.DM_ENABLE, 2*pos, enab)
    end
    hDlg:send(F.DM_ENABLEREDRAW, 1)
  end

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      SetEnable(hDlg)
      hDlg:send(F.DM_SETFOCUS, 3)
    elseif Msg == F.DN_BTNCLICK then
      local check = Param1==btnSet and F.BSTATE_CHECKED or Param1==btnReset and F.BSTATE_UNCHECKED
      if check then
        hDlg:send(F.DM_ENABLEREDRAW, 0)
        for pos = 1,col_num do hDlg:send(F.DM_SETCHECK, 2*pos+1, check); end
        hDlg:send(F.DM_ENABLEREDRAW, 1)
      end
      SetEnable(hDlg)
    end
  end

  local guid = win.Uuid("D252C184-9E10-4DE8-BD68-08A8A937E1F8")
  local res = far.Dialog(guid, -1, -1, 60, 6+col_num, "PanelView", dlg_items, nil, DlgProc)
  if res > 0 and res ~= btnCancel then
    mask = {}
    self._col_masks = self._col_masks or {}
    self._col_masks[self._curr_object] = mask
    local all_empty = true
    for k=1,col_num do
      if dlg_items[2*k+1][6] ~= 0 then
        local txt = dlg_items[2*k][10]
        mask[self._column_descr[k].name] = txt
        all_empty = false
      end
    end
    if all_empty and col_num > 0 then -- all columns should not be hidden - show the 1-st column
      mask[self._column_descr[1].name] = "0"
    end
    self._use_masks = true
    self._hist_obj:save()
  end
end


function mypanel:prepare_panel_info()
  local info = self._panel_info
  local col_types = ""
  local col_widths = ""
  local col_titles = {}
  local status_types = nil
  local status_widths = nil

  info.key_bar = {}
  info.title = M.ps_title_short .. ": " .. self._file_name:match("[^\\/]*$")

  if self._curr_object=="" or self._curr_object==nil then
    col_types     = "N,C0,C1"
    status_types  = "N,C0,C1"
    col_widths    = "0,8,9"
    status_widths = "0,8,9"
    table.insert(col_titles, M.ps_pt_name)
    table.insert(col_titles, M.ps_pt_type)
    table.insert(col_titles, M.ps_pt_count)

    self:add_keybar_label("DDL", VK.F4)
    self:add_keybar_label("Pragma", VK.F4, F.SHIFT_PRESSED)
    self:add_keybar_label("Export", VK.F5)
  else
    info.title = info.title .. " [" .. self._curr_object .. "]"
    local mask = self._use_masks and self._col_masks and self._col_masks[self._curr_object]
    for i,descr in ipairs(self._column_descr) do
      local width = mask and mask[descr.name]
      if width or not mask then
        if col_types ~= "" then
          col_types = col_types .. ","
        end
        col_types = col_types .. "C" .. (i-1)
        if col_widths ~= "" then
          col_widths = col_widths .. ','
        end
        col_widths = col_widths .. (width or "0")
        table.insert(col_titles, self._column_descr[i].name)
      end
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
  info.modes = {}
  local pm = {
    ColumnTypes  = col_types;
    ColumnWidths = col_widths;
    ColumnTitles = col_titles;
    StatusColumnTypes = status_types;
    StatusColumnWidths = status_widths;
  }
  for k=1,10 do info.modes[k] = pm; end
end


function mypanel:add_keybar_label(label, vkc, cks)
  local kbl = {
    Text = label;
    LongText = label;
    VirtualKeyCode = vkc;
    ControlKeyState = cks or 0;
  }
  table.insert(self._panel_info.key_bar, kbl)
end


function mypanel:delete_items(items, items_count)
  if self._panel_mode == pm_table and not (self._has_rowid and self._rowid_name) then
    ErrMsg(M.ps_err_del_norowid)
    return false
  end
  if self._panel_mode == pm_table or self._panel_mode == pm_db then
    local ed = myeditor.neweditor(self._dbx, self._curr_object, self._rowid_name)
    return ed:remove(items, items_count)
  end
  return false
end


function mypanel:handle_keyboard(key_event)
  local vcode  = key_event.VirtualKeyCode
  local cstate = key_event.ControlKeyState
  local nomods = cstate == 0
--local alt    = cstate == F.LEFT_ALT_PRESSED  or cstate == F.RIGHT_ALT_PRESSED
  local ctrl   = cstate == F.LEFT_CTRL_PRESSED or cstate == F.RIGHT_CTRL_PRESSED
  local shift  = cstate == F.SHIFT_PRESSED

  -- All modes -----------------------------------------------------------------
  do
    if ctrl and vcode == ("A"):byte() then       -- CtrlA: suppress this key
      return true
    elseif nomods and vcode == VK.F7 then        -- F7: suppress this key
      return true
    elseif nomods and vcode == VK.F6 then        -- F6: edit and execute SQL query
      self:edit_sql_query()
      return true
    end
  end

  -- Database view mode --------------------------------------------------------
  if self._panel_mode == pm_db then
    if nomods and vcode == VK.F3 then            -- F3: view table/view data
      self:view_db_object()
      return true
    elseif nomods and vcode == VK.F4 then        -- F4: view create statement
      self:view_db_create_sql()
      return true
    elseif shift and vcode == VK.F4 then         -- ShiftF4: view pragma statement
      self:view_pragma_statements()
      return true
    elseif nomods and vcode == VK.F5 then        -- F5: export table/view data
      local ex = exporter.newexporter(self._dbx)
      if ex:export_data_with_dialog() then
        panel.UpdatePanel(nil,0)
        panel.RedrawPanel(nil,0)
      end
      return true
    end

  -- Panel view mode -----------------------------------------------------------
  elseif self._panel_mode == pm_table then
    if nomods and (vcode == VK.F4 or vcode == VK.RETURN) then -- F4 or Enter: edit row
      if vcode == VK.RETURN then
        local item = panel.GetCurrentPanelItem(nil, 1)
        if not (item and item.FileName ~= "..") then          -- skip action for ".."
          return false
        end
      end
      if self._has_rowid and self._rowid_name then
        myeditor.neweditor(self._dbx, self._curr_object, self._rowid_name):update()
        return true
      else
        ErrMsg(M.ps_err_edit_norowid)
      end
    elseif shift and vcode == VK.F4 then         -- ShiftF4: insert row
      myeditor.neweditor(self._dbx, self._curr_object):insert()
      return true
    elseif nomods and vcode == VK.F5 then        -- F5: suppress this key
      return true
    elseif shift and vcode == VK.F3 then
      self:set_column_mask()
      self:prepare_panel_info()
      panel.RedrawPanel(nil,1)
      return true
    elseif ctrl and vcode == VK.F3 then
      self._use_masks = not self._use_masks
      self:prepare_panel_info()
      panel.RedrawPanel(nil,1)
      return true
    end

  -- All done ------------------------------------------------------------------
  end
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
    local cr_sql = self._dbx:get_creation_sql(item.FileName)
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
    local ex = exporter.newexporter(self._dbx)
    tmp_file_name = exporter.get_temp_file_name("txt")
    local ok = ex:export_data_as_text(tmp_file_name, item.FileName)
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
    local cr_sql = self._dbx:get_creation_sql(item.FileName)
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
    local db = self._dbx:db()
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
