-- coding: UTF-8

local sql3     = require "lsqlite3"
local sdialog  = require "far2.simpledialog"
local M        = require "modules.string_rc"
local progress = require "modules.progress"
local settings = require "modules.settings"
local utils    = require "modules.utils"

-- settings --
local MAX_BLOB_LENGTH = 100
local MAX_TEXT_LENGTH = 1024
-- /settings --

local CHAR_HORIS = ("").char(9472) -->  ─
local CHAR_VERT  = ("").char(9474) -->  │
local CHAR_CROSS = ("").char(9532) -->  ┼


local F = far.Flags
local ErrMsg, Resize, Norm = utils.ErrMsg, utils.Resize, utils.Norm

local exporter = {}
local mt_exporter = {__index=exporter}


function exporter.newexporter(dbx, filename, schema)
  local self = {_dbx=dbx; _db=dbx:db(); _filename=filename, _schema=schema}
  return setmetatable(self, mt_exporter)
end


function exporter:get_destination_dir()
  local dir = panel.GetPanelDirectory(nil, 0).Name
  if dir == "" then -- passive panel's directory is unknown, choose host file directory
    dir = self._filename:match(".*\\") or ""
  end
  if not (dir=="" or dir:sub(-1)=="\\") then
    dir = dir .. "\\"
  end
  return dir
end


