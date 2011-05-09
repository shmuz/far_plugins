--[[
 Goal: evaluate Lua expression.
 Start: 2006-02-?? by Shmuel Zeigerman
--]]

local far2_dialog = require "far2.dialog"
local M = require "lf4ed_message"
local F = far.GetFlags()

local function ErrMsg (msg)
  far.Message(msg, M.MError, M.MOk, "w")
end

local function GetAllText()
  local ei = far.EditorGetInfo()
  if ei then
    local t = {}
    for n = 0, ei.TotalLines-1 do
      table.insert(t, far.EditorGetString(n, 2))
    end
    far.EditorSetPosition(ei)
    return table.concat(t, "\n")
  end
end

local function GetSelectedText()
  local ei = far.EditorGetInfo()
  if ei and ei.BlockType ~= F.BTYPE_NONE then
    local t = {}
    local n = ei.BlockStartLine
    while true do
      local s = far.EditorGetString(n, 1)
      if not s or s.SelStart == -1 then
        break
      end
      local sel = s.StringText:sub (s.SelStart+1, s.SelEnd)
      table.insert(t, sel)
      n = n + 1
    end
    far.EditorSetPosition(ei)
    return table.concat(t, "\n"), n-1
  end
end

local function CompileParams (s1, s2, s3, s4)
  local p1 = assert(loadstring("return "..s1, "Parameter #1"))
  local p2 = assert(loadstring("return "..s2, "Parameter #2"))
  local p3 = assert(loadstring("return "..s3, "Parameter #3"))
  local p4 = assert(loadstring("return "..s4, "Parameter #4"))
  return p1, p2, p3, p4
end

local function ParamsDialog (aData)
  local HIST_PARAM = "LuaFAR\\LuaScript\\Parameter"
  local D = far2_dialog.NewDialog()
  D._             = {"DI_DOUBLEBOX",3, 1, 52,14,0, 0, 0, 0, M.MScriptParams}
  D.label         = {"DI_TEXT",     5, 3,  0,0, 0, 0, 0, 0, "&1."}
  D.sParam1       = {"DI_EDIT",     8, 3, 49,0, 0, HIST_PARAM, "DIF_HISTORY",0,""}
  D.label         = {"DI_TEXT",     5, 5,  0,0, 0, 0, 0, 0, "&2."}
  D.sParam2       = {"DI_EDIT",     8, 5, 49,0, 0, HIST_PARAM, "DIF_HISTORY",0,""}
  D.label         = {"DI_TEXT",     5, 7,  0,0, 0, 0, 0, 0, "&3."}
  D.sParam3       = {"DI_EDIT",     8, 7, 49,0, 0, HIST_PARAM, "DIF_HISTORY",0,""}
  D.label         = {"DI_TEXT",     5, 9,  0,0, 0, 0, 0, 0, "&4."}
  D.sParam4       = {"DI_EDIT",     8, 9, 49,0, 0, HIST_PARAM, "DIF_HISTORY",0,""}
  D.bParamsEnable = {"DI_CHECKBOX", 5,11,  0,0, 0, 0, 0, 0, M.MScriptParamsEnable}
  D.sep           = {"DI_TEXT",     0,12,  0,0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1},0,""}
  D.btnRun        = {"DI_BUTTON",   0,13,  0,0, 0, 0, "DIF_CENTERGROUP", 1, M.MRunScript}
  D.btnStore      = {"DI_BUTTON",   0,13,  0,0, 0, 0, "DIF_CENTERGROUP", 0, M.MStoreParams}
  D.btnCancel     = {"DI_BUTTON",   0,13,  0,0, 0, 0, "DIF_CENTERGROUP", 0, M.MCancel}
  ------------------------------------------------------------------------------
  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_CLOSE then
      if param1 == D.btnStore.id or param1 == D.btnRun.id then
        local s1 = D.sParam1:GetText(hDlg)
        local s2 = D.sParam2:GetText(hDlg)
        local s3 = D.sParam3:GetText(hDlg)
        local s4 = D.sParam4:GetText(hDlg)
        local ok, msg = pcall(CompileParams, s1, s2, s3, s4)
        if not ok then ErrMsg(msg); return 0; end
      end
    end
  end
  far2_dialog.LoadData(D, aData)
  local ret = far.Dialog (-1,-1,56,16,"ScriptParams",D,0,DlgProc)
  ret = (ret==D.btnStore.id) and "store" or (ret==D.btnRun.id) and "run"
  if ret then
    far2_dialog.SaveData(D, aData)
  end
  return ret
end

-- WARNING:
--   don't change the string literals "selection" and "all text",
--   since far.OnError relies on them being exactly such.
local function LuaScript (data)
  local text, chunkname = GetSelectedText(), "selection"
  if not text then
    text, chunkname = GetAllText(), "all text"
    if text and text:sub(1,1)=="#" then text = "--"..text end
  end
  if text then
    local chunk, msg = loadstring(text, chunkname)
    if not chunk then error(msg,3) end
    if data.bParamsEnable then
      local p1,p2,p3,p4 = CompileParams(data.sParam1, data.sParam2,
                                        data.sParam3, data.sParam4)
      p1 = p1(); p2 = p2(); p3 = p3(); p4 = p4()
      return chunk (p1,p2,p3,p4)
    else
      return chunk()
    end
  end
