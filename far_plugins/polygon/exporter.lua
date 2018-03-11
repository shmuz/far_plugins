-- exporter.lua

local sql3 = require "lsqlite3"
local F = far.Flags

local Params = ...
local M        = Params.M
local sqlite   = Params.sqlite
local progress = Params.progress
local settings = Params.settings

--  enum format {
local fmt_csv  = 0
local fmt_text = 1

local MAX_BLOB_LENGTH = 100
local MAX_TEXT_LENGTH = 1024

local exporter = {
  fmt_csv = fmt_csv;
  fmt_text = fmt_text;
}
local mt_exporter = {__index=exporter}


function exporter.newexporter(db)
  local self = setmetatable({}, mt_exporter)
  self._db = db
  return self
end


function exporter:export_data_with_dialog()
  local data = settings.load():getfield("exporter")

  -- Get source table/view name
  local item = panel.GetCurrentPanelItem(nil, 1)
  if not (item and item.FileName~=".." and item.FileAttributes:find("d")) then
    return false
  end
  local db_object_name = item.FileName

  -- Get destination path
  local dst_file_name = panel.GetPanelDirectory(nil, 0).Name
  if not (dst_file_name == "" or dst_file_name:find("\\$")) then
    dst_file_name = dst_file_name .. "\\"
  end
  dst_file_name = dst_file_name .. db_object_name

  local FLAG_DFLT = bit64.bor(F.DIF_CENTERGROUP, F.DIF_DEFAULTBUTTON, F.DIF_FOCUS)
  local dlg_items = {
  --[[01]] {F.DI_DOUBLEBOX,     3,1,56,9,  0,0,0,0,                  M.ps_exp_title},
  --[[02]] {F.DI_TEXT,          5,2,54,0,  0,0,0,0,                  M.ps_exp_main:format(db_object_name)},
  --[[03]] {F.DI_EDIT,          5,3,54,0,  0,0,0,0,                  ""},
  --[[04]] {F.DI_TEXT,          0,4, 0,0,  0,0,0,F.DIF_SEPARATOR,    ""},
  --[[05]] {F.DI_TEXT,          5,5,20,0,  0,0,0,0,                  M.ps_exp_fmt},
  --[[06]] {F.DI_RADIOBUTTON,  21,5,29,0,  0,0,0,0,                  "&CSV"},
  --[[07]] {F.DI_RADIOBUTTON,  31,5,40,0,  0,0,0,0,                  M.ps_exp_fmt_text},
  --[[08]] {F.DI_CHECKBOX   ,  21,6, 0,0,  0,0,0,0,                  M.ps_exp_multiline},
  --[[09]] {F.DI_TEXT,          0,7, 0,0,  0,0,0,F.DIF_SEPARATOR,    ""},
  --[[10]] {F.DI_BUTTON,        0,8, 0,0,  0,0,0,FLAG_DFLT,          M.ps_exp_exp},
  --[[11]] {F.DI_BUTTON,        0,8, 0,0,  0,0,0,F.DIF_CENTERGROUP,  M.ps_cancel},
  }
  local edtFileName = 3
  local btnCSV, btnText, btnMultiline, btnCancel = 6, 7, 8, 11

  ------------------------------------------------------------------------------
  local function DlgProc(hDlg, Msg, Param1, Param2)
    if Msg == F.DN_INITDIALOG then
      hDlg:send(F.DM_SETTEXT, edtFileName, dst_file_name)
      hDlg:send(F.DM_SETCHECK, (data.format=="csv" and btnCSV or btnText), 1)
      hDlg:send(F.DM_SETCHECK, btnMultiline, data.multiline and 1 or 0)

    elseif Msg == F.DN_BTNCLICK then
      if Param1 == btnCSV or Param1 == btnText then
        local csv   = hDlg:send(F.DM_GETCHECK, btnCSV) == F.BSTATE_CHECKED
        local ext   = csv and ".csv" or ".txt"
        local fname = hDlg:send(F.DM_GETTEXT, edtFileName):gsub("%.[^.]*$", "") .. ext
        hDlg:send(F.DM_SETTEXT, edtFileName, fname)
        hDlg:send(F.DM_ENABLE, btnMultiline, csv and 1 or 0)
      end
    end
  end
  ------------------------------------------------------------------------------

  local guid = win.Uuid("E9F91B4F-82B2-4B36-9C4B-240D7EE7BF59")
  local dlg = far.DialogInit(guid, -1, -1, 60, 11, nil, dlg_items, nil, DlgProc)

  local rc = far.DialogRun(dlg)
  if rc < 1 or rc == btnCancel then
    far.DialogFree(dlg)
    return false
  else
    dst_file_name = far.SendDlgMessage(dlg, F.DM_GETTEXT, edtFileName)
    local fmt = far.SendDlgMessage(dlg, F.DM_GETCHECK, btnCSV) ~= 0 and fmt_csv or fmt_text

    data.format = fmt==fmt_csv and "csv" or "text"
    data.multiline = far.SendDlgMessage(dlg, F.DM_GETCHECK, btnMultiline) ~= 0
    settings.save()

    far.DialogFree(dlg)
    return self:export_data(dst_file_name, db_object_name, fmt, data.multiline)
  end
end


function exporter:export_data(file_name, db_object, fmt, multiline)
  -- Get row count and  columns description
  local row_count = self._db:get_row_count(db_object)
  local columns_descr = {}
  
  if not row_count or not self._db:read_column_description(db_object, columns_descr) then
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  local columns_count = #columns_descr
  local prg_wnd = progress.newprogress(M.ps_reading, row_count)

  -- Get maximum width for each column
  local columns_width = {}
  if fmt == fmt_text then
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
    local db = self._db:db()
    local stmt_val = db:prepare(query_val)
    local stmt_len = db:prepare(query_len)
    if stmt_val and stmt_len then
      while stmt_val:step() == sql3.ROW do
        stmt_len:step()
        for i = 1, columns_count do
          local w = stmt_len:get_value(i-1) or 1
          if stmt_val:get_column_type(i-1) == sql3.BLOB then
            w = w*2 + #tostring(w) + 5 -- correction for e.g. [24]:0x
          end
          columns_width[i] = math.max(columns_width[i], w)
        end
      end
      stmt_val:finalize()
      stmt_len:finalize()
    end
    for i = 1, columns_count do
      columns_width[i] = math.min(columns_width[i], MAX_TEXT_LENGTH)
    end
  end

  -- Create output file
  local file = io.open(file_name, "wb")
  if not file then
    prg_wnd:hide()
    ErrMsg(M.ps_err_writef.."\n"..file_name, "we")
    return false
  end

  -- Write BOM for text file
  if fmt == fmt_text then
    file:write("\239\187\191") -- UTF-8 BOM
  end

  -- Write header (columns names)
  local out_text = ""
  for i = 1, columns_count do
    if fmt == fmt_csv then
      out_text = out_text .. columns_descr[i].name
      if i ~= columns_count then
        out_text = out_text .. ';'
      end
    else
      local col_name = ""
      if i > 1 then col_name = col_name .. ' '; end
      col_name = col_name .. columns_descr[i].name
      local n = columns_width[i] + (i > 1 and i < columns_count and 2 or 1)
      col_name = col_name:resize(n, " ")
      out_text = out_text .. col_name
      if i < columns_count then
        out_text = out_text .. unicode.utf8.char(0x2502)
      end
    end
  end
  out_text = out_text .. "\r\n"

  -- Header separator
  if fmt == fmt_text then
    for i = 1, #columns_descr do
      local col_sep = unicode.utf8.char(0x2500):rep(
        columns_width[i] + (i > 1 and i ~= columns_count and 2 or 1))
      out_text = out_text .. col_sep
      if i ~= columns_count then
        out_text = out_text .. unicode.utf8.char(0x253C)
      end
    end
    out_text = out_text .. "\r\n"
  end
  file:write(out_text)

  -- Read data
  local query = "select * from '" .. db_object .. "'"
  local db = self._db:db()
  local stmt = db:prepare(query)    
  if not stmt then
    prg_wnd:hide()
    file:close()
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  local count = 0
  local state = sql3.OK
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
      local col_data = exporter.get_text(stmt, i-1, (fmt == fmt_csv and multiline))
      if fmt == fmt_csv then
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
      else
        if i > 1 then
          col_data = " " .. col_data
        end
        local sz = columns_width[i] + (i > 1 and i < columns_count and 2 or 1)
        col_data = col_data:resize(sz, " ")
        if col_data:len() > MAX_TEXT_LENGTH then
          col_data = col_data:sub(1, MAX_TEXT_LENGTH-3) .. "..."
        end
        out_text = out_text .. col_data
        if i < columns_count then
          out_text = out_text .. unicode.utf8.char(0x2502)
        end
      end
    end
    out_text = out_text .. "\r\n"

    if not file:write(out_text) then
      prg_wnd:hide()
      stmt:finalize()
      file:close()
      ErrMsg(M.ps_err_writef.."\n"..file_name, "we")
      return false
    end
  end

  file:close()

  if state ~= sql3.DONE then
    prg_wnd:hide()
    stmt:finalize()
    local err_descr = self._db:last_error()
    ErrMsg(M.ps_err_read.."\n"..err_descr)
    return false
  end

  prg_wnd:hide()
  stmt:finalize()
  return true
end


function exporter.get_temp_file_name(ext)
  if ext then return far.MkTemp() .. "." .. ext
  else return far.MkTemp()
  end
end


local patt_unreadable = "[%z"..string.char(1).."-"..string.char(0x20-1).."]"
function exporter.get_text(stmt, idx, multiline)
  local data = ""
  if stmt:get_column_type(idx) == sql3.BLOB then
    local blob_data = stmt:get_value(idx)
    local blob_len = #blob_data
    local tmp = { "["..blob_len.."]:0x" }
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
  return data
end


return exporter
