--[[
 Goal: sort lines.
 Start: 2008-10-17 by Shmuel Zeigerman
--]]

-- Depends on: FAR API
local sd = require "sortdialog"
local SortDialog = sd.SortDialog

local type, tonumber = type, tonumber
local tinsert = table.insert
local F = far.Flags
local M = require "lf4ed_message"
local band, bor, bxor, bnot = bit64.band, bit64.bor, bit64.bxor, bit64.bnot
local EditorSetPosition = editor.SetPosition
local EditorSetString = editor.SetString
local CompareString = win.CompareString

-- Depends on: FAR API
local function ErrMsg(msg, buttons)
  return far.Message(msg, M.MError, buttons, "w")
end

-- generic
local function TabLen(str, tabsize)
  local extra = 0
  for p in str:gmatch("()\t") do
    extra = extra + (tabsize - (p-1+extra) % tabsize) - 1
  end
  return #str + extra
end

-- Depends on: FAR API
local function IsColumnType()
  local editInfo = editor.GetInfo()
  return (editInfo.BlockType == F.BTYPE_COLUMN)
end

-- Depends on: FAR API
local function EditorHasSelection (editInfo)
  return editInfo.BlockType ~= 0 and editInfo.BlockStartLine >= 1
end

-- Depends on: FAR API
-- Iterator factory
local function EditorBlockLines ()
  local editInfo = editor.GetInfo()
  if not EditorHasSelection(editInfo) then return function() end; end
  local start_line = editInfo.BlockStartLine
  return function()
    local lineInfo = editor.GetString (nil, start_line, 1)
    if lineInfo and lineInfo.SelStart >= 1 and lineInfo.SelEnd ~= 0 then
      start_line = start_line + 1
      return lineInfo
    end
  end
end

