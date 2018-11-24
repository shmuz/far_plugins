-- exporter.lua
-- luacheck: globals ErrMsg

local sql3 = require "lsqlite3"
local F = far.Flags

local Params = ...
local M        = Params.M
local progress = Params.progress
local settings = Params.settings

local MAX_BLOB_LENGTH = 100
local MAX_TEXT_LENGTH = 1024

local exporter = {}
local mt_exporter = {__index=exporter}


function exporter.newexporter(dbx, filename)
  return setmetatable({_dbx=dbx; _file_name=filename}, mt_exporter)
end


function exporter:export_data_with_dialog()
  local data = settings.load():getfield("exporter")

  -- Get source table/view name
  local item = panel.GetCurrentPanelItem(nil, 1)
  if not (item and item.FileName~=".." and item.FileAttributes:find("d")) then
    return false
  end
  local db_object_name = Params.DecodeItemName(item)

  -- Get destination path
  local dst_file_name = panel.GetPanelDirectory(nil, 0).Name
  if not (dst_file_name == "" or dst_file_name:find("\\$")) then
    dst_file_name = dst_file_name .. "\\"
  end
  dst_file_name = dst_file_name .. db_object_name

  local FLAG_DFLT = bit64.bor(F.DIF_CENTERGROUP, F.DIF_DEFAULTBUTTON)
  local dlg_items = {
  --[[01]] {F.DI_DOUBLEBOX,     3,1,68,9,  0,0,0,0,                  M.ps_exp_title},
  --[[02]] {F.DI_TEXT,          5,2,66,0,  0,0,0,0,                  M.ps_exp_main:format(db_object_name)},
  --[[03]] {F.DI_EDIT,          5,3,66,0,  0,0,0,0,                  ""},
  --[[04]] {F.DI_TEXT,          0,4, 0,0,  0,0,0,F.DIF_SEPARATOR,    ""},
  --[[05]] {F.DI_TEXT,          5,5,20,0,  0,0,0,0,                  M.ps_exp_fmt},
  --[[06]] {F.DI_RADIOBUTTON,  21,5,29,0,  0,0,0,0,                  "&CSV"},
  --[[07]] {F.DI_RADIOBUTTON,  31,5,40,0,  0,0,0,0,                  M.ps_exp_fmt_text},
  --[[08]] {F.DI_CHECKBOX,     21,6, 0,0,  0,0,0,0,                  M.ps_exp_multiline},
  --[[09]] {F.DI_TEXT,          0,7, 0,0,  0,0,0,F.DIF_SEPARATOR,    ""},
  --[[10]] {F.DI_BUTTON,        0,8, 0,0,  0,0,0,FLAG_DFLT,          M.ps_exp_exp},
  --[[11]] {F.DI_BUTTON,        0,8, 0,0,  0,0,0,F.DIF_CENTERGROUP,  M.ps_cancel},
  }
  local edtFileName = 3
  local btnCSV, btnText, btnMultiline, btnCancel = 6, 7, 8, 11

  ------------------------------------------------------------------------------
  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      hDlg:send(F.DM_SETCHECK, (data.format=="csv" and btnCSV or btnText), 1)
      hDlg:send(F.DM_SETCHECK, btnMultiline, data.multiline and 1 or 0)

    elseif Msg == F.DN_BTNCLICK then
      if Param1 == btnCSV or Param1 == btnText then
        local csv   = hDlg:send(F.DM_GETCHECK, btnCSV) == F.BSTATE_CHECKED
        local fname = dst_file_name .. (csv and ".csv" or ".txt")
        hDlg:send(F.DM_SETTEXT, edtFileName, fname)
        hDlg:send(F.DM_ENABLE, btnMultiline, csv and 1 or 0)
      end
    end
  end
  ------------------------------------------------------------------------------

  local guid = win.Uuid("E9F91B4F-82B2-4B36-9C4B-240D7EE7BF59")
  local dlg = far.DialogInit(guid, -1, -1, 72, 11, nil, dlg_items, nil, DlgProc)

  local rc = far.DialogRun(dlg)
  if rc >= 1 and rc ~= btnCancel then
    local file_name  = dlg:send(F.DM_GETTEXT, edtFileName)
    data.format      = 0 ~= dlg:send(F.DM_GETCHECK, btnCSV) and "csv" or "text"
    data.multiline   = 0 ~= dlg:send(F.DM_GETCHECK, btnMultiline)
    far.DialogFree(dlg)
    settings.save()

    if data.format == "csv" then
      return self:export_data_as_csv(file_name, db_object_name, data.multiline)
    else
      return self:export_data_as_text(file_name, db_object_name)
    end
  else
    far.DialogFree(dlg)
    return false
  end
