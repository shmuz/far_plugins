-- coding: UTF-8

local DIRSEP  = string.sub(package.config, 1, 1)
local OS_WIN  = (DIRSEP == "\\")
local TYPE_ID = OS_WIN and "AllocationSize" or "NumberOfLinks" -- IMPORTANT: this field is used as type id

local sql3     = require "lsqlite3"
local settings = require "far2.settings"
local sdialog  = require "far2.simpledialog"
local M        = require "modules.string_rc"
local exporter = require "modules.exporter"
local myeditor = require "modules.editor"
local progress = require "modules.progress"
local dbx      = require "modules.sqlite"
local utils    = require "modules.utils"

local ErrMsg, Resize, Norm = utils.ErrMsg, utils.Resize, utils.Norm
local F = far.Flags
local KEEP_DIALOG_OPEN = 0
local SM_USER = F.SM_USER or 100 -- SM_USER appeared in Far 3.0.5655

local CMP_ALPHA, CMP_INT, CMP_FLOAT = 0,1,2 -- CRITICAL: must match the enum in polygon.c

local SECTION_FILES   = "files" -- keys in this section are lower-cased full file names
local SECTION_GENERAL = "general"
local SECTION_QUERIES = "queries"
local SETTINGS_KEY    = nil
local KEY_TIME        = "time"
local KEY_LASTCHECK   = "last_check"


-- Clean up "files" history
local function RemoveOldHistoryRecords()
  local DAY = 24*60*60*1000 -- 1 day in msec
  local CHECK_PERIOD = DAY * 1
  local RETAIN_TIME = DAY * 365

  if OS_WIN then
    local pLocation = "local"
    local now = win.GetSystemTimeAsFileTime()
    local last = settings.mload(SECTION_GENERAL, KEY_LASTCHECK, pLocation)
    if last and (now - last) < CHECK_PERIOD then
      return
    end
    settings.msave(SECTION_GENERAL, KEY_LASTCHECK, now, pLocation)
    ------------------------------------------------------------------------
    local obj = far.CreateSettings(nil, F.PSL_LOCAL)
    local subkey = obj:OpenSubkey(0, SECTION_FILES)
    if subkey then
      local items = obj:Enum(subkey)
      obj:Free()
      for _, v in ipairs(items) do
        local fname = v.Name
        local fdata = settings.mload(SECTION_FILES, fname, pLocation)
        if fdata then
          local last = fdata[KEY_TIME]
          if last then
            if now - last > RETAIN_TIME then
              settings.mdelete(SECTION_FILES, fname, pLocation) -- delete expired fdata
            end
          else
            fdata[KEY_TIME] = now
            settings.msave(SECTION_FILES, fname, fdata, pLocation) -- set current time and save
          end
        else
          settings.mdelete(SECTION_FILES, fname, pLocation) -- delete corrupted fdata
        end
      end
    else
      obj:Free()
    end
  else
    local now = win.GetSystemTimeAsFileTime()
    local sect = settings.mload(SETTINGS_KEY, SECTION_GENERAL) or {}
    local last = sect[KEY_LASTCHECK]
    if last and (now - last) < CHECK_PERIOD then
      return
    end
    sect[KEY_LASTCHECK] = now
    settings.msave(SETTINGS_KEY, SECTION_GENERAL, sect)
    ------------------------------------------------------------------------
    local items = settings.mload(SETTINGS_KEY, SECTION_FILES)
    if items then
      for fname, fdata in pairs(items) do
        local last = fdata[KEY_TIME]
        if last then
          if now - last > RETAIN_TIME then
            items[fname] = nil -- delete expired fdata
          end
        else
          fdata[KEY_TIME] = now
        end
      end
      settings.msave(SETTINGS_KEY, SECTION_FILES, items)
    end
  end
end


-- This file's module. Could not be called "panel" due to existing LuaFAR global "panel".
local mypanel = {}


function mypanel.open(filename, extensions, ignore_foreign_keys, multi_db)
  local self = {
    _col_info       = nil;       -- array of tables: { { name=<name>; affinity=<affinity> }, ... }
    _filename       = filename;  -- either host file name or ":memory:"
    _objname        = "";        -- name of the current object, e.g. database table name or SQL query
    _panel_mode     = "root";    -- valid values are: "root", "db", "table", "view", "query"
    _col_masks_used = {};        -- _col_masks_used[<table_name>] = <boolean>
    _db             = nil;       -- database connection
    _exiting        = nil;       -- boolean (Enter pressed on .. in database mode and _multi_db==false).
                                    -- Without it TopPanelItem of the Far panel might not be preserved
                                    -- as Far will try to place the host file at the bottom of the visible
                                    -- part of the panel.
    _histfile       = nil;       -- files[<filename>] in the plugin's non-volatile local settings
    _tables         = nil;       -- shortcut for _histfile.tables
    _multi_db       = multi_db;  -- boolean value
    _rowid_name     = nil;       -- either "rowid", "oid", "_rowid_", or nil
    _schema         = "";        -- either "main", "temp", or the name of an attached database
    _show_affinity  = nil;       -- boolean value
    _sort_col_index = nil;       -- number of column counting from the left
    _sort_compare   = CMP_ALPHA; -- alphabetic compare
    _tab_filter                  -- current table filter
                    = { enabled=false; text=nil; };
    _language       = nil;       -- current Far language
    _panel_info     = nil;       -- panel info
  }

  setmetatable(self, { __index=mypanel })

  self._db = dbx.open(filename)
  if self._db then
    if self._multi_db then
      self:set_root_mode()
    else
      self:set_database_mode("main")
    end
    if extensions then
      self._db:load_extension("") -- enable extensions
    end
    if not ignore_foreign_keys then
      self._db:exec("PRAGMA foreign_keys = ON;")
    end
    RemoveOldHistoryRecords()
    if OS_WIN then
      self._histfile = settings.mload(SECTION_FILES, filename:lower(), "local") or {}
    else
      local sect = settings.mload(SETTINGS_KEY, SECTION_FILES) or {}
      self._histfile = settings.field(sect, filename:lower())
    end
    self._histfile.tables = self._histfile.tables or {}
    self._tables = self._histfile.tables
    return self
  else
    ErrMsg(M.err_open.."\n"..filename)
    return nil
  end
