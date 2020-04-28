-- coding: UTF-8

local sql3     = require "lsqlite3"
local history  = require "far2.history"
local M        = require "modules.string_rc"
local exporter = require "modules.exporter"
local myeditor = require "modules.editor"
local progress = require "modules.progress"
local sqlite   = require "modules.sqlite"
local utils    = require "modules.utils"

local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor
local CompareString = win.CompareString
local ErrMsg, Resize, Norm = utils.ErrMsg, utils.Resize, utils.Norm

local function get_temp_file_name(ext)
  return far.MkTemp() .. (ext and "."..ext or "")
end

-- This file's module. Could not be called "panel" due to existing LuaFAR global "panel".
local mypanel = {}
local mt_panel = { __index=mypanel }


function mypanel.open(file_name, extensions, foreign_keys, multi_db)
  local self = {

  -- Members come from the original plugin SQLiteDB.
    _file_name       = file_name;
    _last_sql_query  = nil ;
    _column_descr    = nil ;
    _object          = ""  ;
    _dbx             = nil ;
    _panel_mode      = "root"; -- valid values are: "root", "db", "table", "view", "query"

  -- Members added since this plugin started.
    _db             = nil ;
    _schema         = ""  ;
    _col_masks      = nil ; -- col_masks table (non-volatile)
    _col_masks_used = nil ;
    _rowid_name     = nil ;
    _hist_file      = nil ; -- files[<filename>] in the plugin's non-volatile settings
    _sort_col_index = nil ;
    _sort_last_mode = nil ;
    _show_affinity  = nil ;
    _tab_filter     = { enabled=false; text=nil; };
    _multi_db       = multi_db;
  }

  -- Members come from the original plugin SQLiteDB.
  self._panel_info = {
    title   = nil;
    modes   = nil;
    key_bar = nil;
  }

  setmetatable(self, mt_panel)

  local dbx = sqlite.newsqlite()
  if dbx:open(file_name) then
    ---self:set_database_mode()
    self._dbx = dbx
    self._db = dbx:db()
    if self._multi_db then
      self:set_root_mode()
    else
      self:set_database_mode("main")
    end
    if extensions then
      self._db:load_extension("") -- enable extensions
    end
    if foreign_keys then
      self._db:exec("PRAGMA foreign_keys = ON;")
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


function mypanel:set_directory(aHandle, aDir, aUserData)
--far.Show("aDir, self._panel_mode, self._object", aDir, self._panel_mode, self._object)
  local success = true
  self._tab_filter = {}
  ----------------------------------------------------------------------------------------
  if aDir == "/" or aDir == "\\" then
    if self._multi_db then
      self:set_root_mode()
    else
      if self._panel_mode == "db" then
        panel.ClosePanel(aHandle)
        return false
      else
        self:set_database_mode("main")
      end
    end
  ----------------------------------------------------------------------------------------
  elseif aDir == ".." then
    if self._multi_db then
      if self._panel_mode == "db" or self._panel_mode == "query" then
        self:set_root_mode()
      else -- "table" or "view"
        self:set_database_mode()
      end
    else
      if self._panel_mode == "db" then
        panel.ClosePanel(aHandle)
        return false
      elseif self._panel_mode == "query" then
        self:set_database_mode("main")
      else
        self:set_database_mode()
      end
    end
  ----------------------------------------------------------------------------------------
  else -- any directory except "/", "\\", ".."
    local abspath, schema, bslash, object = aDir:match [[^(\?)([^\]+)(\?)([^\]*)$]]
    if abspath==nil or (bslash=="\\" and object=="") then
      return false
    end
    if abspath == "\\" then
      if self:database_exists(schema) then
        if object ~= "" then
          success = self:table_or_view_exists(schema,object) and
                    self:open_object(aHandle, schema, object)
        else
          self:set_database_mode(schema)
        end
      end
    else -- relative path
      if object == "" then
        if self._panel_mode == "root" then
          if self:database_exists(schema) then
            self:set_database_mode(schema)
          end
        elseif self._panel_mode == "db" then
          object = schema
          success = self:table_or_view_exists(self._schema, object) and
                    self:open_object(aHandle, self._schema, object)
        end
      end -- if object == ""
    end -- absolute/relative path
  end -- if not special directory name
  if success then
    self:prepare_panel_info()
    return true
  end