function exporter:export_data_with_dialog()
  local data = settings.load().exporter

  -- Get source table/view name
  local item = panel.GetCurrentPanelItem(nil, 1)
  if not (item and item.FileName~=".." and item.FileAttributes:find("d")) then
    return false
  end
  local db_object_name = item.FileName
  local dst_file_name = self:get_destination_dir() .. db_object_name

  local Items = {
    guid="E9F91B4F-82B2-4B36-9C4B-240D7EE7BF59";
    help="Export";
    width=72;
    {tp="dbox";   text=M.exp_title;                                          },
    {tp="text";   text=utils.lang(M.exp_main, {db_object_name});             },
    {tp="edit";                                          name="targetfile";  },
    {tp="sep";                                                               },
    {tp="text";   text=M.exp_fmt;                                            },
    {tp="rbutt";  text=M.exp_fmt_csv;                    name="csv"; group=1 },
    {tp="rbutt";  text=M.exp_fmt_text;                   name="text";        },
    {tp="cbox";   text=M.exp_multiline; x1=16; ystep=-1; name="multiline";   },
    {tp="sep";                                 ystep=2;                      },
    {tp="butt";   text=M.exp_exp; centergroup=1; default=1;                  },
    {tp="butt";   text=M.cancel;  centergroup=1; cancel=1;                   },
  }
  local Pos, _ = sdialog.Indexes(Items)
  ------------------------------------------------------------------------------
  Items.proc = function(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      hDlg:send(F.DM_SETCHECK, data.format=="csv" and Pos.csv or Pos.text, 1)
      hDlg:send(F.DM_SETCHECK, Pos.multiline, data.multiline and 1 or 0)

    elseif Msg == F.DN_BTNCLICK then
      if Param1 == Pos.csv or Param1 == Pos.text then
        local csv = hDlg:send(F.DM_GETCHECK, Pos.csv) == F.BSTATE_CHECKED
        local fname = dst_file_name .. (csv and ".csv" or ".txt")
        hDlg:send(F.DM_SETTEXT, Pos.targetfile, fname)
        hDlg:send(F.DM_ENABLE, Pos.multiline, csv and 1 or 0)
      end
    end
  end
  ------------------------------------------------------------------------------
  local rc = sdialog.Run(Items)
  if rc then
    data.format = rc.csv and "csv" or "text"
    data.multiline = rc.multiline
    settings.save()
    if data.format == "csv" then
      return self:export_data_as_csv(rc.targetfile, db_object_name, rc.multiline)
    else
      return self:export_data_as_text(rc.targetfile, db_object_name)
    end
  end
  return false
end


function exporter:dump_data_with_dialog()
  local data = settings.load().exporter

  -- Collect selected items for dump
  local t_selected = {}
  local p_info = panel.GetPanelInfo(nil,1)
  for i=1,p_info.SelectedItemsNumber do
    local item = panel.GetSelectedPanelItem(nil, 1, i)
    if item
       and item.FileName ~= ".."
       and item.FileAttributes:find("d")
       and item.CustomColumnData[1] ~= "metadata" -- exclude sqlite_master
    then
      table.insert(t_selected, item)
    end
  end
  local dst_file_name = self:get_destination_dir() .. "dump1.dump"

  local Items = {
    guid="B6EBFACA-232D-42FA-887E-66C7B03DB65D";
    help="Dump";
    width=72;
    {tp="dbox";  text=M.dump_title;                                           },
    {tp="text";  text=M.dump_main;                                            },
    {tp="edit";  text=dst_file_name;   name="targetfile";                     },
    {tp="sep";                                                                },
    {tp="cbox";  text=M.dump_dumpall;  name="dumpall"; val=data.dump_dumpall; },
    {tp="cbox";  text=M.dump_rowids;   name="rowids";  val=data.dump_rowids;  },
    {tp="cbox";  text=M.dump_newlines; name="newline"; val=data.dump_newline; },
    {tp="sep";                                                                },
    {tp="butt";  text=M.dump_dump; centergroup=1; default=1;                  },
    {tp="butt";  text=M.cancel;    centergroup=1; cancel=1;                   },
  }
  local Pos, _ = sdialog.Indexes(Items)
  ------------------------------------------------------------------------------
  function Items.initaction(hDlg)
    if t_selected[1] == nil then
      hDlg:send(F.DM_SETCHECK, Pos.dumpall, 1)
      hDlg:send(F.DM_ENABLE,   Pos.dumpall, 0)
    end
  end

  function Items.closeaction(hDlg, Param1, tOut)
    -- check if the output file already exists
    local fname = tOut.targetfile
    if win.GetFileAttr(fname) then
      local r = far.Message(M.already_exists..":\n"..fname, M.warning,
                            M.overwrite..";"..M.cancel, "w")
      if r~=1 then return 0; end
    end
    -- check that the output file can be created
    local fp = io.open(fname, "w")
    if fp then fp:close(); win.DeleteFile(fname)
    else ErrMsg(M.err_openfile..":\n"..fname); return 0
    end
  end
  ------------------------------------------------------------------------------
  local rc = sdialog.Run(Items)
  if rc then
    data.dump_dumpall = rc.dumpall
    data.dump_rowids  = rc.rowids
    data.dump_newline = rc.newline
    settings.save()
    return self:export_data_as_dump {
        items     = t_selected;
        file_name = rc.targetfile;
        dumpall   = rc.dumpall;
        rowids    = rc.rowids;
        newline   = rc.newline;
      }
  else
    return false
  end
end


function exporter:export_data_as_text(file_name, db_object)
  local dbx = self._dbx
  local db = dbx:db()

  local row_count = dbx:get_row_count(self._schema, db_object)
  if not row_count then return end

  local col_info = dbx:read_columns_info(self._schema, db_object)
  if not col_info then return end

  local col_count = #col_info
  local prg_wnd = progress.newprogress(M.reading, row_count)

  -- Get maximum width for each column
  local col_widths = {}
  local query_val, query_len = "select ", "select "
  for i = 1, col_count do
    if i > 1 then
      query_val = query_val .. ", "
      query_len = query_len .. ", "
    end
    query_val = query_val .. "[" .. col_info[i].name .. "]"
    query_len = query_len .. "length([" .. col_info[i].name .. "])"
  end
  query_val = ("%s from %s.%s"):format(query_val, Norm(self._schema), Norm(db_object))
  query_len = ("%s from %s.%s"):format(query_len, Norm(self._schema), Norm(db_object))

  for i = 1, col_count do
    col_widths[i] = col_info[i].name:len() -- initialize with widths of titles
  end
  local stmt_val = db:prepare(query_val)
  local stmt_len = db:prepare(query_len)
  if stmt_val and stmt_len then
    while stmt_val:step() == sql3.ROW do
      stmt_len:step()
      for i = 1, col_count do
        local len = stmt_len:get_value(i-1) or 1
        if stmt_val:get_column_type(i-1) == sql3.BLOB then
          len = len*2 + #tostring(len) + 3 -- correction for e.g. [24]:
        end
        col_widths[i] = math.min(MAX_TEXT_LENGTH, math.max(len, col_widths[i]))
      end
    end
    stmt_val:finalize()
    stmt_len:finalize()
  end

  -- Create output file
  local file = io.open(file_name, "wb")
  if not file then
    prg_wnd:hide()
    ErrMsg(M.err_writef.."\n"..file_name, nil, "we")
    return false
  end

  -- Write BOM for text file
  file:write("\239\187\191") -- UTF-8 BOM

  -- Write header (columns names)
  local out_text = ""
  for i = 1, col_count do
    local col_name = (i==1 and "" or " ") .. col_info[i].name
    local n = col_widths[i] + (i > 1 and i < col_count and 2 or 1)
    out_text = out_text .. Resize(col_name, n, " ")
    if i < col_count then
      out_text = out_text .. CHAR_VERT
    end
  end
  out_text = out_text .. "\r\n"

  -- Header separator
  for i = 1, col_count do
    local col_sep = CHAR_HORIS:rep(col_widths[i] + (i > 1 and i ~= col_count and 2 or 1))
    out_text = out_text .. col_sep
    if i < col_count then
      out_text = out_text .. CHAR_CROSS
    end
  end
  file:write(out_text, "\r\n")

  -- Read data
  local query = "select * from " .. Norm(self._schema).."."..Norm(db_object) .. ";"
  local stmt = db:prepare(query)
  if not stmt then
    prg_wnd:hide()
    file:close()
    ErrMsg(M.err_read.."\n"..dbx:last_error())
    return false
  end

  local count = 0
  local state
  while true do
    state = stmt:step()
    if state ~= sql3.ROW then
      break
    end
    count = count + 1
    if count % 100 == 0 then
      prg_wnd:update(count)
    end
    if progress.aborted() then
      prg_wnd:hide()
      stmt:finalize()
      file:close()
      return false
    end

    out_text = ""
    for i = 1, col_count do
      local col_data = exporter.get_text(stmt, i-1, false):gsub("%s+", " ")
      if col_data:len() > col_widths[i] then
        col_data = col_data:sub(1, col_widths[i]-3) .. "..."
      end
      if i > 1 then
        col_data = " " .. col_data
      end
      local sz = col_widths[i] + (i > 1 and i < col_count and 2 or 1)
      out_text = out_text .. Resize(col_data, sz, " ")
      if i < col_count then
        out_text = out_text .. CHAR_VERT
      end
    end

    if not file:write(out_text, "\r\n") then
      prg_wnd:hide()
      stmt:finalize()
      file:close()
      ErrMsg(M.err_writef.."\n"..file_name, nil, "we")
      return false
    end
  end

  file:close()
  prg_wnd:hide()
  stmt:finalize()

  if state == sql3.DONE then
    return true
  else
    ErrMsg(M.err_read.."\n"..dbx:last_error())
    return false
  end
end


function exporter:export_data_as_csv(file_name, db_object, multiline)
  -- Get row count and columns info
  local row_count = self._dbx:get_row_count(self._schema, db_object)
  if not row_count then return end

  local col_info = self._dbx:read_columns_info(self._schema, db_object)
  if not col_info then return end

  -- Create output file
  local file = io.open(file_name, "w")
  if not file then
    ErrMsg(M.err_writef.."\n"..file_name, nil, "we")
    return
  end

  local col_count = #col_info
  local prg_wnd = progress.newprogress(M.reading, row_count)

  -- Write header (columns names)
  local out_text = ""
  for i = 1, col_count do
    out_text = out_text .. col_info[i].name
    if i ~= col_count then
      out_text = out_text .. ';'
    end
  end
  file:write(out_text, "\n")

  -- Read data
  local query = "SELECT * FROM " .. Norm(self._schema).."."..Norm(db_object)
  local stmt = self._db:prepare(query)
  if not stmt then
    prg_wnd:hide()
    file:close()
    local err_descr = self._dbx:last_error()
    ErrMsg(M.err_read.."\n"..err_descr)
    return false
  end

  local count = 0
  local state
  local ok_write = true
  while true do
    state = stmt:step()
    if state ~= sql3.ROW then
      break
    end
    count = count + 1
    if count % 100 == 0 then
      prg_wnd:update(count)
    end
    if progress.aborted() then
      file:close()
      return false
    end

    out_text = ""
    for i = 1, col_count do
      local col_data = exporter.get_text(stmt, i-1, multiline)
      local use_quote = col_data:find("[;\"\n\r]")
      if use_quote then
        out_text = out_text .. '"'
        -- Replace quote by double quote
        col_data = col_data:gsub('"', '""')
      end
      out_text = out_text .. col_data
      if use_quote then
        out_text = out_text .. '"'
      end
      if i < col_count then
        out_text = out_text .. ';'
      end
    end

    ok_write = file:write(out_text, "\n")
    if not ok_write then break end
  end

  file:close()
  prg_wnd:hide()
  stmt:finalize()

  if state == sql3.DONE and ok_write then
    return true
  elseif not ok_write then
    ErrMsg(M.err_writef.."\n"..file_name, nil, "we")
  else
    ErrMsg(M.err_read.."\n"..self._dbx:last_error())
  end
  return false
end


function exporter:export_data_as_dump(Args)
  local s1 = ".dump"
  if Args.rowids  then s1 = s1 .. " --preserve-rowids"; end
  if Args.newline then s1 = s1 .. " --newlines"; end

  local t = { [1]='"'..self._filename..'"'; }
  if Args.dumpall then
    t[2] = '"'..s1..'"'
  else
    for i,item in ipairs(Args.items) do
      t[i+1] = '"'..s1..' '..Norm(item.FileName)..'"'
    end
  end
  t[#t+1] = '1>"'..Args.file_name..'" 2>NUL'
  local cmd = table.concat(t, " ")
  ------------------------
  far.Message("Please wait...", "", "")
  local t_execs = { far.PluginStartupInfo().ModuleDir.."sqlite3.exe", "sqlite3.exe" }
  for _, exec in ipairs(t_execs) do
    -- use win.system because win.ShellExecute wouldn't reuse Far console.
    if 0 == win.system('""'..exec..'" '..cmd..'"') then break; end
  end
  ------------------------
  panel.RedrawPanel(nil,1)
  panel.RedrawPanel(nil,0)
  ------------------------
  panel.UpdatePanel(nil,0)
  panel.RedrawPanel(nil,0)
end


function exporter.get_text(stmt, idx, multiline)
  local data
  if stmt:get_column_type(idx) == sql3.BLOB then
    local blob_data = stmt:get_value(idx)
    local blob_len = #blob_data
    local tmp = { "["..blob_len.."]:" }
    for j = 1, math.min(blob_len, MAX_BLOB_LENGTH) do
      tmp[j+1] = ("%02x"):format(string.byte(blob_data, j))
    end
    if blob_len >= MAX_BLOB_LENGTH then tmp[#tmp+1] = "..."; end
    data = table.concat(tmp)
  else
    data = stmt:get_column_text(idx)
    -- Replace unreadable symbols
    if not multiline then
      data = string.gsub(data, "[%z\1-\31]", " ")
    end
  end
  return data or ""
end


return exporter