end


function exporter:dump_data_with_dialog()
  local data = settings.load():getfield("exporter")

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
      item.FileName = Params.DecodeItemName(item)
      table.insert(t_selected, item)
    end
  end

  -- Get destination path
  local dst_file_name = panel.GetPanelDirectory(nil, 0).Name
  if not (dst_file_name == "" or dst_file_name:find("\\$")) then
    dst_file_name = dst_file_name .. "\\"
  end
  dst_file_name = dst_file_name .. "dump1.dump"

  local FLAG_DFLT = bit64.bor(F.DIF_CENTERGROUP, F.DIF_DEFAULTBUTTON)
  local dlg_items = {
  --[[01]] {F.DI_DOUBLEBOX,     3,1,68,10,  0,0,0,0,                  M.ps_dump_title},
  --[[02]] {F.DI_TEXT,          5,2,66, 0,  0,0,0,0,                  M.ps_dump_main},
  --[[03]] {F.DI_EDIT,          5,3,66, 0,  0,0,0,0,                  ""},
  --[[04]] {F.DI_TEXT,          0,4, 0, 0,  0,0,0,F.DIF_SEPARATOR,    ""},
  --[[05]] {F.DI_CHECKBOX,      5,5, 0, 0,  0,0,0,0,                  M.ps_dump_dumpall},
  --[[06]] {F.DI_CHECKBOX,      5,6, 0, 0,  0,0,0,0,                  M.ps_dump_rowids},
  --[[07]] {F.DI_CHECKBOX,      5,7, 0, 0,  0,0,0,0,                  M.ps_dump_newlines},
  --[[08]] {F.DI_TEXT,          0,8, 0, 0,  0,0,0,F.DIF_SEPARATOR,    ""},
  --[[09]] {F.DI_BUTTON,        0,9, 0, 0,  0,0,0,FLAG_DFLT,          M.ps_dump_dump},
  --[[10]] {F.DI_BUTTON,        0,9, 0, 0,  0,0,0,F.DIF_CENTERGROUP,  M.ps_cancel},
  }
  local edtFileName = 3
  local btn_dumpall, btn_rowids, btn_newline, btnExport, btnCancel = 5, 6, 7, 9, 10

  ------------------------------------------------------------------------------
  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      hDlg:send(F.DM_SETTEXT,  edtFileName, dst_file_name)
      hDlg:send(F.DM_SETCHECK, btn_dumpall, data.dump_dumpall and 1 or 0)
      hDlg:send(F.DM_SETCHECK, btn_rowids, data.dump_rowids and 1 or 0)
      hDlg:send(F.DM_SETCHECK, btn_newline, data.dump_newline and 1 or 0)
      if t_selected[1] == nil then
        hDlg:send(F.DM_SETCHECK, btn_dumpall, 1)
        hDlg:send(F.DM_ENABLE, btn_dumpall, 0)
      end

    elseif Msg == F.DN_BTNCLICK then

    elseif Msg == F.DN_CLOSE and Param1 == btnExport then
      -- check if the output file already exists
      local fname = hDlg:send(F.DM_GETTEXT, edtFileName)
      if win.GetFileAttr(fname) then
        local r = far.Message(M.ps_already_exists..":\n"..fname, M.ps_warning,
                              M.ps_overwrite..";"..M.ps_cancel, "w")
        if r~=1 then return 0; end
      end
      -- check that the output file can be created
      local fp = io.open(fname, "w")
      if fp then fp:close(); win.DeleteFile(fname)
      else ErrMsg(M.ps_err_openfile..":\n"..fname); return 0
      end
    end
  end
  ------------------------------------------------------------------------------

  local guid = win.Uuid("B6EBFACA-232D-42FA-887E-66C7B03DB65D")
  local dlg = far.DialogInit(guid, -1, -1, 72, 12, "Dump", dlg_items, nil, DlgProc)

  local rc = far.DialogRun(dlg)
  if rc >= 1 and rc ~= btnCancel then
    local file_name = dlg:send(F.DM_GETTEXT,  edtFileName)
    data.dump_dumpall = 0 ~= dlg:send(F.DM_GETCHECK, btn_dumpall)
    data.dump_rowids  = 0 ~= dlg:send(F.DM_GETCHECK, btn_rowids)
    data.dump_newline = 0 ~= dlg:send(F.DM_GETCHECK, btn_newline)
    far.DialogFree(dlg)
    settings.save()
    return self:export_data_as_dump {
        file_name = file_name;
        items     = t_selected;
        dumpall   = data.dump_dumpall;
        rowids    = data.dump_rowids;
        newline   = data.dump_newline;
      }
  else
    far.DialogFree(dlg)
    return false
  end
