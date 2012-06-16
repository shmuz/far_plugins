--local regex = require "rex_pcre"

local F=far.Flags
local far2_dialog = require "far2.dialog"

local M -- message table for localization
local AppName

local function ReplaceDialog (histData)
  local Dlg = far2_dialog.NewDialog()
  Dlg.dbox        = {"DI_DOUBLEBOX", 3, 1, 72,11, 0, 0, 0, 0, M.MMultilineReplace}
  Dlg.lab         = {"DI_TEXT",      5, 2,  0, 0, 0, 0, 0, 0, M.MDlgSearchPat}
  Dlg.sSearchPat  = {"DI_EDIT",      5, 3, 70, 4, 0, "SearchText", 0, {DIF_HISTORY=1,DIF_USELASTHISTORY=1}, ""}
  Dlg.lab         = {"DI_TEXT",      5, 4,  0, 0, 0, 0, 0, 0, M.MDlgReplacePat}
  Dlg.sReplacePat = {"DI_EDIT",      5, 5, 70, 0, 0, "ReplaceText", 0, {DIF_HISTORY=1,DIF_USELASTHISTORY=1}, ""}

  Dlg.bCaseSens   = {"DI_CHECKBOX",  5, 7,  0, 0, 0, 0, 0, 0, M.MDlgCaseSens}
  Dlg.bRegExpr    = {"DI_CHECKBOX", 26, 7,  0, 0, 0, 0, 0, 0, M.MDlgRegExpr}
  Dlg.bFileAsLine = {"DI_CHECKBOX", 48, 7,  0, 0, 0, 0, 0, 0, M.MDlgFileAsLine}
  Dlg.bWholeWords = {"DI_CHECKBOX",  5, 8,  0, 0, 0, 0, 0, 0, M.MDlgWholeWords}
  Dlg.bExtended   = {"DI_CHECKBOX", 26, 8,  0, 0, 0, 0, 0, 0, M.MDlgExtended}
  Dlg.bMultiLine  = {"DI_CHECKBOX", 48, 8,  0, 0, 0, 0, 0, 0, M.MDlgMultiline}

  Dlg.btnOk       = {"DI_BUTTON",    0,10,  0, 0, 0, 0, 0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MOk}
  Dlg.btnCancel   = {"DI_BUTTON",    0,10,  0, 0, 0, 0, 0, F.DIF_CENTERGROUP, M.MCancel}

  local function CheckRegexChange (hDlg)
    local bRegex = Dlg.bRegExpr:GetCheck(hDlg)
    Dlg.bWholeWords :Enable(hDlg, not bRegex)
    Dlg.bExtended   :Enable(hDlg, bRegex)
    Dlg.bFileAsLine :Enable(hDlg, bRegex)
    Dlg.bMultiLine  :Enable(hDlg, bRegex)
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      CheckRegexChange(hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1==Dlg.bRegExpr.id then CheckRegexChange(hDlg) end
    end
  end

  local id = win.Uuid("87ed8b17-e2b2-47d0-896d-e2956f396f1a")
  far2_dialog.LoadData(Dlg, histData)
  local ret = far.Dialog(id,-1,-1,76,13,"MReplace",Dlg,0,DlgProc)
  far2_dialog.SaveData(Dlg, histData)
  return ret==Dlg.btnOk.id
end

local function TransformSearchPattern (data)
  local pat = data.sSearchPat
  if not data.bRegExpr then
    pat = pat:gsub("[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]", "\\%1")
    if data.bWholeWords then pat = "\\b"..pat.."\\b" end
  end
  return pat
end

local function TransformReplacePattern (data)
  if not data.bRegExpr then
    return data.sReplacePat
  end
  local subst = { ["\\"]="\\", ["%"]="%%", a="\a", e="\27", f="\f", n="\n", r="\r", t="\t" }
  local pat = regex.gsub(data.sReplacePat,
    [[ \\x([0-9A-Fa-f]{1,4}) | \\(.) | (\%) | \$([0-9A-Za-z]) ]],
    function(j,k,l,m)
      if j then
        j = unicode.utf8.char(tonumber(j,16))
        return j=="%" and "%%" or j
      end
      return k and (subst[k] or k) or l and "%%" or "%"..m
    end, nil, "x")
  return pat
end

local function TransformFlags (data)
  local flags = data.bCaseSens and "" or "i"
  if data.bRegExpr then
    if data.bMultiLine  then flags=flags.."m" end
    if data.bFileAsLine then flags=flags.."s" end
    if data.bExtended   then flags=flags.."x" end
  end
  return flags
end

local function EditorAction (op, data)
  local editorInfo = editor.GetInfo()
  local bSelection = editorInfo.BlockType~=F.BTYPE_NONE
  local SearchPat = TransformSearchPattern(data)
  local ReplacePat = TransformReplacePattern(data)
  local Flags = TransformFlags(data)
  regex.gsub("foo", SearchPat, ReplacePat, nil, Flags) -- test patterns, provoke exception

  local t={}
  local lineno=bSelection and editorInfo.BlockStartLine or 0
  local eol
  editor.SetPosition(nil, lineno, 0)
  while lineno < editorInfo.TotalLines do
    local line=editor.GetString(nil, lineno)
    if bSelection and (line.SelStart<0 or line.SelEnd==0) then
      if eol~="" then t[#t+1]="" end
      break
    end
    t[#t+1], eol = line.StringText, line.StringEOL
    lineno = lineno+1
  end
  editor.SetPosition(nil, bSelection and editorInfo.BlockStartLine or 0, 0)

  local result, nFound, nReps = regex.gsub(table.concat(t,"\n"), SearchPat, ReplacePat, nil, Flags)
  if nFound == 0 then
    return nFound, nReps
  end

  editor.UndoRedo(nil, F.EUR_BEGIN)
  for i=bSelection and editorInfo.BlockStartLine or 0,lineno-1 do
    editor.DeleteString()
  end
  lineno = bSelection and editorInfo.BlockStartLine or 0
  for line, eol in result:gmatch("([^\r\n]*)(\r?\n?)") do
    if eol ~= "" then
      editor.InsertString()
      editor.SetString(nil, lineno, line)
      lineno = lineno+1
    else
      if line == "" then break end
      local L = editor.GetString()
      editor.SetString(nil, nil, line .. L.StringText)
    end
  end
  editor.UndoRedo(nil, F.EUR_END)

  return nFound, nReps
end

local function Init (messageTable)
  M = messageTable
  AppName = M.MMultilineReplace
end

local function ReplaceWithDialog (histData)
  if ReplaceDialog(histData) then
    local ok, ret = pcall(EditorAction, "replace", histData)
    editor.Redraw()
    if ok then
      local msg = (ret==0) and M.MNotFound or ("%s%d"):format(M.MTotalReplaced, ret)
      far.Message(msg, AppName)
    else
      far.Message(ret, "Error", nil, "w")
    end
  end
end

return {
  Init = Init,
  EditorAction = EditorAction,
  ReplaceWithDialog = ReplaceWithDialog,
}
