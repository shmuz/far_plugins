--[[
 Goal: wrap long lines without breaking words.
--]]

local far2_dialog = require "far2.dialog"

local M = require "lf4ed_message"
local F = far.Flags
local insert, concat = table.insert, table.concat


-- iterator factory
local function EditorBlock (start_line)
  start_line = start_line or editor.GetInfo().BlockStartLine
  return function()
    local lineInfo = editor.GetString (nil, start_line, 1)
    if lineInfo and lineInfo.SelStart >= 1 and lineInfo.SelEnd ~= 0 then
      start_line = start_line + 1
      return lineInfo
    end
  end
end


local function EditorHasSelection (editInfo)
  return editInfo.BlockType ~= 0 and editInfo.BlockStartLine >= 1
end


local function EditorSelectCurLine (editInfo)
  return editor.Select (nil, "BTYPE_STREAM", editInfo.CurLine, 1, -1, 1)
end


local function Wrap (aColumn1, aColumn2, aJustify, aFactor)
  local editInfo = editor.GetInfo()
  if not EditorHasSelection (editInfo) then
    if EditorSelectCurLine (editInfo) then
      editInfo = editor.GetInfo()
    else
      return
    end
  end

  local linetable, jointable = {}, {}
  local function flush()
    if #jointable > 0 then
      insert (linetable, concat (jointable, " "))
      jointable = {}
    end
  end

  for line in EditorBlock (editInfo.BlockStartLine) do
    if line.StringText:find("%S") then
      insert (jointable, line.StringText)
    else
      flush()
      insert (linetable, "")
    end
  end
  flush()

  editor.DeleteBlock()

  local aMaxLineLen = aColumn2 - aColumn1 + 1
  local indent = (" "):rep(aColumn1 - 1)
  local lines_out = {} -- array for output lines

  -- Compile the next output line and store it.
  local function make_line (from, to, len, words)
    local extra = aMaxLineLen - len
    if aJustify and (aFactor * (to - from) >= extra) then
      for i = from, to - 1 do
        local sp = math.floor ((extra / (to - i)) + 0.5)
        words[i] = words[i] .. string.rep (" ", sp+1)
        extra = extra - sp
      end
      insert (lines_out, indent .. concat (words, "", from, to))
    else
      insert (lines_out, indent .. concat (words, " ", from, to))
    end
  end

  -- Iterate on selected lines (input lines); make and collect output lines.
  for _,line in ipairs(linetable) do
    -- Iterate on words on the currently processed line.
    local ind, start, len = 0, 1, -1
    local words = {}
    for w in line:gmatch ("%S+") do
      ind = ind + 1
      words[ind] = w
      local wlen = w:len()
      local newlen = len + 1 + wlen
      if newlen > aMaxLineLen then
        if len > 0 then
          make_line (start, ind-1, len, words)
          start, len = ind, wlen
        else
          make_line (ind, ind, wlen, words)
          start, len = ind+1, -1
        end
      else
        len = newlen
      end
    end

    if ind == 0 or len > 0 then
      make_line (start, #words, len, words)
    end
  end

  -- Put reformatted lines into the editor
  local Pos = { CurLine=editInfo.BlockStartLine, CurPos=1, TopScreenLine=editInfo.TopScreenLine }
  editor.SetPosition (nil, Pos)
  for i = #lines_out, 1, -1 do
    editor.InsertString()
    editor.SetPosition (nil, Pos)
    editor.SetString(nil, nil, lines_out[i])
  end
  editor.Redraw()
end


local dialogGuid = win.Uuid("6d5c7ec2-8c2f-413c-81e6-0cc8ffc0799a")

local function ExecuteWrapDialog (aData)
  local HIST_PROCESS = "LuaFAR\\Reformat\\ProcessLines"
  local D = far2_dialog.NewDialog()
  D._           = {"DI_DOUBLEBOX",3,1,72,10,   0, 0, 0, 0, M.MReformatBlock}
  D.cbxReformat = {"DI_CHECKBOX", 5,2, 0, 0,   0, 0, 0, 0, M.MReformatBlock2}
  D.labStart    = {"DI_TEXT",     9,3, 0, 0,   0, 0, 0, 0, M.MStartColumn}
  D.edtColumn1  = {"DI_FIXEDIT", 22,3,25, 3,   0, 0, "9999", "DIF_MASKEDIT", "1"}
  D.labEnd      = {"DI_TEXT",    29,3, 0, 0,   0, 0, 0, 0, M.MEndColumn}
  D.edtColumn2  = {"DI_FIXEDIT", 41,3,44, 3,   0, 0, "9999", "DIF_MASKEDIT", "70"}
  D.cbxJustify  = {"DI_CHECKBOX", 9,4, 0, 0,   0, 0, 0, 0, M.MJustifyBorder}
  D.sep         = {"DI_TEXT",     5,5, 0, 0,   0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  D.cbxProcess  = {"DI_CHECKBOX", 5,6, 0, 0,   0, 0, 0, 0, M.MProcessLines}
  D.labExpress  = {"DI_TEXT",     9,7, 0, 0,   0, 0, 0, 0, M.MLineExpr}
  D.edtExpress  = {"DI_EDIT",    21,7,70, 7,   0, HIST_PROCESS, 0, "DIF_HISTORY", ""}
  D.sep         = {"DI_TEXT",     5,8, 0, 0,   0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  D.btnOk       = {"DI_BUTTON",   0,9, 0, 0,   0, 0, 0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MOk}
  D.btnCancel   = {"DI_BUTTON",   0,9, 0, 0,   0, 0, 0, "DIF_CENTERGROUP", M.MCancel}
  ----------------------------------------------------------------------------
  -- Handlers of dialog events --
  local function CheckGroup (hDlg, c1, ...)
    local enbl = c1:GetCheck(hDlg)
    for _, elem in ipairs {...} do elem:Enable(hDlg, enbl) end
  end

  local function CheckAll (hDlg)
    CheckGroup (hDlg, D.cbxReformat, D.labStart, D.edtColumn1, D.labEnd, D.edtColumn2, D.cbxJustify)
    CheckGroup (hDlg, D.cbxProcess, D.edtExpress, D.labExpress)
    if D.cbxReformat:GetCheck(hDlg) then far.SendDlgMessage(hDlg, "DM_SETFOCUS", D.edtColumn1.id)
    elseif D.cbxProcess:GetCheck(hDlg) then far.SendDlgMessage(hDlg, "DM_SETFOCUS", D.edtExpress.id)
    end
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      if D.cbxReformat:GetCheck(hDlg) then D.cbxProcess:SetCheck(hDlg,false) end
      CheckAll (hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1 == D.cbxReformat.id then
        if D.cbxReformat:GetCheck(hDlg) then D.cbxProcess:SetCheck(hDlg,false) end
        CheckAll (hDlg)
      elseif param1 == D.cbxProcess.id then
        if D.cbxProcess:GetCheck(hDlg) then D.cbxReformat:SetCheck(hDlg,false) end
        CheckAll (hDlg)
      end
    end
  end
  ----------------------------------------------------------------------------
  far2_dialog.LoadData(D, aData)
  local ret = far.Dialog (dialogGuid,-1,-1,76,12,"Wrap",D,0,DlgProc)
  if ret == D.btnOk.id then
    far2_dialog.SaveData(D, aData)
    return true
  end
end


local function ProcessBlock (aCode)
  local func, err = loadstring("L,N=... return " .. aCode)
  if func==nil then
    far.Message(err, "Error", nil, "w")
    return
  end
  local env = setmetatable({}, { __index=_G })
  setfenv(func,env)

  local bNotSelected
  local eInfo = editor.GetInfo()
  if not EditorHasSelection (eInfo) then
    assert (EditorSelectCurLine (eInfo))
    eInfo = editor.GetInfo()
    bNotSelected = true
  end

  local lnum, N = eInfo.BlockStartLine, 0
  while lnum <= eInfo.TotalLines do
    local line = editor.GetString(nil, lnum, 1)
    if not (line and line.SelStart >= 1 and line.SelEnd ~= 0) then
      break
    end
    N = N + 1
    local repl = func(line.StringText, N)
    if type(repl) == "string" then
      if repl == "" then
        editor.SetString(nil, nil, repl, line.StringEOL)
      else
        for s,eol in repl:gmatch("([^\r\n]*)(\r?\n?)") do
          if s=="" and eol=="" then break end
          editor.SetString(nil, lnum, s)
          if eol ~= "" then
            editor.SetPosition(nil, lnum, s:len()+1)
            editor.InsertString()
            lnum = lnum + 1
            eInfo.TotalLines = eInfo.TotalLines + 1
          end
        end
      end
      lnum = lnum + 1
    elseif not repl then
      editor.DeleteString()
      eInfo.TotalLines = eInfo.TotalLines - 1
    else
      lnum = lnum + 1
    end
  end

  editor.SetPosition (nil, eInfo)
  if bNotSelected then editor.Select(nil, "BTYPE_NONE") end
end


local function WrapWithDialog (aData)
  if not ExecuteWrapDialog(aData) then return end
  local code = aData.cbxProcess and aData.edtExpress or ""

  if aData.cbxReformat then
    local offs1 = assert(tonumber(aData.edtColumn1), "start column is not a number")
    local offs2 = assert(tonumber(aData.edtColumn2), "end column is not a number")
    assert(offs1 >= 1, "start column is less than 1")
    assert(offs2 >= offs1, "end column is less than start column")

    editor.UndoRedo(nil, "EUR_BEGIN")
    Wrap (offs1, offs2, aData.cbxJustify, 2.0)
    editor.UndoRedo(nil, "EUR_END")

  else
    editor.UndoRedo(nil, "EUR_BEGIN")
    ProcessBlock(code)
    editor.UndoRedo(nil, "EUR_END")
  end
end

local history = (...)[1]
WrapWithDialog (history)