end


function exporter:export_data_as_text(file_name, db_object)
  local dbx = self._dbx
  -- Get row count and  columns description
  local row_count = dbx:get_row_count(db_object)
  local columns_descr = dbx:read_column_description(db_object)
  if not (row_count and columns_descr) then
    ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
    return false
  end

  local columns_count = #columns_descr
  local prg_wnd = progress.newprogress(M.ps_reading, row_count)

  -- Get maximum width for each column
  local columns_width = {}
  local query_val, query_len = "select ", "select "
  for i = 1, columns_count do
    if i > 1 then
      query_val = query_val .. ", "
      query_len = query_len .. ", "
    end
    query_val = query_val .. "[" .. columns_descr[i].name .. "]"
    query_len = query_len .. "length([" .. columns_descr[i].name .. "])"
  end
  query_val = query_val .. " from '" .. db_object .. "'"
  query_len = query_len .. " from '" .. db_object .. "'"

  for i = 1, columns_count do
    columns_width[i] = columns_descr[i].name:len() -- initialize with widths of titles
  end
  local db = dbx:db()
  local stmt_val = db:prepare(query_val)
  local stmt_len = db:prepare(query_len)
  if stmt_val and stmt_len then
    while stmt_val:step() == sql3.ROW do
      stmt_len:step()
      for i = 1, columns_count do
        local len = stmt_len:get_value(i-1) or 1
        if stmt_val:get_column_type(i-1) == sql3.BLOB then
          len = len*2 + #tostring(len) + 3 -- correction for e.g. [24]:
        end
        columns_width[i] = math.max(columns_width[i], len)
        columns_width[i] = math.min(columns_width[i], MAX_TEXT_LENGTH)
      end
    end
    stmt_val:finalize()
    stmt_len:finalize()
  end

  -- Create output file
  local file = io.open(file_name, "wb")
  if not file then
    prg_wnd:hide()
    ErrMsg(M.ps_err_writef.."\n"..file_name, nil, "we")
    return false
  end

  -- Write BOM for text file
  file:write("\239\187\191") -- UTF-8 BOM

  -- Write header (columns names)
  local out_text = ""
  for i = 1, columns_count do
    local col_name = (i==1 and "" or " ") .. columns_descr[i].name
    local n = columns_width[i] + (i > 1 and i < columns_count and 2 or 1)
    out_text = out_text .. col_name:resize(n, " ")
    if i < columns_count then
      out_text = out_text .. unicode.utf8.char(0x2502)
    end
  end
  out_text = out_text .. "\r\n"

  -- Header separator
  for i = 1, columns_count do
    local col_sep = unicode.utf8.char(0x2500):rep(
      columns_width[i] + (i > 1 and i ~= columns_count and 2 or 1))
    out_text = out_text .. col_sep
    if i < columns_count then
      out_text = out_text .. unicode.utf8.char(0x253C)
    end
  end
  file:write(out_text, "\r\n")

  -- Read data
  local query = "select * from " .. db_object:normalize() .. ";"
  local db = dbx:db()
  local stmt = db:prepare(query)
  if not stmt then
    prg_wnd:hide()
    file:close()
    ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
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
    for i = 1, columns_count do
      local col_data = exporter.get_text(stmt, i-1, false):gsub("%s+", " ")
      if col_data:len() > columns_width[i] then
        col_data = col_data:sub(1, columns_width[i]-3) .. "..."
      end
      if i > 1 then
        col_data = " " .. col_data
      end
      local sz = columns_width[i] + (i > 1 and i < columns_count and 2 or 1)
      out_text = out_text .. col_data:resize(sz, " ")
      if i < columns_count then
        out_text = out_text .. unicode.utf8.char(0x2502)
      end
    end

    if not file:write(out_text, "\r\n") then
      prg_wnd:hide()
      stmt:finalize()
      file:close()
      ErrMsg(M.ps_err_writef.."\n"..file_name, nil, "we")
      return false
    end
  end

  file:close()
  prg_wnd:hide()
  stmt:finalize()

  if state == sql3.DONE then
    return true
  else
    ErrMsg(M.ps_err_read.."\n"..dbx:last_error())
    return false
  end
