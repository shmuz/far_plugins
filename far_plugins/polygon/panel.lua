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

local function get_temp_file_name(ext)
  return far.MkTemp() .. (ext and "."..ext or "")
end

-- This file's module. Could not be called "panel" due to existing LuaFAR global "panel".
local mypanel = {}
local mt_panel = { __index=mypanel }


function mypanel.open(file_name, extensions, foreign_keys)
  local self = {

  -- Members come from the original plugin SQLiteDB.
    _file_name       = file_name;
    _last_sql_query  = nil ;
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
    _show_affinity  = nil ;
    _tab_filter     = { enabled=false; text=nil; };
  }

  -- Members come from the original plugin SQLiteDB.
  self._panel_info = {
    title   = nil;
    modes   = nil;
    key_bar = nil;
  }

  setmetatable(self, mt_panel)

  self._dbx = sqlite.newsqlite()
  if self._dbx:open(file_name) then
    self:set_database_mode()
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
    ErrMsg(M.ps_err_open.."\n"..file_name)
    return nil
  end
end


function mypanel:set_directory(handle, Dir, UserData)
  self._tab_filter = {}
  if Dir == ".." or Dir == "/" or Dir == "\\" then
    self:set_database_mode()
    return true
  else
    local name = Params.DecodeDirName(Dir, UserData)
      if self._dbx:get_row_count(name) > 20000 then -- sorting is very slow on big tables
        panel.SetSortMode(handle, nil, "SM_UNSORTED")
        panel.SetSortOrder(handle, nil, false)
      end
    return self:open_object(name)
  end
end


function mypanel:set_database_mode()
  self._panel_mode = "db"
  self._curr_object = nil
  self:prepare_panel_info()
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


local function FindFirstTwoWords(query)
  local num
  local words = {}
  for k = 1,2 do
    repeat
      query, num = string.gsub(query, "^%s+", "") -- remove white space
      query, num = string.gsub(query, "^%-%-[^\n]*\n?", "") -- remove a comment
    until (num == 0)

    local w, q = query:match("([%w_]+)(.*)")
    if w then words[k], query = w, q
    else break
    end
  end
  return words[1], words[2]
end


function mypanel:open_query(handle, query)
  local word1, word2 = FindFirstTwoWords(query)
  if not word1 then return end
  word1 = word1:lower()

  -- Check query for select
  word2 = word2 and word2:lower()
  if (word1=="select" and word2~="load_extension") or
     (word1=="pragma" and word2=="database_list")
  then
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
      self._column_descr[i] = { name = name; }
    end

    stmt:finalize()
  else
    -- Update query - just execute without read result
    local prg_wnd = progress.newprogress(M.ps_execsql)
    if not self._dbx:execute_query(query, true) then
      prg_wnd:hide()
      return false
    end
    prg_wnd:hide()
  end

  local position = word1~="update" and {CurrentItem=1} or nil -- don't reset position on update
  self:prepare_panel_info()
  panel.UpdatePanel(handle, nil, false)
  panel.RedrawPanel(handle, nil, position)
  return true
end