end


function mypanel:set_root_mode()
  self._schema = ""
  self._object = ""
  self._panel_mode = "root"
  self:prepare_panel_info()
end


function mypanel:set_database_mode(aSchema)
  if aSchema then
    self._schema = aSchema
  end
  self._object = ""
  self._panel_mode = "db"
  self:prepare_panel_info()
end


function mypanel:open_object(aHandle, aSchema, aObject)
  local tp = self._dbx:get_object_type(aSchema, aObject)
  local panel_mode = (tp==sqlite.ot_master or tp==sqlite.ot_table) and "table" or
                     (tp == sqlite.ot_view) and "view"
  if panel_mode then
    local column_descr = self._dbx:read_column_description(aSchema, aObject)
    if column_descr then
      self._schema       = aSchema
      self._object       = aObject
      self._panel_mode   = panel_mode
      self._column_descr = column_descr

      local count = self._dbx:get_row_count(self._schema, self._object) or 0
      if count > 20000 then -- sorting is very slow on big tables
        panel.SetSortMode(aHandle, nil, "SM_UNSORTED")
        panel.SetSortOrder(aHandle, nil, false)
      end
      return true
    end
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
    local stmt = self._db:prepare(query)
    if not stmt then
      self._dbx:SqlErrMsg(query)
      return false
    end
    local state = stmt:step()
    if state == sql3.ERROR or state == sql3.MISUSE then
      self._dbx:SqlErrMsg(query)
      stmt:finalize()
      return false
    end

    self._last_sql_query = query
    self._panel_mode = "query"
    self._object = query

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
      panel.UpdatePanel(handle)
      panel.RedrawPanel(handle)
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
  local CurDir = self._schema
  if self._object ~= "" then CurDir = CurDir.."\\"..self._object; end
  if CurDir ~= "" then CurDir = "\\"..CurDir; end

  local Info  = self._panel_info
  local Flags = bor(F.OPIF_DISABLESORTGROUPS,F.OPIF_DISABLEFILTER,F.OPIF_SHORTCUT)
  return {
    CurDir           = CurDir;
    Flags            = Flags;
    HostFile         = self._file_name;
    KeyBar           = Info.key_bar;
    PanelModesArray  = Info.modes;
    PanelModesNumber = #Info.modes;
    PanelTitle       = Info.title;
    ShortcutData     = "";
    StartPanelMode   = ("1"):byte();
  }
end


-- try to avoid returning false as it closes the panel (that may cause data loss)
function mypanel:get_find_data(handle)
  self._sort_last_mode = nil
  ------------------------------------------------------------------------------
  if self._panel_mode == "root" then
    return self:get_panel_list_root()
  ------------------------------------------------------------------------------
  elseif self._panel_mode == "query" then
    return self:get_panel_list_query()
  ------------------------------------------------------------------------------
  elseif self:database_exists(self._schema) then
    if self._panel_mode == "db" then
      local rc = self:get_panel_list_db()
      if rc then
        panel.SetDirectoriesFirst(handle, nil, false)
        return rc
      else
        self:set_root_mode() -- go up one level
        return self:get_find_data(handle)
      end
    elseif self._panel_mode=="table" or self._panel_mode=="view" then
      local rc = self:get_panel_list_obj()
      if rc then
        return rc
      else
        self:set_database_mode() -- go up one level
        return self:get_find_data(handle)
      end
    else
      ErrMsg("Invalid panel mode: "..tostring(self._panel_mode)) -- should never get here
    end
  ------------------------------------------------------------------------------
  else
    ErrMsg("Database not found: "..tostring(self._schema))
    self:set_root_mode()
    return self:get_find_data(handle) -- go root level
  end
  ------------------------------------------------------------------------------
  return false
