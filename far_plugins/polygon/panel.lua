-- panel.lua
-- luacheck: globals ErrMsg

local sql3    = require "lsqlite3"
local history = require "far2.history"

local F = far.Flags
local VK = win.GetVirtualKeys()
local win_CompareString = win.CompareString

local Params = ...
local M        = Params.M
local exporter = Params.exporter
local myeditor = Params.myeditor
local progress = Params.progress
local sqlite   = Params.sqlite

-- This file's module. Could not be called "panel" due to existing LuaFAR global "panel".
local mypanel = {}
local mt_panel = {__index=mypanel}


function mypanel.open(file_name, silent, extensions, foreign_keys)
  local self = {

  -- Members come from the original plugin SQLiteDB.
    _file_name       = file_name;
    _last_sql_query  = ""  ;
    _column_descr    = nil ;
    _curr_object     = nil ;
    _dbx             = nil ;
    _panel_mode      = nil ; -- valid values are: "db", "table", "view", "query"

  -- Members added since this plugin started.
    _col_masks      = nil ; -- col_masks table (non-volatile)
    _col_masks_used = nil ;
    _rowid_name     = nil ;
    _hist_file      = nil ; -- files[<filename>] in the plugin's non-volatile settings
    _sort_col_index = nil ;
    _sort_last_mode = nil ;
    _tab_filter     = nil ;
    _tab_filter_enb = nil ;
  }

  -- Members come from the original plugin SQLiteDB.
  self._panel_info = {
    title   = "" ;
    modes   = {} ;
    key_bar = {} ;
  }

  setmetatable(self, mt_panel)

  self._dbx = sqlite.newsqlite()
  if self._dbx:open(file_name) and self:open_database() then
    local db = self._dbx:db()
    if extensions then
      db:load_extension("") -- enable extensions
    end
    if foreign_keys then
      db:exec("PRAGMA foreign_keys = ON;")
    end
    self._hist_file = history.newsettings("files", file_name:lower(), "PSL_LOCAL")
    self._col_masks = self._hist_file:field("col_masks")
    self._col_masks_used = false
    return self
  else
    if not silent then
      ErrMsg(M.ps_err_open.."\n"..file_name)
    end
    return nil
  end
end


function mypanel:set_directory(handle, Dir)
  self._tab_filter = false
  self._tab_filter_enb = false
  if Dir == ".." or Dir == "/" or Dir == "\\" then
    return self:open_database()
  else
    return self:open_object(Dir)
  end
end


function mypanel:open_database()
  self._panel_mode = "db"
  self._curr_object = ""
  self:prepare_panel_info()
  return true
end


function mypanel:open_object(object_name)
  local dbx = self._dbx
  local tp = dbx:get_object_type(object_name)
  if tp == sqlite.ot_master or tp == sqlite.ot_table then
    self._panel_mode = "table"
  elseif tp == sqlite.ot_view then
    self._panel_mode = "view"
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