function mypanel:get_panel_info(handle)
  local info = self._panel_info
  return {
    CurDir           = Params.EncodeDirName(self._curr_object);
    Flags            = bit64.bor(F.OPIF_DISABLESORTGROUPS,F.OPIF_DISABLEFILTER,F.OPIF_SHORTCUT);
    HostFile         = self._file_name;
    KeyBar           = info.key_bar;
    PanelModesArray  = info.modes;
    PanelModesNumber = #info.modes;
    PanelTitle       = info.title;
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

  local db_objects = self._dbx:get_objects_list()
  if not db_objects then
    prg_wnd:hide()
    ErrMsg(M.ps_err_read.."\n"..self._file_name.."\n"..self._dbx:last_error())
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
    Params.EncodeDirNameToItem(obj.name, item)
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
  local query
  local obj_norm = curr_object:normalize()
  if self._rowid_name then
    query = ("select %s.%s,* from %s"):format(obj_norm, self._rowid_name, obj_norm)
    local stmt = db:prepare(query)
    if stmt then stmt:finalize()
    else self._rowid_name = nil
    end
  end
  if not self._rowid_name then
    query = "select * from " .. obj_norm
  end

  local count_query = "select count(*) from " .. obj_norm
  if self._tab_filter.text and self._tab_filter.enabled then
    local tail = " "..self._tab_filter.text
    count_query = count_query..tail
    query = query..tail
  end

  local stmt = db:prepare(query)
  if not stmt then
    ErrMsg(M.ps_err_sql.."\n"..query.."\n"..dbx:last_error())
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
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  local prg_wnd = progress.newprogress(M.ps_reading)
  local state
  for row = 1, math.huge do
    state = stmt:step()
    if state ~= sql3.ROW then
      break
    end
    if (row-1) % 100 == 0 then
      if progress.aborted() then
        break  -- Show incomplete data
      end
      prg_wnd:update(row-1)
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
  prg_wnd:hide()
  stmt:finalize()

  if not (state==sql3.DONE or state==sql3.ROW) then
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

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
  if self._col_masks[self._curr_object] then
    self._col_masks_used = not self._col_masks_used
    self:prepare_panel_info()
    panel.UpdatePanel(handle,nil,true)
    panel.RedrawPanel(handle,nil)
  end
end


local function add_keybar_label (target, label, vkc, cks)
  local kbl = {
    Text = label;
    LongText = label;
    VirtualKeyCode = vkc;
    ControlKeyState = cks or 0;
  }
  table.insert(target, kbl)
end


local affinity_map = {
  INTEGER = " [i]";
  TEXT    = " [t]";
  BLOB    = " [b]";
  REAL    = " [r]";
  NUMERIC = " [n]";
}


function mypanel:prepare_panel_info()
  local col_types = ""
  local col_widths = ""
  local col_titles = {}
  local status_types = nil
  local status_widths = nil

  self._panel_info = {
    key_bar = {};
    modes   = {};
    title   = M.ps_title_short .. ": " .. self._file_name:match("[^\\/]*$");
  }
  local info = self._panel_info
  local key_bar = info.key_bar

  if self._panel_mode == "db" then
    col_types     = "N,C0,C1"
    status_types  = "N,C0,C1"
    col_widths    = "0,8,9"
    status_widths = "0,8,9"
    table.insert(col_titles, M.ps_pt_name)
    table.insert(col_titles, M.ps_pt_type)
    table.insert(col_titles, M.ps_pt_count)

    add_keybar_label (key_bar, "DDL", VK.F4)
    add_keybar_label (key_bar, "Pragma", VK.F4, F.SHIFT_PRESSED)
    add_keybar_label (key_bar, "Export", VK.F5)
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
        if self._show_affinity and self._panel_mode == "table" then
          table.insert(col_titles, descr.name..affinity_map[descr.affinity])
        else
          table.insert(col_titles, descr.name)
        end
      end
    end
    add_keybar_label (key_bar, "Update", VK.F4)
    add_keybar_label (key_bar, "Insert", VK.F4, F.SHIFT_PRESSED)
    add_keybar_label (key_bar, "", VK.F3)
    add_keybar_label (key_bar, "", VK.F3, F.SHIFT_PRESSED)
    add_keybar_label (key_bar, "", VK.F5)
  end
  add_keybar_label (key_bar, "SQL", VK.F6)
  add_keybar_label (key_bar, "", VK.F1, F.SHIFT_PRESSED)
  add_keybar_label (key_bar, "", VK.F2, F.SHIFT_PRESSED)
  add_keybar_label (key_bar, "", VK.F3, F.SHIFT_PRESSED)
  add_keybar_label (key_bar, "", VK.F5, F.SHIFT_PRESSED)
  add_keybar_label (key_bar, "", VK.F6, F.SHIFT_PRESSED)
  add_keybar_label (key_bar, "", VK.F7)
  add_keybar_label (key_bar, "", VK.F3, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  add_keybar_label (key_bar, "", VK.F4, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  add_keybar_label (key_bar, "", VK.F5, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  add_keybar_label (key_bar, "", VK.F6, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  add_keybar_label (key_bar, "", VK.F7, F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED)
  for i = VK.F1, VK.F12 do
    add_keybar_label (key_bar, "", i, F.LEFT_CTRL_PRESSED + F.RIGHT_CTRL_PRESSED)
  end

  -- Configure one panel view for all modes
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


function mypanel:delete_items(handle, items)
  if self._panel_mode == "table" and not self._rowid_name then
    ErrMsg(M.ps_err_del_norowid)
    return false
  end
  if self._panel_mode == "table" or self._panel_mode == "db" then
    local ed = myeditor.neweditor(self._dbx, self._curr_object, self._rowid_name)
    return ed:remove(items)
  end
  return false
end


function mypanel:set_table_filter(handle)
  local guid        = win.Uuid("920436C2-C32D-487F-B590-0E255AD71038")
  local query       = "SELECT * FROM "..self._curr_object:normalize()
  local hist_extra  = "Polygon_PanelFilterExt"
  local hist_where  = "Polygon_PanelFilter"
  local flag_edit   = F.DIF_HISTORY + F.DIF_USELASTHISTORY
  local flag_separ  = F.DIF_SEPARATOR
  local flag_ok     = F.DIF_DEFAULTBUTTON+F.DIF_CENTERGROUP
  local flag_cancel = F.DIF_CENTERGROUP

  local Items = {
    --[[01]] {F.DI_DOUBLEBOX,  3, 1,72, 8,   0, 0,          0, 0,            M.ps_panel_filter},
    --[[02]] {F.DI_TEXT,       5, 2, 0, 0,   0, 0,          0, 0,            query},
    --[[03]] {F.DI_EDIT,       5, 3,70, 0,   0, hist_extra, 0, flag_edit,    ""},
    --[[04]] {F.DI_TEXT,       5, 4, 0, 0,   0, 0,          0, 0,            "WHERE"},
    --[[05]] {F.DI_EDIT,       5, 5,70, 0,   0, hist_where, 0, flag_edit,    ""},
    --[[06]] {F.DI_TEXT,      -1, 6, 0, 0,   0, 0,          0, flag_separ,   ""},
    --[[07]] {F.DI_BUTTON,     0, 7, 0, 0,   0, 0,          0, flag_ok,      M.ps_ok},
    --[[08]] {F.DI_BUTTON,     0, 7, 0, 0,   0, 0,          0, flag_cancel,  M.ps_cancel},
  }
  local edtExtra, edtWhere, btnOK = 3, 5, 7

  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_CLOSE and Param1 == btnOK then
      local extra = hDlg:send("DM_GETTEXT", edtExtra)
      local where = hDlg:send("DM_GETTEXT", edtWhere)
      local text = where:find("%S") and (extra.." WHERE "..where) or extra
      local stmt = self._dbx:db():prepare(query.." "..text)
      if stmt then -- check syntax
        stmt:finalize()
        self._tab_filter.text = text
        self._tab_filter.enabled = true
      else
        ErrMsg(M.ps_err_sql.."\n"..self._dbx:last_error())
        return 0
      end
    end
  end

  if far.Dialog(guid,-1,-1,76,10,"PanelFilter",Items,nil,DlgProc) == btnOK then
    panel.UpdatePanel(handle)
    panel.RedrawPanel(handle)
  end
end


function mypanel:toggle_table_filter(handle)
  if self._tab_filter.text then
    self._tab_filter.enabled = not self._tab_filter.enabled
    panel.UpdatePanel(handle)
    panel.RedrawPanel(handle)
  end
end


function mypanel:handle_keyboard(handle, key_event)
  local vcode  = key_event.VirtualKeyCode
  local cstate = key_event.ControlKeyState
  local nomods = (cstate == 0) or (cstate == F.ENHANCED_KEY)
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
      local ex = exporter.newexporter(self._dbx, self._file_name)
      if ex:export_data_with_dialog() then
        panel.UpdatePanel(nil,0)
        panel.RedrawPanel(nil,0)
      end
      return true
    elseif ctrl and vcode == VK.D then
      local ex = exporter.newexporter(self._dbx, self._file_name)
      ex:dump_data_with_dialog()
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
        local ed = myeditor.neweditor(self._dbx, self._curr_object, self._rowid_name)
        ed:edit_item(handle)
        return true
      else
        ErrMsg(M.ps_err_edit_norowid)
      end
    elseif shift and vcode == VK.F4 then         -- ShiftF4: insert row
      local ed = myeditor.neweditor(self._dbx, self._curr_object, self._rowid_name)
      ed:insert_item(handle)
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
    elseif ctrl and vcode == VK.A then           -- Ctrl-A ("show/hide columns affinity")
      self._show_affinity = not self._show_affinity
      self:prepare_panel_info()
      panel.RedrawPanel(handle)
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
  elseif shift and vcode == VK.F6 then         -- ShiftF6: suppress this key
    return true
  elseif nomods and vcode == VK.F7 then        -- F7: suppress this key
    return true
  elseif nomods and vcode == VK.F8 then -- intercept F8 to avoid panel-reread in case of user cancel
    if self._panel_mode == "db" or self._panel_mode == "table" then
      if panel.GetPanelInfo(handle).SelectedItemsNumber > 0 then
        local guid = win.Uuid("4472C7D8-E2B2-46A0-A005-B10B4141EBBD") -- for macros
        if far.Message(M.ps_drop_question, M.ps_title_short, ";YesNo", "w", nil, guid) == 1 then
          return nil
        end
      end
    end
    return true
  elseif shift and vcode == VK.F8 then         -- ShiftF8: suppress this key
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
  local RealItemName = Params.DecodeItemName(item)

  -- For unknown types show create sql only
  if not item.FileAttributes:find("d") then
    local cr_sql = self._dbx:get_creation_sql(item.FileName)
    if not cr_sql then
      return
    end
    tmp_file_name = get_temp_file_name("sql")

    local file = io.open(tmp_file_name, "wb")
    if not file then
      ErrMsg(M.ps_err_writef.."\n"..tmp_file_name, nil, "we")
      return
    end
    if not file:write(cr_sql) then
      file:close()
      ErrMsg(M.ps_err_writef.."\n"..tmp_file_name, nil, "we")
      return
    end
    file:close()
  else
    -- Export data
    local ex = exporter.newexporter(self._dbx, self._file_name)
    tmp_file_name = get_temp_file_name("txt")
    local ok = ex:export_data_as_text(tmp_file_name, RealItemName)
    if not ok then return end
  end
  local title = M.ps_title_short .. ": " .. RealItemName
  viewer.Viewer(tmp_file_name, title, 0, 0, -1, -1, bit64.bor(
    F.VF_ENABLE_F6, F.VF_DISABLEHISTORY, F.VF_DELETEONLYFILEONCLOSE, F.VF_IMMEDIATERETURN, F.VF_NONMODAL), 65001)
  viewer.SetMode(nil, { Type=F.VSMT_WRAP,     iParam=0,          Flags=0 })
  viewer.SetMode(nil, { Type=F.VSMT_VIEWMODE, iParam=F.VMT_TEXT, Flags=F.VSMFL_REDRAW })
end


function mypanel:view_db_create_sql()
  -- Get selected object name
  local item = panel.GetCurrentPanelItem(nil, 1)
  if item and item.FileName ~= ".." then
    local RealItemName = Params.DecodeItemName(item)
    local cr_sql = self._dbx:get_creation_sql(RealItemName)
    if cr_sql then
      local tmp_path = far.MkTemp()..".sql"
      local file = io.open(tmp_path, "w")
      if file and file:write(cr_sql) then
        file:close()
        viewer.Viewer(tmp_path, RealItemName, nil, nil, nil, nil,
          F.VF_ENABLE_F6 + F.VF_DISABLEHISTORY + F.VF_DELETEONLYFILEONCLOSE + F.VF_NONMODAL, 65001)
      else
        if file then file:close() end
        ErrMsg(M.ps_err_writef.."\n"..tmp_path, nil, "we")
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
  local list_items = {}
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
        table.insert(list_items, { Text=pv })
      end
      stmt:finalize()
    end
  end

  if list_items[1] then
    local guid = win.Uuid("FF769EE0-2643-48F1-A8A2-239CD3C6691F")
    local list_flags = F.DIF_LISTNOBOX + F.DIF_LISTNOAMPERSAND + F.DIF_FOCUS
    local btn_flags = F.DIF_CENTERGROUP + F.DIF_DEFAULTBUTTON
    local dlg_items = {
      {"DI_DOUBLEBOX", 3, 1,56,18,          0, 0, 0, 0,               M.ps_title_pragma},
      {"DI_LISTBOX",   4, 2,55,15, list_items, 0, 0, list_flags,      ""},
      {"DI_TEXT",      0,16, 0,16,          0, 0, 0, F.DIF_SEPARATOR, ""},
      {"DI_BUTTON",   60,17, 0, 0,          0, 0, 0, btn_flags,       M.ps_ok}
    }
    far.Dialog(guid, -1, -1, 60, 20, nil, dlg_items)
  end
end


function mypanel:edit_sql_query(handle)
  -- Create a file and save the last used query if any.
  local tmp_name = get_temp_file_name("sql")
  local fp = io.open(tmp_name, "w")
  if fp then
    if self._last_sql_query then
      fp:write(self._last_sql_query)
    end
    fp:close()
  else
    ErrMsg(M.ps_err_writef.."\n"..tmp_name, nil, "we")
    return
  end

  -- Open query editor.
  if F.EEC_MODIFIED == editor.Editor(tmp_name, "SQLite query", nil, nil, nil, nil,
                       F.EF_DISABLESAVEPOS + F.EF_DISABLEHISTORY, nil, nil, 65001)
  then
    fp = io.open(tmp_name, "rb")
    if fp then
      local query = fp:read("*all")
      query = string.gsub(query, "^\239\187\191", "") -- remove UTF-8 BOM
      query = string.gsub(query, "\r\n", "\n")
      fp:close()
      if query:find("%S") then
        self._last_sql_query = query
        self:open_query(handle, query)
      end
    else
      ErrMsg(M.ps_err_read.."\n"..tmp_name, nil, "we")
    end
  end

  -- Delete the file.
  win.DeleteFile(tmp_name)
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


local function get_rowid(PanelItem)
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
    get_rowid   = get_rowid;
  }
end


return mypanel
