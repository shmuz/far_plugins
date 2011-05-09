--[[
 Goal: wrap long lines without breaking words.
--]]

local far2_dialog = require "far2.dialog"

local M = require "lf4ed_message"
local F = far.GetFlags()
local insert, concat = table.insert, table.concat


-- iterator factory
local function EditorBlock (start_line)
  start_line = start_line or far.EditorGetInfo().BlockStartLine
  return function()
    local lineInfo = far.EditorGetString (start_line, 1)
    if lineInfo and lineInfo.SelStart >= 0 and lineInfo.SelEnd ~= 0 then
      start_line = start_line + 1
      return lineInfo
    end
  end
end


local function EditorHasSelection (editInfo)
  return editInfo.BlockType ~= 0 and editInfo.BlockStartLine >= 0
end


local function EditorSelectCurLine (editInfo)
  return far.EditorSelect ("BTYPE_STREAM", editInfo.CurLine, 0, -1, 1)
end


local function Incr (input, first, last)
  for k = #input, 1, -1 do
    if input[k] == last then
      input[k] = first
    else
      input[k] = string.char (string.byte(input[k]) + 1)
      return
    end
  end
  insert (input, 1, first)
end


-- Prefix can be made smart:
--     "S:12"     --  12 spaces
--     "L:>> "    --  prefix ">> "
--     "N:5."     --  automatic numbering, beginning from "5."
--     "N:5)"     --  automatic numbering, beginning from "5)"
--     "N:c"      --  automatic numbering, beginning from "c"
--     "N:C."     --  automatic numbering, beginning from "C."
--
local function GetPrefix (aCode)
  local op = aCode:sub(1,2):upper()
  local param = aCode:sub(3):gsub ("%:$", "")
  if op == "S:" then
    local n = assert (tonumber (param), "Prefix parameter must be a number")
    assert (n <= 1000, "Prefix length is limited at 1000")
    return string.rep (" ", n)

  elseif op == "L:" then
    return param

  elseif op == "N:" then
    local init, places, delim = param:match ("^(%w+)%,?(%d*)%,?(.*)")
    if not init then return end
    if places == "" then places = 0 end
    if tonumber(init) then
      init = tonumber(init)
      return function()
        local cur_init = tostring(init)
        init = init + 1
        return string.rep(" ", places - #cur_init) .. cur_init .. delim
      end
    else
      local first, last
      if init:find ("^[a-z]+$") then first,last = "a","z"
      elseif init:find ("^[A-Z]+$") then first,last = "A","Z"
      else error("Prefix Lines: invalid starting number")
      end
      local t = {}
      for k=1,#init do t[k] = init:sub(k,k) end
      init = t
      return function()
        local cur_init = concat(init)
        Incr(init, first, last)
        return string.rep(" ", places - #cur_init) .. cur_init .. delim
      end
    end

  end
end


local function Wrap (aColumn1, aColumn2, aPrefix, aJustify, aFactor)
  local editInfo = far.EditorGetInfo()
  if not EditorHasSelection (editInfo) then
    if EditorSelectCurLine (editInfo) then
      editInfo = far.EditorGetInfo()
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

  far.EditorDeleteBlock()

  local aMaxLineLen = aColumn2 - aColumn1 + 1
  local indent = (" "):rep(aColumn1 - 1)
  local lines_out = {} -- array for output lines

  -- Compile the next output line and store it.
  local function make_line (from, to, len, words)
    local prefix = type(aPrefix) == "string" and aPrefix or aPrefix()
    local extra = aMaxLineLen - len
    if aJustify and (aFactor * (to - from) >= extra) then
      for i = from, to - 1 do
        local sp = math.floor ((extra / (to - i)) + 0.5)
        words[i] = words[i] .. string.rep (" ", sp+1)
        extra = extra - sp
      end
      insert (lines_out, indent .. prefix .. concat (words, "", from, to))
    else
      insert (lines_out, indent .. prefix .. concat (words, " ", from, to))
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
  local Pos = { CurLine = editInfo.BlockStartLine, CurPos = 0 }
  far.EditorSetPosition (Pos)
  for i = #lines_out, 1, -1 do
    far.EditorInsertString()
    far.EditorSetPosition (Pos)
    far.EditorSetString(-1, lines_out[i])
  end
end


local function PrefixBlock (aPrefix)
  local bNotSelected
  local editInfo = far.EditorGetInfo()
  if not EditorHasSelection (editInfo) then
    assert (EditorSelectCurLine (editInfo))
    editInfo = far.EditorGetInfo()
    bNotSelected = true
  end

  if type(aPrefix) == "string" then
    local p = aPrefix
    aPrefix = function() return p end
  end

  for line in EditorBlock (editInfo.BlockStartLine) do
    far.EditorSetString(-1, aPrefix() .. line.StringText)
  end

  far.EditorSetPosition (editInfo)
  if bNotSelected then far.EditorSelect("BTYPE_NONE") end
end


-- {6d5c7ec2-8c2f-413c-81e6-0cc8ffc0799a}
local dialogGuid = "\194\126\092\109\047\140\060\065\129\230\012\200\255\192\121\154"

local function ExecuteWrapDialog (aData)
  local HIST_PREFIX = "LuaFAR\\Reformat\\Prefix"
  local D = far2_dialog.NewDialog()
  D._           = {"DI_DOUBLEBOX",3,1,72,10,0, 0, 0, 0, M.MReformatBlock}
  D.cbxReformat = {"DI_CHECKBOX", 5,2,0,0,  0, 1, 0, 0, M.MReformatBlock2}
  D.labStart    = {"DI_TEXT",     9,3,0,0,  0, 0, 0, 0, M.MStartColumn}
  D.edtColumn1  = {"DI_FIXEDIT", 22,3,25,4, 0, 0, 0, 0, "1"}
  D.labEnd      = {"DI_TEXT",    29,3,0,0,  0, 0, 0, 0, M.MEndColumn}
  D.edtColumn2  = {"DI_FIXEDIT", 41,3,44,4, 0, 0, 0, 0, "70"}
  D.cbxJustify  = {"DI_CHECKBOX", 9,4,0,0,  0, 0, 0, 0, M.MJustifyBorder}
  D.sep         = {"DI_TEXT",     5,5,0,0,  0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.cbxPrefix   = {"DI_CHECKBOX", 5,6,0,0,  0, 0, 0, 0, M.MPrefixLines}
  D.edtPrefix   = {"DI_EDIT",    17,7,70,6, 0, HIST_PREFIX, "DIF_HISTORY", 0, "S:4"}
  D.labCommand  = {"DI_TEXT",     9,7,0,0,  0, 0, 0, 0, M.MCommand}
  D.sep         = {"DI_TEXT",     5,8,0,0,  0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.btnOk       = {"DI_BUTTON",   0,9,0,0,  0, 0, "DIF_CENTERGROUP", 1, M.MOk}
  D.btnCancel   = {"DI_BUTTON",   0,9,0,0,  0, 0, "DIF_CENTERGROUP", 0, M.MCancel}
  ----------------------------------------------------------------------------
  -- Handlers of dialog events --
  local function Check (hDlg, c1, ...)
    local enbl = c1:GetCheck(hDlg)
    for _, elem in ipairs {...} do elem:Enable(hDlg, enbl) end
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      Check (hDlg, D.cbxReformat, D.labStart, D.edtColumn1, D.labEnd, D.edtColumn2, D.cbxJustify)
      Check (hDlg, D.cbxPrefix, D.edtPrefix, D.labCommand)
    elseif msg == F.DN_BTNCLICK then
      if param1 == D.cbxReformat.id then Check (hDlg, D.cbxReformat, D.labStart, D.edtColumn1, D.labEnd, D.edtColumn2, D.cbxJustify)
      elseif param1 == D.cbxPrefix.id then Check (hDlg, D.cbxPrefix, D.edtPrefix, D.labCommand)
      end
    elseif msg == F.DN_GETDIALOGINFO then
      return dialogGuid
    end
  end
  ----------------------------------------------------------------------------
  far2_dialog.LoadData(D, aData)
  local ret = far.Dialog (-1,-1,76,12,"Wrap",D,0,DlgProc)
  if ret == D.btnOk.id then
    far2_dialog.SaveData(D, aData)
    return true
  end
end


local function WrapWithDialog (aData)
  if not ExecuteWrapDialog(aData) then return end
  local prefix = aData.cbxPrefix and aData.edtPrefix and GetPrefix(aData.edtPrefix) or ""

  if aData.cbxReformat then
    local offs1 = assert(tonumber(aData.edtColumn1), "start column is not a number")
    local offs2 = assert(tonumber(aData.edtColumn2), "end column is not a number")
    assert(offs1 >= 1, "start column is less than 1")
    assert(offs2 >= offs1, "end column is less than start column")

    far.EditorUndoRedo("EUR_BEGIN")
    Wrap (offs1, offs2, prefix, aData.cbxJustify, 2.0)
    far.EditorUndoRedo("EUR_END")

  elseif prefix ~= "" then
    far.EditorUndoRedo("EUR_BEGIN")
    PrefixBlock(prefix)
    far.EditorUndoRedo("EUR_END")
  end
end

local history = (...)[1]
WrapWithDialog (history)