function mypanel:open_query(handle, query)
  local word1 = query:match("^%s*([%w_]+)")
  if not word1 then return end

  -- Check query for select
  local word2 = query:match("^%s+([%w_]+)", #word1+1)
  if word1:lower() == "select" and not (word2 and word2:lower()=="load_extension") then
    -- Get column description
    local db = self._dbx:db()
    local stmt = db:prepare(query)
    if not stmt then
      ErrMsg(M.ps_err_sql.."\n"..query.."\n"..self._dbx:last_error())
      return false
    end
    local state = stmt:step()
    if state == sql3.ERROR or state == sql3.MISUSE then
      ErrMsg(M.ps_err_sql.."\n"..query.."\n"..self._dbx:last_error())
      stmt:finalize()
      return false
    end

    self._last_sql_query = query
    self._panel_mode = "query"
    self._curr_object = query

    stmt:reset()
    self._column_descr = {}
    for i, name in ipairs(stmt:get_names()) do
      self._column_descr[i] = { name = name; type = sqlite.ct_text; }
    end

    stmt:finalize()
  else
    -- Update query - just execute without read result
    local prg_wnd = progress.newprogress(M.ps_execsql)
    if not self._dbx:execute_query(query) then
      prg_wnd:hide()
      ErrMsg(M.ps_err_sql.."\n"..query.."\n"..self._dbx:last_error())
      return false
    end
    prg_wnd:hide()
  end

  self:prepare_panel_info()
  panel.UpdatePanel(handle, nil, false)
  panel.RedrawPanel(handle, nil, {CurrentItem=1})
  return true
end


function mypanel:get_panel_info(handle)
  return {
    CurDir           = self._curr_object;
    Flags            = bit64.bor(F.OPIF_DISABLESORTGROUPS,F.OPIF_DISABLEFILTER,F.OPIF_SHORTCUT);
    HostFile         = self._file_name;
    KeyBar           = self._panel_info.key_bar;
    PanelModesArray  = self._panel_info.modes;
    PanelModesNumber = #self._panel_info.modes;
    PanelTitle       = self._panel_info.title;
    ShortcutData     = "";
    StartPanelMode   = ("1"):byte();
  }
end


function mypanel:get_panel_list(handle)
  local rc = false
  self._sort_last_mode = nil
  if self._panel_mode=="db" then
    rc = self:get_panel_list_db()
    panel.SetDirectoriesFirst(handle, nil, false)
  elseif self._panel_mode=="table" or self._panel_mode=="view" then
    rc = self:get_panel_list_obj()
  elseif self._panel_mode == "query" then
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

  local items = { { FileName=".."; FileAttributes="d"; } }
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
    if     obj.type==sqlite.ot_master  then tp="metadata"
    elseif obj.type==sqlite.ot_table   then tp="table"
    elseif obj.type==sqlite.ot_view    then tp="view"
    elseif obj.type==sqlite.ot_index   then tp="index"
    elseif obj.type==sqlite.ot_trigger then tp="trigger"
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

  -- Find a name to use for ROWID (self._rowid_name)
  self._rowid_name = nil
  if self._panel_mode == "table" then
    local stmt = db:prepare("select * from " .. curr_object:normalize())
    if stmt then
      local map = {}
      for _,colname in ipairs(stmt:get_names()) do
        map[colname:lower()] = true
      end
      for _,name in ipairs {"rowid", "oid", "_rowid_"} do
        if map[name] == nil then
          self._rowid_name = name
          break
        end
      end
      stmt:finalize()
    else
      ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
      return false
    end
  end

  -- Add a special item with dots (..) in all columns.
  local items = {}
  items[1] = { FileName=".."; FileAttributes="d"; CustomColumnData={}; }
  for i = 1, #self._column_descr do
    items[1].CustomColumnData[i] = ".."
  end

  -- If ROWID exists then select it as the leftmost column.
  local count_query = "select count(*) from " .. curr_object:normalize()
  local query = self._rowid_name
    and ("select %s,* from %s"):format(self._rowid_name, curr_object:normalize())
    or   "select * from " .. curr_object:normalize()
  if self._tab_filter and self._tab_filter_enb then
    count_query = count_query .. " where " .. self._tab_filter
    query       =       query .. " where " .. self._tab_filter
  end

  local stmt = db:prepare(query)
  if not stmt then
    ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
    return items
  end

  -- Get row count
  local count_stmt = db:prepare(count_query)
  count_stmt:step()
  local row_count = count_stmt:get_value(0)
  count_stmt:finalize()

  -- Add real items
  local prg_wnd = progress.newprogress(M.ps_reading, row_count)
  for row = 1, row_count do
    if (row-1) % 100 == 0 then
      prg_wnd:update(row-1)
    end
    local res = stmt:step()
    if res == sql3.DONE then
      break
    elseif res ~= sql3.ROW then
      ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
      items = false
      break
    end
    if progress.aborted() then
      break -- Show incomplete data
    end

    local item = { CustomColumnData={}; }
    items[row+1] = item -- shift by 1, as items[1] is dot_item

    if self._rowid_name then
      for i = 1,#self._column_descr do
        item.CustomColumnData[i] = exporter.get_text(stmt, i, true)
      end
      -- the leftmost column is ROWID (according to the query used)
      local rowid = stmt:get_value(0)
      -- this field is used for holding ROWID
      item.AllocationSize = rowid
      -- use ROWID as file name, otherwise FAR cannot properly handle selections on the panel
      item.FileName = ("%010d"):format(rowid)
    else
      for i = 1,#self._column_descr do
        item.CustomColumnData[i] = exporter.get_text(stmt, i-1, true)
      end
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
  local dot_item = { FileName=".."; FileAttributes="d"; }

  -- All dots (..)
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
      custom_column_data[j] = exporter.get_text(stmt, j-1, true)
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


function mypanel:set_column_mask(handle)
  -- Build dialog dynamically
  local dlg_width = 72
  local col_num = #self._column_descr
  local FLAG_DFLT = bit64.bor(F.DIF_CENTERGROUP, F.DIF_DEFAULTBUTTON)
  local FLAG_NOCLOSE = bit64.bor(F.DIF_CENTERGROUP, F.DIF_BTNNOCLOSE)
  local dlg_items = {
    {F.DI_DOUBLEBOX, 3,1,dlg_width-4,col_num+4, 0,0,0,0, M.ps_title_select_columns},
  }
  local mask = self._col_masks[self._curr_object]
  for i = 1,col_num do
    local text = mask and mask[self._column_descr[i].name]
    local check = text and 1 or 0
    local name = self._column_descr[i].name
    local name_len = name:len()
    if name_len > dlg_width-18 then
      name = name:sub(1,dlg_width-21).."..."
    end
    table.insert(dlg_items, { F.DI_FIXEDIT,  5,1+i,7,0,     0,0,0,0, text or "0" })
    table.insert(dlg_items, { F.DI_CHECKBOX, 9,1+i,0,0, check,0,0,0, name })
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
  local res = far.Dialog(guid, -1, -1, dlg_width, 6+col_num, "PanelView", dlg_items, nil, DlgProc)
  if res > 0 and res ~= btnCancel then
    mask = {}
    self._col_masks[self._curr_object] = mask
    local all_empty = true
    for k=1,col_num do
      if dlg_items[2*k+1][6] ~= 0 then
        mask[self._column_descr[k].name] = dlg_items[2*k][10]
        all_empty = false
      end
    end
    if all_empty and col_num > 0 then -- all columns should not be hidden - show the 1-st column
      mask[self._column_descr[1].name] = "0"
    end
    self._col_masks_used = true
    self._hist_file:save()
    self:prepare_panel_info()
    panel.UpdatePanel(handle,nil,true)
    panel.RedrawPanel(handle,nil)
  end
end


function mypanel:toggle_column_mask(handle)
  self._col_masks_used = not self._col_masks_used
  self:prepare_panel_info()
  panel.UpdatePanel(handle,nil,true)
  panel.RedrawPanel(handle,nil)
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
    local mask = self._col_masks_used and self._col_masks[self._curr_object]
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
  local pm1 = {
    ColumnTypes  = col_types;
    ColumnWidths = col_widths;
    ColumnTitles = col_titles;
    StatusColumnTypes = status_types;
    StatusColumnWidths = status_widths;
  }
  local pm2 = {}
  for k,v in pairs(pm1) do pm2[k]=v; end
  pm2.Flags = F.PMFLAGS_FULLSCREEN
  for k=1,10 do
    info.modes[k] = (k%2==1) and pm2 or pm1
  end
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


function mypanel:delete_items(handle, items, items_count)
  if self._panel_mode == "table" and not self._rowid_name then
    ErrMsg(M.ps_err_del_norowid)
    return false
  end
  if self._panel_mode == "table" or self._panel_mode == "db" then
    local ed = myeditor.neweditor(self._dbx, self._curr_object, self._rowid_name)
    return ed:remove(items, items_count)
  end
  return false
end


function mypanel:set_table_filter(handle)
  local query = "SELECT * FROM "..self._curr_object:normalize().." WHERE "
  local text = far.InputBox(nil, M.ps_panel_filter, query, "Polygon_PanelFilter", nil, nil, "PanelFilter")
  if text then
    local stmt = self._dbx:db():prepare(query..text)
    if stmt then -- check syntax
      stmt:finalize()
      self._tab_filter = text
      self._tab_filter_enb = true
      panel.UpdatePanel(handle)
      panel.RedrawPanel(handle)
    else
      ErrMsg(M.ps_err_read.."\n"..self._dbx:last_error())
    end
  end
end


function mypanel:toggle_table_filter(handle)
  if self._tab_filter then
    self._tab_filter_enb = not self._tab_filter_enb
    panel.UpdatePanel(handle)
    panel.RedrawPanel(handle)
  end
end


function mypanel:handle_keyboard(handle, key_event)
  local vcode  = key_event.VirtualKeyCode
  local cstate = key_event.ControlKeyState
  local nomods = cstate == 0
--local alt    = cstate == F.LEFT_ALT_PRESSED  or cstate == F.RIGHT_ALT_PRESSED
  local ctrl   = cstate == F.LEFT_CTRL_PRESSED or cstate == F.RIGHT_CTRL_PRESSED
  local shift  = cstate == F.SHIFT_PRESSED

  -- Database mode -------------------------------------------------------------
  if self._panel_mode == "db" then
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

  -- Table mode ----------------------------------------------------------------
  elseif self._panel_mode == "table" then
    if nomods and (vcode == VK.F4 or vcode == VK.RETURN) then -- F4 or Enter: edit row
      if vcode == VK.RETURN then
        local item = panel.GetCurrentPanelItem(nil, 1)
        if not (item and item.FileName ~= "..") then          -- skip action for ".."
          return false
        end
      end
      if self._rowid_name then
        myeditor.neweditor(self._dbx, self._curr_object, self._rowid_name):update()
        return true
      else
        ErrMsg(M.ps_err_edit_norowid)
      end
    elseif shift and vcode == VK.F4 then         -- ShiftF4: insert row
      myeditor.neweditor(self._dbx, self._curr_object):insert()
      return true
    elseif shift and vcode == VK.F3 then
      self:set_column_mask(handle)
      return true
    elseif shift and vcode == VK.F5 then
      self:toggle_column_mask(handle)
      return true
    elseif ctrl and vcode == VK.F then           -- Ctrl-F ("panel filter")
      self:set_table_filter(handle)
      return true;
    elseif ctrl and vcode == VK.G then           -- Ctrl-G ("toggle panel filter")
      self:toggle_table_filter(handle)
      return true
    end

  -- View mode ----------------------------------------------------------------
  elseif self._panel_mode == "view" then
    if shift and vcode == VK.F3 then
      self:set_column_mask(handle)
      return true
    elseif shift and vcode == VK.F5 then
      self:toggle_column_mask(handle)
      return true
    elseif ctrl and vcode == VK.F then           -- Ctrl-F ("panel filter")
      self:set_table_filter(handle)
      return true;
    elseif ctrl and vcode == VK.G then           -- Ctrl-G ("toggle panel filter")
      self:toggle_table_filter(handle)
      return true
    end

  -- Query mode ----------------------------------------------------------------
  elseif self._panel_mode == "query" then
    -- nothing for the moment

  end

  -- All modes -----------------------------------------------------------------
  if nomods and vcode == VK.F6 then            -- F6: edit and execute SQL query
    self:edit_sql_query(handle)
    return true
  elseif shift and vcode == VK.F4 then         -- ShiftF4: suppress this key
    return true
  elseif nomods and vcode == VK.F5 then        -- F5: suppress this key
    return true
  elseif nomods and vcode == VK.F7 then        -- F7: suppress this key
    return true
  elseif ctrl and vcode == ("A"):byte() then   -- CtrlA: suppress this key
    return true
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


function mypanel:edit_sql_query(handle)
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
    self:open_query(handle, self._last_sql_query)
  end
end


local SortMap = {
  [ F.SM_NAME     ] = 1,
  [ F.SM_EXT      ] = 2,
  [ F.SM_MTIME    ] = 3,
  [ F.SM_SIZE     ] = 4,
  [ F.SM_UNSORTED ] = 5,
  [ F.SM_CTIME    ] = 6,
  [ F.SM_ATIME    ] = 7,
  [ F.SM_DESCR    ] = 8,
  [ F.SM_OWNER    ] = 9,
}


function mypanel:get_sort_index(Mode)
  if self._panel_mode=="table" or self._panel_mode=="view" then
    local index = 0
    local pos_from_left = SortMap[Mode]
    if pos_from_left then
      for dd in self._panel_info.modes[1].ColumnTypes:gmatch("%d+") do -- ColumnTypes: e.g. C0,C4,C6
        index = index + 1
        if index == pos_from_left then
          return tonumber(dd) + 1
        end
      end
    end
  end
end


function mypanel:compare(PanelItem1, PanelItem2, Mode)
  if self._panel_mode == "db" then
    if Mode == F.SM_EXT then
      -- sort by object type
      return win_CompareString(
        PanelItem1.CustomColumnData[1],
        PanelItem2.CustomColumnData[1], "u", "cS") or 0
    else
      -- use Far Manager compare function
      return -2
    end
  else
    if self._sort_last_mode ~= Mode then
      self._sort_last_mode = Mode
      self._sort_col_index = self:get_sort_index(Mode)
    end
    local index = self._sort_col_index
    if index then
      return win_CompareString(
        PanelItem1.CustomColumnData[index],
        PanelItem2.CustomColumnData[index], "u", "cS") or 0
    else
      return 0
    end
  end
end


function mypanel.get_rowid(PanelItem)
  local fname = PanelItem and PanelItem.FileName
  return fname and fname~=".." and PanelItem.AllocationSize
end


function mypanel:get_info()
  return {
    db          = self._dbx:db();
    file_name   = self._file_name;
    panel_mode  = self._panel_mode;
    curr_object = self._curr_object;
    rowid_name  = self._rowid_name;
    get_rowid   = mypanel.get_rowid;
  }
end


return mypanel