end


function mypanel:table_or_view_exists(aSchema, aObject)
  local stmt = self._db:prepare("SELECT 1 FROM "..Norm(aSchema).."."..Norm(aObject))
  if stmt then stmt:finalize(); return true; end
  return false
end


function mypanel:database_exists(aObject)
  aObject = aObject:lower()
  for obj in self._db:nrows("PRAGMA DATABASE_LIST") do
    if obj.name:lower() == aObject then return true; end
  end
  return false
end


function mypanel:get_panel_list_root()
  local items = {}
  items[1] = { FileName=".."; FileAttributes="d"; }
  for obj in self._db:nrows("PRAGMA DATABASE_LIST") do
    table.insert(items, {
      FileAttributes = "d";
      FileName = obj.name;
      CustomColumnData = { obj.seq, obj.file };
    })
  end
  return items
end


function mypanel:get_panel_list_db()
  local prg_wnd = progress.newprogress(M.ps_reading)

  local db_objects = self._dbx:get_objects_list(self._schema)
  if not db_objects then
    prg_wnd:hide()
    ErrMsg(M.ps_err_read.."\n"..self._file_name.."\n"..self._dbx:last_error())
    return false
  end

  local items = { { FileName=".."; FileAttributes="d"; } }
  for i,obj in ipairs(db_objects) do
    local item = {
      AllocationSize = obj.type;  -- This field used as type id
      CustomColumnData = {};
      FileAttributes = "";
      FileName = obj.name;
      FileSize = obj.row_count;
    }

    if obj.type==sqlite.ot_master or obj.type==sqlite.ot_table or obj.type==sqlite.ot_view then
      item.FileAttributes = "d"
    end

    if obj.name == "sqlite_master" or obj.name == "sqlite_sequence" or
       obj.name:find("^sqlite_autoindex_")
    then item.FileAttributes = item.FileAttributes.."s"; end -- add "system" attribute

    local tp = "?"
    if     obj.type==sqlite.ot_master  then tp="metadata"
    elseif obj.type==sqlite.ot_table   then tp="table"
    elseif obj.type==sqlite.ot_view    then tp="view"
    elseif obj.type==sqlite.ot_index   then tp="index"
    elseif obj.type==sqlite.ot_trigger then tp="trigger"
    end
    item.CustomColumnData[1] = tp
    item.CustomColumnData[2] = ("% 9d"):format(obj.row_count)

    items[i+1] = item
  end

  prg_wnd:hide()
  return items
end


function mypanel:get_panel_list_obj()
  local dbx = self._dbx
  local fullname = Norm(self._schema).."."..Norm(self._object)

  -- Find a name to use for ROWID (self._rowid_name)
  self._rowid_name = nil
  if self._panel_mode == "table" then
    local query = "select * from " .. fullname
    local stmt = self._db:prepare(query)
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
      self._dbx:SqlErrMsg(query)
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
  if self._rowid_name then
    query = ("select %s.%s,* from %s"):format(fullname, self._rowid_name, fullname)
    local stmt = self._db:prepare(query)
    if stmt then stmt:finalize()
    else self._rowid_name = nil
    end
  end
  if not self._rowid_name then
    query = "select * from " .. fullname
  end

  local count_query = "select count(*) from " .. fullname
  if self._tab_filter.text and self._tab_filter.enabled then
    local tail = " "..self._tab_filter.text
    count_query = count_query..tail
    query = query..tail
  end

  local stmt = self._db:prepare(query)
  if not stmt then
    self._dbx:SqlErrMsg(query)
    return items
  end

  -- Get row count
  local row_count = 0
  local count_stmt = self._db:prepare(count_query)
  if count_stmt:step()==sql3.ROW then
    row_count = count_stmt:get_value(0)
  end
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

  local stmt = self._db:prepare(self._object)
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
  local FLAG_DFLT = bor(F.DIF_CENTERGROUP, F.DIF_DEFAULTBUTTON)
  local FLAG_NOCLOSE = bor(F.DIF_CENTERGROUP, F.DIF_BTNNOCLOSE)
  local dlg_items = {
    {F.DI_DOUBLEBOX, 3,1,dlg_width-4,col_num+4, 0,0,0,0, M.ps_title_select_columns},
  }
  local mask = self._col_masks[self._object]
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
    self._col_masks[self._object] = mask
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
  if self._col_masks[self._object] then
    self._col_masks_used = not self._col_masks_used
    self:prepare_panel_info()
    panel.UpdatePanel(handle,nil,true)
    panel.RedrawPanel(handle,nil)
  end