end


function mypanel:invalidate_panel_info()
  self._panel_info = nil
end


function mypanel:set_directory(aHandle, aDir, aUserData)
  local success = true
  self._tab_filter = {}
  ----------------------------------------------------------------------------------------
  if aDir == DIRSEP or (OS_WIN and aDir == "/") then
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
    local patt = ("^(%s?)([^%s]+)(%s?)([^%s]*)$"):format(DIRSEP,DIRSEP,DIRSEP,DIRSEP)
    local g1, g2, g3, g4 = aDir:match(patt)
    if g1==nil or (g3==DIRSEP and g4=="") then
      return false
    end
    if g1 == DIRSEP then -- absolute path
      if self:database_exists(g2) then
        if g4 ~= "" then
          success = self:table_or_view_exists(g2,g4) and self:open_object(aHandle,g2,g4)
        else
          self:set_database_mode(g2)
        end
      end
    else -- relative path
      if g4 == "" then
        if self._panel_mode == "root" then
          if self:database_exists(g2) then
            self:set_database_mode(g2)
          end
        elseif self._panel_mode == "db" then
          success = self:table_or_view_exists(self._schema, g2) and
                    self:open_object(aHandle, self._schema, g2)
        end
      end -- if g4 == ""
    end -- absolute/relative path
  end -- if not special directory name
  if success then
    self:invalidate_panel_info()
    return true
  end
end


function mypanel:set_root_mode()
  self._schema = ""
  self._objname = ""
  self._panel_mode = "root"
  self:invalidate_panel_info()
end


function mypanel:set_database_mode(aSchema)
  if aSchema then
    self._schema = aSchema
  end
  self._objname = ""
  self._panel_mode = "db"
  self:invalidate_panel_info()
end


function mypanel:open_object(aHandle, aSchema, aObject)
  local tp = dbx.get_object_type(self._db, aSchema, aObject)
  if tp=="table" or tp=="view" then
    local col_info = dbx.read_columns_info(self._db, aSchema, aObject)
    if col_info then
      self._schema     = aSchema
      self._objname    = aObject
      self._panel_mode = tp
      self._col_info   = col_info

      local count = dbx.get_row_count(self._db, self._schema, self._objname)
      if count and count >= 50000 then -- sorting is very slow on big tables
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
      query = string.gsub(query, "^%s+", "") -- remove white space
      query, num = string.gsub(query, "^%-%-[^\n]*\n?", "") -- remove a comment
    until (num == 0)

    local w, q = query:match("([%w_]+)(.*)")
    if w then words[k], query = w, q
    else break
    end
  end
  return words[1], words[2]
end


local pragma_word2 = {
  ["collation_list"   ] = true;
  ["compile_options"  ] = true;
  ["database_list"    ] = true;
  ["foreign_key_check"] = true;
  ["foreign_key_list" ] = true;
  ["function_list"    ] = true;
  ["module_list"      ] = true;
  ["pragma_list"      ] = true;
  ["table_info"       ] = true;
  ["table_xinfo"      ] = true;
}
function mypanel:do_open_query(handle, query)
  local word1, word2 = FindFirstTwoWords(query)
  if not word1 then return end
  word1 = word1:lower()
  word2 = word2 and word2:lower()

  -- Check query for select
  if (word1=="select" and word2~="load_extension")
  or (word1=="pragma" and pragma_word2[word2]) then
    -- Get column description
    local stmt = self._db:prepare(query)
    if not stmt then
      dbx.err_message(self._db, query)
      return false
    end
    local state = stmt:step()
    if state == sql3.ERROR or state == sql3.MISUSE then
      dbx.err_message(self._db, query)
      stmt:finalize()
      return false
    end

    self._panel_mode = "query"
    self._objname = query

    stmt:reset()
    self._col_info = {}
    for i, name in ipairs(stmt:get_names()) do
      self._col_info[i] = { name = name; }
    end

    stmt:finalize()
  else
    -- Update query - just execute without reading the result
    local prg_wnd = progress.newprogress(M.execsql)
    if not dbx.execute_query(self._db, query, true) then
      prg_wnd:hide()
      panel.RedrawPanel(handle)
      return false
    end
    prg_wnd:hide()
  end

  local position = word1~="update" and {CurrentItem=1} or nil -- don't reset position on update
  self:invalidate_panel_info()
  panel.UpdatePanel(handle, nil, false)
  panel.RedrawPanel(handle, nil, position)
  return true
end


local q_history = { _array=nil; }
local meta_q_history = { __index=q_history; }


function q_history.new()
  local self = setmetatable({}, meta_q_history)
  if OS_WIN then
    self._array = settings.mload(SECTION_QUERIES, SECTION_QUERIES, "local") or {}
  else
    self._array = settings.mload(SETTINGS_KEY, SECTION_QUERIES) or {}
  end
  return self
end


function q_history:save()
  if OS_WIN then
    settings.msave(SECTION_QUERIES, SECTION_QUERIES, self._array, "local")
  else
    settings.msave(SETTINGS_KEY, SECTION_QUERIES, self._array)
  end
end


function q_history:add(query)
  -- add a new entry or move it down if it's a duplicate
  for i,v in ipairs(self._array) do
    if query == v then
      table.remove(self._array, i)
      break
    end
  end
  table.insert(self._array, query)

  -- leave 1000 entries at most (remove the oldest entries)
  for _=1, #self._array-1000 do
    table.remove(self._array, 1)
  end

  self:save()