end


function exporter:export_data_as_csv(file_name, db_object, multiline)
  -- Get row count and  columns description
  local row_count = self._dbx:get_row_count(db_object)
  local columns_descr = self._dbx:read_column_description(db_object)
  if not (row_count and columns_descr) then
    ErrMsg(M.ps_err_read.."\n"..self._dbx:last_error())
    return false
  end

  -- Create output file
  local file = io.open(file_name, "wb")
  if not file then
    ErrMsg(M.ps_err_writef.."\n"..file_name, nil, "we")
    return false
  end

  local columns_count = #columns_descr
  local prg_wnd = progress.newprogress(M.ps_reading, row_count)

  -- Write header (columns names)
  local out_text = ""
  for i = 1, columns_count do
    out_text = out_text .. columns_descr[i].name
    if i ~= columns_count then
      out_text = out_text .. ';'
    end
  end
  file:write(out_text, "\r\n")

  -- Read data
  local query = "select * from " .. db_object:normalize() .. ";"
  local db = self._dbx:db()
  local stmt = db:prepare(query)
  if not stmt then
    prg_wnd:hide()
    file:close()
    local err_descr = self._dbx:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
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
    for i = 1, columns_count do
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
      if i < columns_count then
        out_text = out_text .. ';'
      end
    end

    ok_write = file:write(out_text, "\r\n")
    if not ok_write then break end
  end

  file:close()
  prg_wnd:hide()
  stmt:finalize()

  if state == sql3.DONE and ok_write then
    return true
  elseif not ok_write then
    ErrMsg(M.ps_err_writef.."\n"..file_name, nil, "we")
  else
    ErrMsg(M.ps_err_read.."\n"..self._dbx:last_error())
  end
  return false
end


function exporter:export_data_as_dump(Args)
  local s1 = ".dump"
  if Args.rowids  then s1 = s1 .. " --preserve-rowids"; end
  if Args.newline then s1 = s1 .. " --newlines"; end

  local t = { [1]='"'..self._file_name..'"'; }
  if Args.dumpall then
    t[2] = '"'..s1..'"'
  else
    for i,item in ipairs(Args.items) do
      t[i+1] = '"'..s1..' '..item.FileName:normalize()..'"'
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


local patt_unreadable = "[%z"..string.char(1).."-"..string.char(0x20-1).."]"
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
      data = string.gsub(data, patt_unreadable, " ")
    end
  end
  return data or ""
end


return exporter