end


local Keybar = {}
Keybar.root = {
--           F1        F2        F3        F4        F5        F6        F7        F8
  nomods = { false,    false,    "",       "",       "",       "SQL",    "",       "Detach" },
  shift  = { "",       "",       "",       "",       "",       "",       "",       ""       },
  alt    = { false,    false,    "",       "",       "",       "",       "",       false    },
  ctrl   = { "",       "",       "",       "",       "",       "",       "",       ""       },
}
Keybar.db = {
--           F1        F2        F3        F4        F5        F6        F7        F8
  nomods = { false,    false,    "View",   "DDL",    "Export", "SQL",    "",       "Delete" },
  shift  = { "",       "",       "",       "Pragma", "Dump",   "",       "",       ""       },
  alt    = { false,    false,    "",       "",       "",       "",       "",       false    },
  ctrl   = { "",       "",       "",       "",       "",       "",       "",       ""       },
}
Keybar.table = {
--           F1        F2        F3        F4        F5        F6        F7        F8
  nomods = { false,    false,    "",       "Update", "",       "SQL",    "",       "Delete" },
  shift  = { "",       "",       "Custom", "Insert", "Affin",  "Filter", "",       ""       },
  alt    = { false,    false,    "Custom", "",       "",       "Filter", "",       false    },
  ctrl   = { "",       "",       "",       "",       "",       "",       "",       ""       },
}
Keybar.query = {
--           F1        F2        F3        F4        F5        F6        F7        F8
  nomods = { false,    false,    "",       "",       "",       "SQL",    "",       ""       },
  shift  = { "",       "",       "",       "",       "",       "",       "",       ""       },
  alt    = { false,    false,    "",       "",       "",       "",       "",       false    },
  ctrl   = { "",       "",       "",       "",       "",       "",       "",       ""       },
}
Keybar.mods = {
  nomods = 0;
  shift  = F.SHIFT_PRESSED;
  alt    = F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED;
  ctrl   = F.LEFT_CTRL_PRESSED + F.RIGHT_CTRL_PRESSED;
}