-- Depends on: data names, namely, on the following strings:
--    StringText, SelStart, SelEnd
local function GetLines (columntype)
  local arr_index, arr_target, arr_compare = {},{},{}
  for line in EditorBlockLines() do
    tinsert(arr_index, #arr_index+1)
    tinsert(arr_target, line)
    local s = columntype and line.StringText:sub(line.SelStart, line.SelEnd)
      or line.StringText
    tinsert(arr_compare, s)
  end
  return arr_compare, arr_index, arr_target
end

-- Depends on: FAR API
local function PutLines(arr_compare, arr_index, arr_target, OnlySelection)
  local editInfo = editor.GetInfo()
  if band (editInfo.CurState, F.ECSTATE_LOCKED) ~= 0 then
    ErrMsg("The editor is locked"); return
  end
  local pstart = editInfo.BlockStartLine - 1
  local BlockSelStart, BlockSelEnd, BlockSelWidth
  if OnlySelection then
    EditorSetPosition(nil, editInfo.BlockStartLine)
    local line = editor.GetString(nil, nil)
    BlockSelStart = editor.RealToTab(nil, nil, line.SelStart)
    BlockSelEnd   = editor.RealToTab(nil, nil, line.SelEnd)
    BlockSelWidth = BlockSelEnd - BlockSelStart + 1
  end
  for i, v in ipairs(arr_index) do
    if i ~= v then
      local newtext, newEOL
      if OnlySelection then
        local TrgLine = arr_target[i]
        local oldtext = TrgLine.StringText
        local S = arr_compare[v]
        local S2 = S .. (" "):rep(BlockSelWidth - S:len())
        local TrgScrLen = TabLen(oldtext, editInfo.TabSize)
        if TrgScrLen < BlockSelStart then
          if S == "" then newtext = oldtext
          else newtext = oldtext .. (" "):rep(BlockSelStart-TrgScrLen-1) .. S
          end
        else
          newtext = oldtext:sub(1, TrgLine.SelStart-1)
          if TrgScrLen < BlockSelEnd then newtext = newtext .. S
          else newtext = newtext .. S2 .. oldtext:sub(TrgLine.SelEnd + 1)
          end
        end
        newEOL = TrgLine.StringEOL
      else
        newtext, newEOL = arr_target[v].StringText, arr_target[v].StringEOL
      end
      EditorSetPosition(nil, pstart + i)
      EditorSetString(nil, nil, newtext, newEOL)
    end
  end
end

local function Column (subj, colnum, colpat)
  for A in regex.gmatch(subj, colpat) do
    if colnum == 1 then return A end
    colnum = colnum - 1
  end
end

local template = [[
local _Column, _ColPat, L = ...
local _A
local N  = tonumber
local C  = function(n) return _Column(_A,n,_ColPat) end
local LC = function(n) return L(C(n)) end
local NC = function(n) return N(C(n)) end
return function(a, i) _A=a return %s end
]]

-- Depends on: data names, namely, on the following strings:
-- "expr", "func", "rev".
local function DoSort (arr_compare, arr_index, arr_dialog)
  local function cmp(i1, i2)
    local a, b = arr_compare[i1], arr_compare[i2]
    for _, data in ipairs(arr_dialog) do
      local v1, v2 = data.expr(a, i1), data.expr(b, i2)
      if v1 ~= v2 then
        if type(v1) == "string" then
          v1 = assert(data.func(v1,v2), "compare function failed")
          v2 = 0
        end
        if v1 > v2 then return data.rev end
        if v1 < v2 then return not data.rev end
      end
    end
    return i1 < i2 -- this makes sort stable
  end
  table.sort(arr_index, cmp)
end

-- give expressions read access to the global table
local meta = { __index=_G }

local function compile(expr, fieldname, env, colpat)
  local func = assert(loadstring(template:format(expr), fieldname))
  setfenv(func, env)
  return func(Column, colpat, far.LLowerBuf)
end

-- Depends on: win.wcscmp, win.CompareString
-- Depends on: data names, namely, on the following strings:
--    edtColPat
--    cbxFileName, edtFileName
--    cbxUse1, edtExpr1, cbxRev1
--    cbxUse2, edtExpr2, cbxRev2
--    cbxUse3, edtExpr3, cbxRev3
local function GetExpressions (aData)
  local env = setmetatable({}, meta)
  if aData.cbxFileName then
    local chunk = assert(loadfile(aData.edtFileName))
    setfenv(chunk, env)
    chunk()
  end
  local arr_dialog = {}
  for i = 1,3 do
    if aData["cbxUse"..i] then
      local case, expr, rev = aData["cbxCase"..i], aData["edtExpr"..i], aData["cbxRev"..i]
      local func
      if case == true then
        func = function(v1,v2) return CompareString(v1,v2,nil,"S") end
      elseif case == 2 then
        local flags, expr2 = expr:match("^:(.-):(.*)")
        if flags then expr = expr2 else flags = "" end
        if flags == "1" then
          func = win.wcscmp
        else
          func = function(v1,v2) return CompareString(v1,v2,nil,flags) end
        end
      else -- if case == false; default
        func = function(v1,v2) return CompareString(v1,v2,nil,"cS") end
      end
      tinsert(arr_dialog, {
        expr = compile(expr, "Expression "..i, env, aData.edtColPat),
        rev = rev or false,
        func = func})
    end
  end
  return arr_dialog
end

-- generic
local function SortWithRawData (aData)
  local columntype = IsColumnType()
  local arr_dialog = GetExpressions(aData)
  if #arr_dialog == 0 then
    return  -- no expressions available
  end
  local arr_compare, arr_index, arr_target = GetLines(columntype)
  if #arr_compare < 2 then
    return  -- nothing to sort
  end
  getfenv(arr_dialog[1].expr).I = #arr_index
  DoSort(arr_compare, arr_index, arr_dialog)
  -- put the sorted lines into the editor
  local OnlySelection = columntype and aData.cbxOnlySel
  editor.UndoRedo(nil, "EUR_BEGIN")
  PutLines(arr_compare, arr_index, arr_target, OnlySelection)
  editor.UndoRedo(nil, "EUR_END")
end

-- generic
local function SortWithDialog (aArg)
  local data = aArg[1]
  if SortDialog(data, IsColumnType()) then
    SortWithRawData(data)
  end
end

return {
  SortWithRawData = SortWithRawData,
  SortWithDialog = SortWithDialog,
}