end


function mypanel:open_query(handle, query)
  q_history.new():add(query)
  self:do_open_query(handle, query)
end


local SortMap = {
  [ F.SM_NAME     ] = 1,  -- Ctrl-F3
  [ F.SM_EXT      ] = 2,  -- Ctrl-F4
  [ F.SM_MTIME    ] = 3,  -- Ctrl-F5
  [ F.SM_SIZE     ] = 4,  -- Ctrl-F6
--[ F.SM_UNSORTED ] Far does not call CompareW when Ctrl-F7 is pressed
  [ F.SM_CTIME    ] = 5,  -- Ctrl-F8
  [ F.SM_ATIME    ] = 6,  -- Ctrl-F9
  [ F.SM_DESCR    ] = 7,  -- Ctrl-F10
  [ F.SM_OWNER    ] = 8,  -- Ctrl-F11
}

local PMODES = { table=1; view=1; query=1; }

function mypanel:get_open_panel_info(handle)
  if PMODES[self._panel_mode] and not SortMap[panel.GetPanelInfo(handle).SortMode] then
    self._sort_col_index = nil
    self:prepare_panel_info(handle)
  elseif not (self._panel_info and self._language == win.GetEnv("FARLANG")) then
    self:prepare_panel_info(handle)
  end

  local CurDir
  if self._exiting or (not OS_WIN and self._panel_mode=="db" and not self._multi_db) then
    CurDir = ""
  else
    CurDir = self._schema
    if self._objname ~= "" then CurDir = CurDir..DIRSEP..self._objname; end
    if CurDir ~= "" then CurDir = DIRSEP..CurDir; end
  end

  local Info  = self._panel_info
  local Flags = OS_WIN and
    bit64.bor(F.OPIF_DISABLESORTGROUPS,F.OPIF_DISABLEFILTER,F.OPIF_SHORTCUT) or
    bit64.bor(F.OPIF_USEHIGHLIGHTING)
  return {
    CurDir           = CurDir;
    Flags            = Flags;
    HostFile         = self._filename;
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
      ErrMsg(M.invalid_panel_mode..": "..tostring(self._panel_mode)) -- should never get here
    end
  ------------------------------------------------------------------------------
  else
    ErrMsg(M.database_not_found..": "..tostring(self._schema))
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
  local prg_wnd = progress.newprogress(M.reading)

  local db_objects = dbx.get_objects_list(self._db, self._schema)
  if not db_objects then
    prg_wnd:hide()
    ErrMsg(M.err_read.."\n"..self._filename.."\n"..dbx.last_error(self._db))
    return false
  end

  local items = { { FileName=".."; FileAttributes="d"; } }
  for i,obj in ipairs(db_objects) do
    local item = {
      [TYPE_ID] = obj.type;
      CustomColumnData = {};
      FileAttributes = "";
      FileName = obj.name;
      FileSize = obj.row_count;
    }
    local typename = dbx.decode_object_type(obj.type)
    if typename=="table" or typename=="view" then
      item.FileAttributes = "d"
    end
    if obj.name:find("^sqlite_") then
      item.FileAttributes = item.FileAttributes.."s"  -- add "system" attribute
    end
    item.CustomColumnData[1] = dbx.decode_object_type(obj.type, true) or "?"
    item.CustomColumnData[2] = ("% 9d"):format(obj.row_count)
    items[i+1] = item
  end

  prg_wnd:hide()
  return items
end


function mypanel:get_panel_list_obj()
  local fullname = Norm(self._schema).."."..Norm(self._objname)

  -- Find a name to use for ROWID (self._rowid_name)
  self._rowid_name = nil
  if self._panel_mode == "table" then
    local query = "SELECT * FROM " .. fullname
    local stmt = self._db:prepare(query)
    if stmt then
      local map = {}
      for _,colname in ipairs(stmt:get_names()) do
        map[colname:lower()] = true
      end
      for _,name in ipairs {"rowid", "oid", "_rowid_"} do
        if map[name] == nil then
          self._rowid_name = fullname.."."..name
          break
        end
      end
      stmt:finalize()
    else
      dbx.err_message(self._db, query)
      return false
    end
  end

  -- Add a special item with dots (..) in all columns.
  local items = {}
  items[1] = { FileName=".."; FileAttributes="d"; CustomColumnData={}; }
  for i = 1, #self._col_info do
    items[1].CustomColumnData[i] = ".."
  end

  -- If ROWID exists then select it as the leftmost column.
  local query
  if self._rowid_name then
    query = ("SELECT %s,* FROM %s"):format(self._rowid_name, fullname)
    local stmt = self._db:prepare(query)
    if stmt then stmt:finalize()
    else self._rowid_name = nil
    end
  end
  if not self._rowid_name then
    query = "SELECT * FROM " .. fullname
  end

  local count_query = "SELECT count(*) FROM " .. fullname
  if self._tab_filter.text and self._tab_filter.enabled then
    local tail = " "..self._tab_filter.text
    count_query = count_query..tail
    query = query..tail
  end

  local stmt = self._db:prepare(query)
  if not stmt then
    dbx.err_message(self._db, query)
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
  local prg_wnd = progress.newprogress(M.reading, row_count)
  for row = 1, row_count do
    if row % 100 == 1 then
      prg_wnd:update(row-1)
      if progress.aborted() then
        break -- show incomplete data
      end
    end
    local res = stmt:step()
    if res == sql3.DONE then
      break
    elseif res ~= sql3.ROW then
      ErrMsg(M.err_read.."\n"..dbx.last_error(self._db))
      items = false
      break
    end

    local item = { CustomColumnData={}; }
    items[row+1] = item -- shift by 1, as items[1] is dot_item

    if self._rowid_name then
      for i = 1,#self._col_info do
        item.CustomColumnData[i] = exporter.get_text(stmt, i, true)
      end
      -- the leftmost column is ROWID (according to the query used)
      local rowid = stmt:get_column_text(0)
      -- IMPORTANT: field 'Owner' is used for holding ROWID
      item.Owner = rowid
      -- use ROWID as file name, otherwise FAR cannot properly handle selections on the panel
      item.FileName = ("%010d"):format(rowid)
    else
      for i = 1,#self._col_info do
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
  local dot_col_num = #self._col_info
  local dot_custom_column_data = {}
  for j = 1, dot_col_num do
    dot_custom_column_data[j] = ".."
  end
  dot_item.CustomColumnData = dot_custom_column_data
  table.insert(buff, dot_item)

  local stmt = self._db:prepare(self._objname)
  if not stmt then
    local err_descr = dbx.last_error(self._db)
    ErrMsg(M.err_read.."\n"..err_descr)
    return false
  end

  local prg_wnd = progress.newprogress(M.reading)
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
    local err_descr = dbx.last_error(self._db)
    ErrMsg(M.err_read.."\n"..err_descr)
    return false
  end

  return buff
end


function mypanel:set_column_mask(handle)
  -- Build dialog dynamically
  local dlg_width = 72
  local col_num = #self._col_info
  local Items = {
    guid="D252C184-9E10-4DE8-BD68-08A8A937E1F8";
    help="PanelView";
    width=dlg_width;
    [1]={ tp="dbox"; text=M.title_select_columns };
  }
  local curtable = self._tables[self._objname] or {}
  self._tables[self._objname] = curtable
  local masks = curtable.col_masks
  for i,col in ipairs(self._col_info) do
    local text = masks and masks[col.name]
    local check = text and true
    local name = col.name
    if name:len() > dlg_width-18 then
      name = name:sub(1,dlg_width-21).."..."
    end
    table.insert(Items, { tp="fixedit"; text=text or "0"; x1=5; x2=7;        name=2*i;   })
    table.insert(Items, { tp="chbox";   text=name; x1=9; ystep=0; val=check; name=2*i+1; })
  end
  table.insert(Items, { tp="sep";                                                     })
  table.insert(Items, { tp="butt"; text=M.ok;            centergroup=1; default=1;    })
  table.insert(Items, { tp="butt"; text=M.set_columns;   centergroup=1; btnnoclose=1; })
  table.insert(Items, { tp="butt"; text=M.reset_columns; centergroup=1; btnnoclose=1; })
  table.insert(Items, { tp="butt"; text=M.cancel;        centergroup=1; cancel=1;     })

  local btnSet, btnReset = 2*col_num+4, 2*col_num+5

  local function SetEnable(hDlg)
    hDlg:send(F.DM_ENABLEREDRAW, 0)
    for pos = 1,col_num do
      local enab = hDlg:send(F.DM_GETCHECK, 2*pos+1)==F.BSTATE_CHECKED and 1 or 0
      hDlg:send(F.DM_ENABLE, 2*pos, enab)
    end
    hDlg:send(F.DM_ENABLEREDRAW, 1)
  end

  Items.proc = function(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      SetEnable(hDlg)
      hDlg:send(F.DM_SETFOCUS, 3)
    elseif Msg == F.DN_BTNCLICK then
      local state = Param1==btnSet and F.BSTATE_CHECKED or Param1==btnReset and F.BSTATE_UNCHECKED
      if state then
        hDlg:send(F.DM_ENABLEREDRAW, 0)
        for pos = 1,col_num do hDlg:send(F.DM_SETCHECK, 2*pos+1, state); end
        hDlg:send(F.DM_ENABLEREDRAW, 1)
      end
      SetEnable(hDlg)
    end
  end

  local res = sdialog.New(Items):Run()
  if res then
    local masks = {}
    curtable.col_masks = masks
    for k=1,col_num do
      if res[2*k+1] then -- if checkbox is checked
        masks[self._col_info[k].name] = res[2*k] -- take data from fixedit
      end
    end
    if next(masks) == nil and col_num > 0 then -- all columns should not be hidden - show the 1-st column
      masks[self._col_info[1].name] = "0"
    end
    self._col_masks_used[self._objname] = true
    self._histfile[KEY_TIME] = win.GetSystemTimeAsFileTime()
    if OS_WIN then
      settings.msave(SECTION_FILES, self._filename:lower(), self._histfile, "local")
    else
      local t = settings.mload(SETTINGS_KEY, SECTION_FILES) or {}
      t[self._filename:lower()] = self._histfile
      settings.msave(SETTINGS_KEY, SECTION_FILES, t)
    end
    self:invalidate_panel_info()
    panel.RedrawPanel(handle)
  end
end


function mypanel:toggle_column_mask(handle)
  local cur = self._tables[self._objname]
  if cur and cur.col_masks then
    self._col_masks_used[self._objname] = not self._col_masks_used[self._objname]
    self:invalidate_panel_info()
    panel.RedrawPanel(handle)
  end
end


local function GetKeybarStrings(panelmode)
  if panelmode == "root" then return {
  --           F1        F2        F3         F4           F5           F6            F7     F8
    nomods = { false,    false,    "",        "",          "",          "SQL",        "",    "Detach" },
    shift  = { "",       "",       "",        "",          "",          "",           "",    ""    },
    alt    = { false,    false,    "",        "",          "",          "",           "",    false },
    ctrl   = { "",       "",       "",        "",          "",          "",           "",    ""    },
  }
  elseif panelmode == "db" then return {
  --           F1        F2        F3         F4           F5           F6            F7     F8
    nomods = { false,    false,    M.kb_view, "DDL",       M.kb_export, "SQL", M.kb_table,   M.kb_delete },
    shift  = { "",       "",       "",        M.kb_pragma, "Dump",      "Recover",    "",    ""    },
    alt    = { false,    false,    "",        "",          "",          "",           "",    false },
    ctrl   = { "",       "",       "",        "",          "",          "",           "",    ""    },
  }
  elseif panelmode == "table" then return {
  --           F1        F2        F3         F4           F5           F6            F7     F8
    nomods = { false,    false,    "",        "Update",    "",          "SQL",        "",    M.kb_delete },
    shift  = { "",       "",       "Custom",  "Insert",    "Copy",      M.kb_filter,  "",    ""    },
    alt    = { false,    false,    "Custom",  "",          "Affinit",   M.kb_filter,  "",    false },
    ctrl   = { "",       "",       "",        "",          "",          "",           "",      ""  },
  }
  elseif panelmode == "query" then return {
  --           F1        F2        F3         F4           F5           F6            F7     F8
    nomods = { false,    false,    "",        "",          "",          "SQL",        "",    ""    },
    shift  = { "",       "",       "",        "",          "",          "",           "",    ""    },
    alt    = { false,    false,    "",        "",          "",          "",           "",    false },
    ctrl   = { "",       "",       "",        "",          "",          "",           "",    ""    },
  }
  end
end


function mypanel:FillKeyBar (trg, src)
  if OS_WIN then
    local VK = win.GetVirtualKeys()
    local Keybar_mods = {
      nomods = 0;
      shift  = F.SHIFT_PRESSED;
      alt    = F.LEFT_ALT_PRESSED + F.RIGHT_ALT_PRESSED;
      ctrl   = F.LEFT_CTRL_PRESSED + F.RIGHT_CTRL_PRESSED;
    }
    src = GetKeybarStrings(src)
    for mod,cks in pairs(Keybar_mods) do
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
  else
    src = GetKeybarStrings(src)
    trg.Titles={}
    trg.ShiftTitles={}
    trg.AltTitles={}
    trg.CtrlTitles={}
    for k=1,8 do
      trg.Titles[k]      = src.nomods[k]
      trg.ShiftTitles[k] = src.shift[k]
      trg.AltTitles[k]   = src.alt[k]
      trg.CtrlTitles[k]  = src.ctrl[k]
    end
    for k=9,12 do
      trg.CtrlTitles[k] = ""
    end
    local txt = self._multi_db and "MainDB" or "MultiDB"
    trg.AltShiftTitles = { [6]=txt; }
  end
end


local affinity_map = {
  INTEGER = " [i]";
  TEXT    = " [t]";
  BLOB    = " [b]";
  REAL    = " [r]";
  NUMERIC = " [n]";
}


function mypanel:prepare_panel_info(handle)
  local col_types = ""
  local col_widths = ""
  local col_titles = {}
  local status_types = nil
  local status_widths = nil

  local info = {
    key_bar = {};
    modes   = {};
    title   = M.title_short .. ": " .. self._filename:match("[^"..DIRSEP.."]*$");
  }
  self._panel_info = info
  self._language = win.GetEnv("FARLANG")
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
    col_titles    = { M.pt_name, M.pt_type, M.pt_count }
    self:FillKeyBar(info.key_bar, "db")
  -------------------------------------------------------------------------------------------------
  else -- self._panel_mode == "table"/"view"/"query"
    -- Re-read column info as it may have changed due to possible "ALTER TABLE..." execution
    local col_info = dbx.read_columns_info(self._db, self._schema, self._objname)
    if col_info and col_info[1] then
      self._col_info = col_info
    end
    local pInfo = panel.GetPanelInfo(handle)
    local sort_reverse = bit64.band(pInfo.Flags, F.PFLAGS_REVERSESORTORDER) ~= 0
    local sort_char = sort_reverse and M.sort_descend or M.sort_ascend
    local cur = self._tables[self._objname]
    local masks = self._col_masks_used[self._objname] and cur and cur.col_masks
    local show_affinity = self._panel_mode=="table" and self._show_affinity
    for i,descr in ipairs(self._col_info) do
      local width = not masks and "0" or masks[descr.name]
      if width then
        if col_types ~= "" then
          col_types = col_types .. ","
          col_widths = col_widths .. ','
        end
        col_types = col_types .. "C" .. (i-1)
        col_widths = col_widths .. width
        local head = i == self._sort_col_index and sort_char or ""
        local tail = show_affinity and affinity_map[descr.affinity] or ""
        table.insert(col_titles, head..descr.name..tail)
      end
    end
    if col_titles[1] == nil then
      local descr = self._col_info[1]
      col_types = "C0"
      col_widths = "0"
      local head = 1 == self._sort_col_index and sort_char or ""
      local tail = show_affinity and affinity_map[descr.affinity] or ""
      table.insert(col_titles, head..descr.name..tail)
    end
    if self._panel_mode == "query" then
      info.title = ("%s [%s]"):format(info.title, self._objname)
      self:FillKeyBar(info.key_bar, "query")
    else
      info.title = ("%s [%s.%s]"):format(info.title, self._schema, self._objname)
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
  if OS_WIN then
    pm2.Flags = F.PMFLAGS_FULLSCREEN
  else
    pm2.FullScreen = true
  end
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
      ErrMsg(M.err_del_norowid)
      return false
    end
    return myeditor.remove(self._db, self._schema, self._objname, self._rowid_name, items)
  end
  return false
end


function mypanel:set_table_filter(handle)
  local query = "SELECT * FROM "..Norm(self._schema).."."..Norm(self._objname)
  local Items = {
    guid="920436C2-C32D-487F-B590-0E255AD71038";
    help="PanelFilter";
    width=76;
    {tp="dbox"; text=M.panel_filter;                                           },
    {tp="text"; text=query;                                                    },
    {tp="edit"; hist="Polygon_PanelFilterExt"; uselasthistory=1; name="extra"; },
    {tp="text"; text="WHERE"                                                   },
    {tp="edit"; hist="Polygon_PanelFilter";    uselasthistory=1; name="where"; },
    {tp="sep";                                                                 },
    {tp="butt"; text=M.ok;     centergroup=1; default=1;                       },
    {tp="butt"; text=M.cancel; centergroup=1; cancel=1;                        },
  }

  local function closeaction(hDlg, Param1, tOut)
    local extra, where = tOut.extra, tOut.where
    local text = where:find("%S") and (extra.." WHERE "..where) or extra
    local longquery = query.." "..text
    local stmt = self._db:prepare(longquery)
    if stmt then -- check syntax
      stmt:finalize()
      self._tab_filter.text = text
      self._tab_filter.enabled = true
    else
      dbx.err_message(self._db, longquery)
      return 0
    end
  end

  Items.proc = function(hDlg, Msg, Par1, Par2)
    if Msg == F.DN_CLOSE then
      return closeaction(hDlg, Par1, Par2)
    end
  end

  if sdialog.New(Items):Run() then
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


function mypanel:create_table()
  local items = {
    width=80;
    guid="AE45BD7E-7110-4581-A8C1-EDC7BA96B0AB";
    help = "CreateTableDialog";
    {tp="dbox"; text=M.title_create_table;                 },
    {tp="text"; text=M.label_table_name;                   },
    {tp="edit"; name="tablename";  hist="polygon_tabname"; },
    {tp="sep" ;                                            },
    {tp="sep" ;                                            },
    {tp="butt"; text=M.ok; default=1; centergroup=1;       },
    {tp="butt"; text=M.cancel; cancel=1; centergroup=1;    },
  }
  local x1 = M.label_column_name:len() + 9
  for k=1,16 do
    table.insert(items, 3+2*k, {tp="text"; text=("%s %d"):format(M.label_column_name,k); })
    table.insert(items, 4+2*k, {tp="edit"; name=k; ystep=0; x1=x1; hist="polygon_colname"; })
  end

  local function closeaction(hDlg, Par1, tOut)
    local t = {}
    for k=1,16 do
      if tOut[k] ~= "" then t[#t+1] = "  "..tOut[k] end
    end
    local query = ("CREATE TABLE %s (\n%s\n)"):format(tOut.tablename, table.concat(t,",\n"))
    if self._db:exec(query) ~= sql3.OK then
      dbx.err_message(self._db, query)
      return KEEP_DIALOG_OPEN
    end
  end

  items.proc = function(hDlg, Msg, Par1, Par2)
    if Msg == F.DN_CLOSE then
      return closeaction(hDlg, Par1, Par2)
    end
  end

  return sdialog.New(items):Run()
end


local SuppressedKeys = {
  AltF3   = true;
  CtrlA   = true;
  CtrlN   = true;
  F3      = true;
  F5      = true;
  F7      = true;
  ShiftF4 = true;
  ShiftF6 = true;
  ShiftF8 = true;
}


function mypanel:handle_key_db(handle, key)
  if key == "F3" then            -- F3: view table/view data
    self:view_db_object()
    return true
  elseif key == "F4" then        -- F4: view create statement
    self:view_db_create_sql()
    return true
  elseif key == "ShiftF4" then   -- view pragma statement
    self:view_pragma_statements()
    return true
  elseif key == "F5" then        -- export table/view data
    local ex = exporter.newexporter(self._db, self._filename, self._schema)
    if ex:export_data_with_dialog() then
      panel.UpdatePanel(nil,0)
      panel.RedrawPanel(nil,0)
    end
    return true
  elseif key == "ShiftF5" then
    local ex = exporter.newexporter(self._db, self._filename, self._schema)
    ex:dump_data_with_dialog()
    return true
  elseif key == "ShiftF6" then
    local ex = exporter.newexporter(self._db, self._filename, self._schema)
    ex:recover_data_with_dialog()
    return true
  elseif key == "Enter" and not self._multi_db then
    local item = panel.GetCurrentPanelItem(handle)
    if item.FileName == ".." then self._exiting=true; end
  elseif key == "F7" then
    if self:create_table() then
      panel.UpdatePanel(handle)
      panel.RedrawPanel(handle)
    end
    return true
  end
end


function mypanel:handle_key_tbview(handle, key)
  if key == "ShiftF3" then
    self:set_column_mask(handle)
    return true
  elseif key=="AltF3" then
    self:toggle_column_mask(handle)
    return true
  elseif key == "ShiftF6" then        -- "panel filter"
    self:set_table_filter(handle)
    return true
  elseif key == "AltF6" then          -- "toggle panel filter"
    self:toggle_table_filter(handle)
    return true
  elseif key=="CtrlN" then
    ------ Toggle between alphabetical and numerical sort modes ------
    local curr = self._sort_compare
    local item = far.Menu( { Title=M.title_sort_compare_mode }, {
      { text="&1. Alphabetic";       checked=(curr==CMP_ALPHA); selected=(curr==CMP_ALPHA); Cmp=CMP_ALPHA; },
      { text="&2. Numeric: integer"; checked=(curr==CMP_INT);   selected=(curr==CMP_INT);   Cmp=CMP_INT;   },
      { text="&3. Numeric: float";   checked=(curr==CMP_FLOAT); selected=(curr==CMP_FLOAT); Cmp=CMP_FLOAT; },
    })
    if item then
      self._sort_compare = item.Cmp
      local info = panel.GetPanelInfo(handle)
      if self._panel_mode ~= "db" and info.SortMode < SM_USER then
        -- SetSortMode() called with the current sort mode reverses the sort order, thus we
        -- call SetSortOrder() requesting the current sort order. Hopefully, the future Far Manager
        -- versions won't optimize such a case out and will always initiate sorting operation.
        -- As for Far 3.0.5886 (September 2021) it is OK.
        panel.SetSortOrder(handle, nil, bit64.band(info.Flags, F.PFLAGS_REVERSESORTORDER)~=0)
      end
    end
    return true
  end
end


function mypanel:handle_key_table(handle, key)
  if key == "F4" or key == "Enter" then -- edit row
    if key == "Enter" then
      local item = panel.GetCurrentPanelItem(nil, 1)
      if not (item and item.FileName ~= "..") then     -- skip action for ".."
        return false
      end
    end
    if self._rowid_name then
      myeditor.edit_row(self._db, self._schema, self._objname, self._rowid_name, handle)
      return true
    else
      ErrMsg(M.err_edit_norowid)
    end
  elseif key == "ShiftF4" then         -- insert row
    myeditor.insert_row(self._db, self._schema, self._objname, self._rowid_name, handle)
    return true
  elseif key == "ShiftF5" then         -- copy row
    myeditor.copy_row(self._db, self._schema, self._objname, self._rowid_name, handle)
    return true
  elseif key == "AltF5" then           -- "show/hide columns affinity"
    self._show_affinity = not self._show_affinity
    self:invalidate_panel_info()
    panel.RedrawPanel(handle)
    return true
  end
end


function mypanel:handle_key_all(handle, key)
  if SuppressedKeys[key] then
    return true
  elseif key == "F6" then           -- edit and execute SQL query
    self:sql_query_history(handle)
    return true
  elseif key == "AltShiftF6" then   -- toggle multi_db mode
    self._multi_db = not self._multi_db
    self:invalidate_panel_info()
    panel.RedrawPanel(handle)
    return false
  elseif key == "F8" then -- intercept F8 to avoid panel-reread in case of user cancel
    if panel.GetPanelInfo(handle).SelectedItemsNumber > 0 then
      local guid = win.Uuid("4472C7D8-E2B2-46A0-A005-B10B4141EBBD") -- for macros
      if self._panel_mode == "root" then
        if far.Message(M.detach_question, M.title_short, ";YesNo", "w", nil, guid) == 1 then
          return false
        end
      end
      if self._panel_mode == "db" or self._panel_mode == "table" then
        if far.Message(M.drop_question, M.title_short, ";YesNo", "w", nil, guid) == 1 then
          return false
        end
      end
    end
    return true
  elseif key=="CtrlShiftBackSlash" then
    panel.ClosePanel(handle)
  end
end


function mypanel:handle_keyboard(handle, key_event)
  local key = far.InputRecordToName(key_event)
  if key then
    key = key:gsub("RCtrl","Ctrl"):gsub("RAlt","Alt")
    if self._panel_mode == "db" then
      local ret = self:handle_key_db(handle,key)
      if ret ~= nil then return ret end
    elseif self._panel_mode == "table" or self._panel_mode == "view" then
      local ret = self:handle_key_tbview(handle,key)
      if ret ~= nil then return ret end
      if self._panel_mode == "table" then
        ret = self:handle_key_table(handle, key)
        if ret ~= nil then return ret end
      end
    end
    return self:handle_key_all(handle, key)
  end
end


function mypanel:view_db_object()
  -- Get selected object name
  local item = panel.GetCurrentPanelItem(nil,1)
  if not item or item.FileName == ".." then
    return
  end

  local tmp_file_name
  local RealItemName = item.FileName

  -- For unknown types show create sql only
  if not item.FileAttributes:find("d") then
    local cr_sql = dbx.get_creation_sql(self._db, self._schema, item.FileName)
    if not cr_sql then
      return
    end
    tmp_file_name = utils.get_temp_file_name("sql")

    local file = io.open(tmp_file_name, "wb")
    if not file then
      ErrMsg(M.err_writef.."\n"..tmp_file_name, nil, "we")
      return
    end
    if not file:write(cr_sql) then
      file:close()
      ErrMsg(M.err_writef.."\n"..tmp_file_name, nil, "we")
      return
    end
    file:close()
  else
    -- Export data
    local ex = exporter.newexporter(self._db, self._filename, self._schema)
    tmp_file_name = utils.get_temp_file_name("txt")
    local ok = ex:export_data_as_text(tmp_file_name, RealItemName)
    if not ok then return end
  end
  local title = M.title_short .. ": " .. RealItemName
  viewer.Viewer(tmp_file_name, title, 0, 0, -1, -1, bit64.bor(
    F.VF_ENABLE_F6, F.VF_DISABLEHISTORY, F.VF_DELETEONLYFILEONCLOSE, F.VF_IMMEDIATERETURN, F.VF_NONMODAL), 65001)
  viewer.SetMode(nil, { Type=F.VSMT_WRAP,     iParam=0,          Flags=0 })
  viewer.SetMode(nil, { Type=F.VSMT_VIEWMODE, iParam=F.VMT_TEXT, Flags=F.VSMFL_REDRAW })
end


function mypanel:view_db_create_sql()
  -- Get selected object name
  local item = panel.GetCurrentPanelItem(nil,1)
  if item and item.FileName ~= ".." then
    local RealItemName = item.FileName
    local cr_sql = dbx.get_creation_sql(self._db, self._schema, RealItemName)
    if cr_sql then
      local tmp_path = far.MkTemp()..".sql"
      local file = io.open(tmp_path, "w")
      if file and file:write(cr_sql) then
        file:close()
        viewer.Viewer(tmp_path, RealItemName, nil, nil, nil, nil,
          F.VF_ENABLE_F6 + F.VF_DISABLEHISTORY + F.VF_DELETEONLYFILEONCLOSE + F.VF_NONMODAL, 65001)
      else
        if file then file:close() end
        ErrMsg(M.err_writef.."\n"..tmp_path, nil, "we")
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
    local W = 65
    local items = {
      guid = "FF769EE0-2643-48F1-A8A2-239CD3C6691F";
      width = W;
      { tp="dbox"; text=("%s [%s]"):format(M.title_pragma, self._schema);              },
      { tp="listbox"; x1=4; x2=W-5; y2=15; list=items; listnobox=1; listnoampersand=1;
                      listnoclose=1; },
      { tp="sep";                                                                      },
      { tp="butt"; text=M.ok; centergroup=1; default=1;                                },
    }
    sdialog.New(items):Run()
  end
end


function mypanel:edit_query(query)
  -- Create a file containing the selected query
  local tmp_name = utils.get_temp_file_name("sql")
  local fp = io.open(tmp_name, "w")
  if fp then
    fp:write(query)
    fp:close()
  else
    ErrMsg(M.err_writef.."\n"..tmp_name, nil, "we")
    return nil
  end

  -- Open query editor
  query = nil
  local flags = F.EF_DISABLEHISTORY + (OS_WIN and F.EF_DISABLESAVEPOS or 0)
  if F.EEC_MODIFIED==editor.Editor(tmp_name,"SQLite query",nil,nil,nil,nil,flags,nil,nil,65001) then
    fp = io.open(tmp_name)
    if fp then
      query = fp:read("*all")
      fp:close()
      query = string.gsub(query, "^\239\187\191", "")  -- remove UTF-8 BOM
      query = string.gsub(query, "^%s*(.-)%s*$", "%1") -- remove leading and trailing space
      if not query:find("%S") then
        query = nil
      end
    else
      ErrMsg(M.err_read.."\n"..tmp_name, nil, "we")
    end
  end

  -- Delete the file.
  win.DeleteFile(tmp_name)
  return query
end


function mypanel:sql_query_history(handle)
  -- Prepare menu data
  local queries = q_history.new()
  local qarray = queries._array
  local state = { query=""; }

  local props = {
    Bottom = "F1 F4 F6 Ctrl+C Ctrl+Enter Shift+Del";
    SelectIndex = #qarray;
    HelpTopic = "queries_history";
  }
  local brkeys = {
    { BreakKey="F4";         action="edit";       },
    { BreakKey="F6";         action="newedit";    },
    { BreakKey="C+RETURN";   action="insert";     },
    { BreakKey="C+C";        action="copy";       },
    { BreakKey="C+INSERT";   action="copy";       },
    { BreakKey="CS+C";       action="copyserial"; },
    { BreakKey="CS+INSERT";  action="copyserial"; },
    { BreakKey="S+DELETE";   action="delete";     },
  }

  while true do
    local H = far.AdvControl("ACTL_GETFARRECT")
    props.MaxHeight = (H.Bottom - H.Top + 1) - 8
    props.Title = M.select_query.." ["..#qarray.."]"
    local items = {}
    for i,v in ipairs(qarray) do items[i] = { text=v; } end

    -- Show the menu
    local item, pos = far.Menu(props, items, brkeys)
    if item then
      local query = items[pos] and items[pos].text
      if item.action == nil then -- Enter pressed
        if query then self:open_query(handle, query); break; end

      elseif item.action == "insert" then
        if query then panel.SetCmdLine(handle, query); break; end

      elseif item.action == "copy" then
        if query then far.CopyToClipboard(query); break; end

      elseif item.action == "copyserial" then
        -- table.concat is not OK here as individual entries may contain line feeds inside them
        if query then far.CopyToClipboard(settings.serialize(qarray)); break; end

      elseif item.action == "delete" then
        if query then
          table.remove(qarray, pos)
          props.SelectIndex = #qarray
          state.modified = true
        end

      elseif item.action == "edit" or item.action == "newedit" then
        query = self:edit_query(item.action=="edit" and query or "")
        if query then
          self:open_query(handle, query) -- it saves the history internally
          return
        else
          props.SelectIndex = pos
        end
      end

    else
      break
    end
  end
  if state.modified then queries:save() end
end


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


-- This function is called from polygon.c from CompareW exported function.
-- CRITICAL: its semantics must be in accordance with polygon.c.
-- Its return value (ret) if < 1 is treated as CompareW return value,
-- otherwise as the 1-based index into CustomColumnData array.
function export.Compare (self, handle, PanelItem1, PanelItem2, Mode)
  local ret
  local compare = CMP_ALPHA
  self:prepare_panel_info(handle)
  if self._panel_mode == "root" then
    if     Mode==F.SM_EXT   then ret,compare = 1,CMP_INT
    elseif Mode==F.SM_MTIME then ret,compare = 2,CMP_ALPHA
    else                         ret,compare = 0,CMP_ALPHA
    end
  elseif self._panel_mode == "db" then
    if Mode == F.SM_EXT then -- sort by object type ( CustomColumnData[1] )
      ret = 1
    else -- use Far Manager compare function
      ret = -2
    end
  else
    self._sort_col_index = self:get_sort_index(Mode)
    self:prepare_panel_info(handle)
    ret = self._sort_col_index or 0
    compare = self._sort_compare
  end
  return bit64.bor(ret+2, bit64.lshift(compare,8)) -- (ret + 2) | (compare << 8)
end


function mypanel:get_info()
  return {
    db          = self._db;
    file_name   = self._filename;
    multi_db    = self._multi_db;
    schema      = self._schema;
    panel_mode  = self._panel_mode;
    curr_object = self._objname;
    rowid_name  = self._rowid_name;
    get_rowid   = utils.get_rowid;
    __self      = self; -- BEWARE: direct access to self; the code using it will break on API changes
  }
end


return mypanel