function mypanel:FillKeyBar (trg, src)
  src = Keybar[src]
  for mod,cks in pairs(Keybar.mods) do
    for vk=VK.F1,VK.F8 do
      local txt = src[mod][vk-VK.F1+1]
      if txt then
        table.insert(trg, { Text=txt; LongText=txt; VirtualKeyCode=vk; ControlKeyState=cks })
      end
    end
  end
  for vk=VK.F9,VK.F12 do
    table.insert(trg, { Text=""; LongText=""; VirtualKeyCode=vk;
                        ControlKeyState=F.LEFT_CTRL_PRESSED + F.RIGHT_CTRL_PRESSED })
  end
  local txt = self._multi_db and "MainDB" or "MultiDB"
  table.insert(trg, { Text=txt; LongText=txt; VirtualKeyCode=VK.F6;
                      ControlKeyState=F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED + F.SHIFT_PRESSED })
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

  local info = {
    key_bar = {};
    modes   = {};
    title   = M.ps_title_short .. ": " .. self._file_name:match("[^\\/]*$");
  }
  self._panel_info = info
  -------------------------------------------------------------------------------------------------
  if self._panel_mode == "root" then
    col_types     = "N,C0,C1"
    status_types  = "N,C0,C1"
    col_widths    = "0,5,0"
    status_widths = "0,5,0"
    col_titles    = { "name", "seq", "file" }
    self:FillKeyBar(info.key_bar, "root")
  -------------------------------------------------------------------------------------------------
  elseif self._panel_mode == "db" then
    info.title = info.title .. " [" .. self._schema .. "]"
    col_types     = "N,C0,C1"
    status_types  = "N,C0,C1"
    col_widths    = "0,8,9"
    status_widths = "0,8,9"
    col_titles    = { M.ps_pt_name, M.ps_pt_type, M.ps_pt_count }
    self:FillKeyBar(info.key_bar, "db")
  -------------------------------------------------------------------------------------------------
  else -- self._panel_mode == "table"/"view"/"query"
    local mask = self._col_masks_used and self._col_masks[self._object]
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
        if self._panel_mode == "table" and self._show_affinity then
          table.insert(col_titles, descr.name..affinity_map[descr.affinity])
        else
          table.insert(col_titles, descr.name)
        end
      end
    end
    if self._panel_mode == "query" then
      info.title = ("%s [%s]"):format(info.title, self._object)
      self:FillKeyBar(info.key_bar, "query")
    else
      info.title = ("%s [%s.%s]"):format(info.title, self._schema, self._object)
      self:FillKeyBar(info.key_bar, "table")
    end
  -------------------------------------------------------------------------------------------------
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
  if self._panel_mode == "root" then
    for _,item in ipairs(items) do
      self._db:exec("DETACH "..Norm(item.FileName))
    end
  elseif self._panel_mode == "db" or self._panel_mode == "table" then
    if self._panel_mode == "table" and not self._rowid_name then
      ErrMsg(M.ps_err_del_norowid)
      return false
    end
    local ed = myeditor.neweditor(self._dbx, self._schema, self._object, self._rowid_name)
    return ed:remove(items)
  end
  return false
end