end

local function ResultDialog (aHelpTopic, aData, result)
  local Title = (aHelpTopic=="LuaExpression") and M.MExpr or M.MBlockSum
  local D = far2_dialog.NewDialog()
  ------------------------------------------------------------------------------
  D._         = {"DI_DOUBLEBOX",3, 1,42,7,  0, 0, 0, 0, Title}
  D.lblResult = {"DI_TEXT",     5, 2, 0,0,  0, 0, 0, 0, M.MResult}
  D.edtResult = {"DI_EDIT",     0, 2,40,0,  0, 0, 0, 0, result, _noautoload=1}
  D.cbxInsert = {"DI_CHECKBOX", 5, 3, 0,0,  0, 0, 0, 0, M.MInsertText}
  D.cbxCopy   = {"DI_CHECKBOX", 5, 4, 0,0,  0, 0, 0, 0, M.MCopyToClipboard}
  D.sep       = {"DI_TEXT",     0, 5, 0,0,  0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.btnOk     = {"DI_BUTTON",   0, 6, 0,0,  0, 0, "DIF_CENTERGROUP", 1, M.MOk}
  D.btnCancel = {"DI_BUTTON",   0, 6, 0,0,  0, 0, "DIF_CENTERGROUP", 0, M.MCancel}
  D.edtResult.X1 = D.lblResult.X1 + D.lblResult.Data:len()
  ------------------------------------------------------------------------------
  far2_dialog.LoadData(D, aData)
  local ret = far.Dialog (-1,-1,46,9,aHelpTopic,D)
  far2_dialog.SaveData(D, aData)
  return (ret == D.btnOk.id)
end

-- NOTE: In order to obtain correct offsets, this function should use either
--       far.find, or unicode.utf8.cfind function.
local function BlockSum(history)
  local block = far.EditorGetSelection()
  if not block then ErrMsg(M.MNoTextSelected) return end

  local ei = assert(far.EditorGetInfo(), "EditorGetInfo failed")
  local sum = 0
  local x_start, x_dot
  local regex = far.regex([[ (\S[^\s;,:]*) ]], "x")
  for n = block.StartLine, block.EndLine do
    local s = far.EditorGetString (n, 1)
    local start, _, sel = regex:find( s.StringText:sub(s.SelStart+1, s.SelEnd) )
    if start then
      x_start = far.EditorRealToTab(n, s.SelStart + start)
      local num = tonumber(sel)
      if num then
        sum = sum + num
        local x = far.find(sel, "\\.")
        if x then x_dot = x_start + x - 1 end
      end
    end
  end
  if not ResultDialog("BlockSum", history, sum) then return end
  sum = history.edtResult
  if history.cbxCopy then far.CopyToClipboard(sum) end
  if history.cbxInsert then
    local y = block.EndLine -- position of the last line
    local s = far.EditorGetString(y) -- get last block line
    far.EditorSetPosition (y, s.StringText:len()) -- insert a new line
    far.EditorInsertString()                      -- +
    local prefix = "="
    if x_dot then
      local x = far.find(tostring(sum), "\\.")
      if x then x_start = x_dot - (x - 1) end
    end
    if x_start then
      x_start = x_start>#prefix and x_start-#prefix-1 or 0
    else
      x_start = (block.BlockType==F.BTYPE_COLUMN) and s.SelStart or 0
    end
    far.EditorSetPosition (y+1, x_start)
    far.EditorInsertText(prefix .. sum)
    far.EditorRedraw()
  else
    far.EditorSetPosition (ei) -- restore the position
  end
end

local function LuaExpr(history)
  local edInfo = far.EditorGetInfo()
  local text, numline = GetSelectedText()
  if not text then
    numline = edInfo.CurLine
    text = far.EditorGetString(numline, 2)
  end

  local func, msg = loadstring("return " .. text)
  if not func then
    ErrMsg(msg) return
  end

  local env = { math=math, _G=_G, far=far }
  setmetatable(env, { __index=math })
  setfenv(func, env)
  local ok, result = pcall(func)
  if not ok then
    ErrMsg(result) return
  end

  result = tostring(result)
  if not ResultDialog("LuaExpression", history, result) then
    return
  end

  result = history.edtResult
  if history.cbxInsert then
    local line = far.EditorGetString(numline)
    local pos = (edInfo.BlockType==F.BTYPE_NONE) and line.StringLength or line.SelEnd
    far.EditorSetPosition(numline, pos)
    far.EditorInsertText(" = " .. result .. " ; ")
    far.EditorRedraw()
  end
  if history.cbxCopy then
    far.CopyToClipboard(result)
  end
end

local funcs = {
  BlockSum     = BlockSum,
  LuaExpr      = LuaExpr,
  LuaScript    = function(aData) return LuaScript(aData) end, -- keep errorlevel==3
  ScriptParams = function(aData)
      if ParamsDialog(aData) == "run" then return LuaScript(aData) end
    end,
}

do
  local arg = ...
  return assert (funcs[arg[1]]) (unpack(arg, 2))
end