function mypanel:set_table_filter(handle)
  local guid        = win.Uuid("920436C2-C32D-487F-B590-0E255AD71038")
  local query       = "SELECT * FROM "..Norm(self._schema).."."..Norm(self._object)
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
      local longquery = query.." "..text
      local stmt = self._db:prepare(longquery)
      if stmt then -- check syntax
        stmt:finalize()
        self._tab_filter.text = text
        self._tab_filter.enabled = true
      else
        self._dbx:SqlErrMsg(longquery)
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
  local alt    = cstate == F.LEFT_ALT_PRESSED  or cstate == F.RIGHT_ALT_PRESSED
  local ctrl   = cstate == F.LEFT_CTRL_PRESSED or cstate == F.RIGHT_CTRL_PRESSED
  local shift  = cstate == F.SHIFT_PRESSED
  local altshift = band(cstate, F.LEFT_CTRL_PRESSED+F.RIGHT_CTRL_PRESSED) == 0 and
                   band(cstate, F.LEFT_ALT_PRESSED+F.RIGHT_ALT_PRESSED) ~= 0 and
                   band(cstate, F.SHIFT_PRESSED) ~= 0

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
      local ex = exporter.newexporter(self._dbx, self._file_name, self._schema)
      if ex:export_data_with_dialog() then
        panel.UpdatePanel(nil,0)
        panel.RedrawPanel(nil,0)
      end
      return true
    elseif shift and vcode == VK.F5 then
      local ex = exporter.newexporter(self._dbx, self._file_name, self._schema)
      ex:dump_data_with_dialog()
      return true
    end
  end

  -- Table or view mode --------------------------------------------------------
  if self._panel_mode == "table" or self._panel_mode == "view" then
    if shift and vcode == VK.F3 then
      self:set_column_mask(handle)
      return true
    elseif alt and vcode == VK.F3 then
      self:toggle_column_mask(handle)
      return true
    elseif shift and vcode == VK.F6 then         -- Shift-F6 ("panel filter")
      self:set_table_filter(handle)
      return true;
    elseif alt and vcode == VK.F6 then           -- Alt-F6 ("toggle panel filter")
      self:toggle_table_filter(handle)
      return true
    end
  end

  -- Table mode ----------------------------------------------------------------
  if self._panel_mode == "table" then
    if nomods and (vcode == VK.F4 or vcode == VK.RETURN) then -- F4 or Enter: edit row
      if vcode == VK.RETURN then
        local item = panel.GetCurrentPanelItem(nil, 1)
        if not (item and item.FileName ~= "..") then          -- skip action for ".."
          return false
        end
      end
      if self._rowid_name then
        local ed = myeditor.neweditor(self._dbx, self._schema, self._object, self._rowid_name)
        ed:edit_item(handle)
        return true
      else
        ErrMsg(M.ps_err_edit_norowid)
      end
    elseif shift and vcode == VK.F4 then         -- ShiftF4: insert row
      local ed = myeditor.neweditor(self._dbx, self._schema, self._object, self._rowid_name)
      ed:insert_item(handle)
      return true
    elseif shift and vcode == VK.F5 then         -- Shift-F5 ("show/hide columns affinity")
      self._show_affinity = not self._show_affinity
      self:prepare_panel_info()
      panel.RedrawPanel(handle)
      return true
    end
  end

  -- All modes -----------------------------------------------------------------
  if shift and vcode == VK.F4 then             -- ShiftF4: suppress this key
    return true
  elseif nomods and vcode == VK.F5 then        -- F5: suppress this key
    return true
  elseif nomods and vcode == VK.F6 then        -- F6: edit and execute SQL query
    self:edit_sql_query(handle)
    return true
  elseif altshift and vcode == VK.F6 then      -- AltShiftF6: toggle multi_db mode
    self._multi_db = not self._multi_db
    self:prepare_panel_info()
    panel.RedrawPanel(handle)
    return false
  elseif shift and vcode == VK.F6 then         -- ShiftF6: suppress this key
    return true
  elseif nomods and vcode == VK.F7 then        -- F7: suppress this key
    return true
  elseif nomods and vcode == VK.F8 then -- intercept F8 to avoid panel-reread in case of user cancel
    if panel.GetPanelInfo(handle).SelectedItemsNumber > 0 then
      local guid = win.Uuid("4472C7D8-E2B2-46A0-A005-B10B4141EBBD") -- for macros
      if self._panel_mode == "root" then
        if far.Message(M.ps_detach_question, M.ps_title_short, ";YesNo", "w", nil, guid) == 1 then
          return nil
        end
      end
      if self._panel_mode == "db" or self._panel_mode == "table" then
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
  local RealItemName = item.FileName

  -- For unknown types show create sql only
  if not item.FileAttributes:find("d") then
    local cr_sql = self._dbx:get_creation_sql(self._schema, item.FileName)
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
    local ex = exporter.newexporter(self._dbx, self._file_name, self._schema)
    tmp_file_name = get_temp_file_name("txt")
    local ok = ex:export_data_as_text(tmp_file_name, RealItemName)
    if not ok then return end
  end
  local title = M.ps_title_short .. ": " .. RealItemName
  viewer.Viewer(tmp_file_name, title, 0, 0, -1, -1, bor(
    F.VF_ENABLE_F6, F.VF_DISABLEHISTORY, F.VF_DELETEONLYFILEONCLOSE, F.VF_IMMEDIATERETURN, F.VF_NONMODAL), 65001)
  viewer.SetMode(nil, { Type=F.VSMT_WRAP,     iParam=0,          Flags=0 })
  viewer.SetMode(nil, { Type=F.VSMT_VIEWMODE, iParam=F.VMT_TEXT, Flags=F.VSMFL_REDRAW })
end


function mypanel:view_db_create_sql()
  -- Get selected object name
  local item = panel.GetCurrentPanelItem(nil, 1)
  if item and item.FileName ~= ".." then
    local RealItemName = item.FileName
    local cr_sql = self._dbx:get_creation_sql(self._schema, RealItemName)
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
  local pragma_names = {
    "application_id",
    "auto_vacuum",
    "automatic_index",
    "busy_timeout",
    "cache_size",
    "cache_spill",
    "cell_size_check",
    "checkpoint_fullfsync",
    "compile_options",
    "data_version",
    "defer_foreign_keys",
    "encoding",
    "foreign_key_check",
    "foreign_keys",
    "freelist_count",
    "fullfsync",
    "integrity_check",
    "journal_mode",
    "journal_size_limit",
    "legacy_alter_table",
    "legacy_file_format",
    "locking_mode",
    "max_page_count",
    "mmap_size",--
    "page_count",
    "page_size",
    "query_only",
    "quick_check",
    "read_uncommitted",
    "recursive_triggers",
    "reverse_unordered_selects",
    "schema_version",
    "secure_delete",
    "synchronous",
    "temp_store",
    "threads",
    "user_version",
    "wal_autocheckpoint",
    "wal_checkpoint",
  }
  table.sort(pragma_names)
  local maxlen = 0
  for _,v in ipairs(pragma_names) do
    maxlen = math.max(maxlen, v:len())
  end
  -- execute a query for each pragma from the list
  local items = {}
  local head = "PRAGMA "..Norm(self._schema).."."
  for _,v in ipairs(pragma_names) do
    local stmt = self._db:prepare(head..v)
    if stmt then
      local cnt,first = 0,nil
      while stmt:step() == sql3.ROW do
        cnt = cnt+1
        if cnt == 1 then
          first = stmt:get_value(0)
        else
          if cnt == 2 then
            table.insert(items, { Text=v..":" })
            table.insert(items, { Text="    "..first })
          end
          table.insert(items, { Text = "    "..stmt:get_value(0) })
        end
      end
      if cnt == 1 then
        local num = tonumber(first)
        if num and not (num>-10 and num<10) then
          first = ("%d (0x%X)"):format(num,num)
        end
        local pv = Resize(v..":", maxlen+4, " ")..first
        table.insert(items, { Text=pv })
      end
      stmt:finalize()
    end
  end

  if items[1] then
    local guid = win.Uuid("FF769EE0-2643-48F1-A8A2-239CD3C6691F")
    local title = ("%s [%s]"):format(M.ps_title_pragma, self._schema)
    local list_flags = F.DIF_LISTNOBOX + F.DIF_LISTNOAMPERSAND + F.DIF_FOCUS
    local btn_flags = F.DIF_CENTERGROUP + F.DIF_DEFAULTBUTTON
    local dlg_items = {
      {"DI_DOUBLEBOX", 3,  1, 61, 18, 0,     0, 0, 0,               title},
      {"DI_LISTBOX",   4,  2, 60, 15, items, 0, 0, list_flags,      ""},
      {"DI_TEXT",      0, 16,  0, 16, 0,     0, 0, F.DIF_SEPARATOR, ""},
      {"DI_BUTTON",   60, 17,  0,  0, 0,     0, 0, btn_flags,       M.ps_ok}
    }
    far.Dialog(guid, -1, -1, 65, 20, nil, dlg_items)
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
      return CompareString(
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
      return CompareString(
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
    db          = self._db;
    file_name   = self._file_name;
    multi_db    = self._multi_db;
    schema      = self._schema;
    panel_mode  = self._panel_mode;
    curr_object = self._object;
    rowid_name  = self._rowid_name;
    get_rowid   = get_rowid;
  }
end


return mypanel
