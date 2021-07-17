-- luacheck: globals _Plugin

local Common     = require "lfs_common"
local EditMain   = require "lfs_editmain"
local M          = require "lfs_message"

local libDialog  = require "far2.dialog"
local libMessage = require "far2.message"

local FormatInt = Common.FormatInt
local AppName = function() return M.MDlgMultilineReplace end

local F=far.Flags
local KEEP_DIALOG_OPEN = 0

local RegexLibs = {"far", "oniguruma", "pcre", "pcre2"}

local function ReplaceDialog (Data)
  local HIST_INITFUNC   = _Plugin.DialogHistoryPath .. "InitFunc"
  local HIST_FINALFUNC  = _Plugin.DialogHistoryPath .. "FinalFunc"
  local hstflags = bit64.bor(F.DIF_HISTORY, F.DIF_USELASTHISTORY, F.DIF_MANUALADDHISTORY)
  local guid = win.Uuid("87ed8b17-e2b2-47d0-896d-e2956f396f1a")
  local Dlg = libDialog.NewDialog()
  ------------------------------------------------------------------------------
  Dlg.dbox        = {"DI_DOUBLEBOX", 3, 1, 72,18, 0, 0, 0, 0, M.MDlgMultilineReplace}
  Dlg.lab         = {"DI_TEXT",      5, 2,  0, 0, 0, 0, 0, 0, M.MDlgSearchPat}
  Dlg.sSearchPat  = {"DI_EDIT",      5, 3, 70, 0, 0, "SearchText", 0, hstflags, ""}
  Dlg.lab         = {"DI_TEXT",      5, 4,  0, 0, 0, 0, 0, 0, M.MDlgReplacePat}
  Dlg.sReplacePat = {"DI_EDIT",      5, 5, 70, 0, 0, "ReplaceText", 0, hstflags, ""}
  Dlg.bRepIsFunc  = {"DI_CHECKBOX",  9, 6,  0, 0, 0, 0, 0, 0, M.MDlgRepIsFunc}
  Dlg.sep         = {"DI_TEXT",      5, 7,  0, 0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  ------------------------------------------------------------------------------
  local X2 = 39
  local X3 = X2 + M.MDlgRegexLib:gsub("&",""):len() + 1;
  local X4 = X3 + 12
  Dlg.bRegExpr    = {"DI_CHECKBOX",  5, 8,  0, 0, 0, 0, 0, 0, M.MDlgRegExpr}
  Dlg.lab         = {"DI_TEXT",     X2, 8,  0, 0, 0, 0, 0, 0, M.MDlgRegexLib}
  Dlg.cmbRegexLib = {"DI_COMBOBOX", X3, 8, X4, 0, {{Text="Far regex"},{Text="Oniguruma"},{Text="PCRE"},{Text="PCRE2"}},
                                                     0, 0, {DIF_DROPDOWNLIST=1}, "", _noauto=true}
  Dlg.bCaseSens   = {"DI_CHECKBOX",  5, 9,  0, 0, 0, 0, 0, 0, M.MDlgCaseSens}
  Dlg.bFileAsLine = {"DI_CHECKBOX", X2, 9,  0, 0, 0, 0, 0, 0, M.MDlgFileAsLine}
  Dlg.bWholeWords = {"DI_CHECKBOX",  5,10,  0, 0, 0, 0, 0, 0, M.MDlgWholeWords}
  Dlg.bMultiLine  = {"DI_CHECKBOX", X2,10,  0, 0, 0, 0, 0, 0, M.MDlgMultilineMode}
  Dlg.bExtended   = {"DI_CHECKBOX",  5,11,  0, 0, 0, 0, 0, 0, M.MDlgExtended}
  Dlg.sep         = {"DI_TEXT",      5,12,  0, 0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  ------------------------------------------------------------------------------
  Dlg.bAdvanced   = {"DI_CHECKBOX",  5,13,  0, 0, 0, 0, 0, 0, M.MDlgAdvanced}
  Dlg.labInitFunc = {"DI_TEXT",      5,14,  0, 0, 0, 0, 0, 0, M.MDlgInitFunc}
  Dlg.sInitFunc   = {"DI_EDIT",      5,15, 36, 0, 0, HIST_INITFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  Dlg.labFinalFunc= {"DI_TEXT",     X2,14,  0, 0, 0, 0, 0, 0, M.MDlgFinalFunc}
  Dlg.sFinalFunc  = {"DI_EDIT",     X2,15, 70, 0, 0, HIST_FINALFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  Dlg.sep         = {"DI_TEXT",      5,16,  0, 0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  ------------------------------------------------------------------------------
  Dlg.btnReplace  = {"DI_BUTTON",    0,17,  0, 0, 0, 0, 0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MDlgBtnReplace}
  Dlg.btnCount    = {"DI_BUTTON",    0,17,  0, 0, 0, 0, 0, F.DIF_CENTERGROUP, M.MDlgBtnCount2}
  Dlg.btnCancel   = {"DI_BUTTON",    0,17,  0, 0, 0, 0, 0, F.DIF_CENTERGROUP, M.MCancel}
  ------------------------------------------------------------------------------

  local function CheckRegexChange (hDlg)
    local bRegex = Dlg.bRegExpr:GetCheck(hDlg)
    Dlg.bWholeWords :Enable(hDlg, not bRegex)
    Dlg.bExtended   :Enable(hDlg, bRegex)
    Dlg.bFileAsLine :Enable(hDlg, bRegex)
    Dlg.bMultiLine  :Enable(hDlg, bRegex)
  end

  local function CheckAdvancedEnab (hDlg)
    local bEnab = Dlg.bAdvanced:GetCheck(hDlg)
    Dlg.labInitFunc   :Enable(hDlg, bEnab)
    Dlg.sInitFunc     :Enable(hDlg, bEnab)
    Dlg.labFinalFunc  :Enable(hDlg, bEnab)
    Dlg.sFinalFunc    :Enable(hDlg, bEnab)
  end


  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      CheckRegexChange(hDlg)
      CheckAdvancedEnab(hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1==Dlg.bRegExpr.id then CheckRegexChange(hDlg)
      elseif param1==Dlg.bAdvanced.id then CheckAdvancedEnab (hDlg)
      end
    elseif Common.Check_F4_On_DI_EDIT(Dlg, hDlg, msg, param1, param2) then
      -- processed
    elseif msg == F.DN_CLOSE then
      if param1==Dlg.btnReplace.id or param1==Dlg.btnCount.id then
        local tmpData = {}
        libDialog.SaveDataDyn(hDlg, Dlg, tmpData)
        tmpData.sRegexLib = RegexLibs[ Dlg.cmbRegexLib:GetListCurPos(hDlg) ]
        local ok, field = Common.ProcessDialogData(tmpData, true, true)
        if ok then
          Data.sRegexLib = tmpData.sRegexLib
          hDlg:send("DM_ADDHISTORY", Dlg.sSearchPat.id, tmpData.sSearchPat)
          hDlg:send("DM_ADDHISTORY", Dlg.sReplacePat.id, tmpData.sReplacePat)
        else
          if Dlg[field] then Common.GotoEditField(hDlg, Dlg[field].id) end
          return KEEP_DIALOG_OPEN
        end
      end
    end
  end

  Common.AssignHotKeys(Dlg)
  libDialog.LoadData(Dlg, Data)
  local items = Dlg.cmbRegexLib.ListItems
  items.SelectIndex = 1
  for i,v in ipairs(RegexLibs) do
    if Data.sRegexLib == v then items.SelectIndex = i; break; end
  end

  local ret = far.Dialog(guid,-1,-1,76,20,"MReplace",Dlg,0,DlgProc)
  ret = ret==Dlg.btnReplace.id and "replace" or ret==Dlg.btnCount.id and "count"
  if ret then
    libDialog.SaveData(Dlg, Data)
  end
  return ret
end

local function EditorAction (op, data)
  local editorInfo = editor.GetInfo()
  if not EditMain.UnlockEditor(M.MDlgMultilineReplace, editorInfo) then
    return false
  end

  local bSelection = editorInfo.BlockType~=F.BTYPE_NONE
  local tParams = Common.ProcessDialogData(data, op=="replace", true)
  if not tParams then
    far.Message("invalid input data"); return
  end

  local is_wide = tParams.Regex.ufindW and true
  local TT_EditorGetString = is_wide and editor.GetStringW  or editor.GetString
  local TT_EditorSetString = is_wide and editor.SetStringW  or editor.SetString
  local TT_empty           = is_wide and win.Utf8ToUtf16("")  or ""
  local TT_newline         = is_wide and win.Utf8ToUtf16("\n")  or "\n"
  local TT_gmatch          = is_wide and regex.gmatchW or regex.gmatch
  local TT_Gsub            = is_wide and Common.GsubW or Common.Gsub

  local fReplace = function() end
  if op == "replace" then
    local nMatch,nReps = 0,0
    local ff = Common.GetReplaceFunction(tParams.ReplacePat, is_wide)
    fReplace = function (collect)
      nMatch = nMatch + 1
      local r1,r2 = ff(collect,nMatch,nReps)
      if r1 then nReps = nReps+1 end
      return r1,r2
    end
  end

  if data.bAdvanced then tParams.InitFunc() end
  local t = {}
  local lineno=bSelection and editorInfo.BlockStartLine or 1
  local eol
  local break_counter = 0

  -- without break_counter, it slows down the operation by 10...20 %
  local function CheckBreak (force)
    break_counter = break_counter + 1
    if force or break_counter == 10 then
      break_counter = 0
      return win.ExtractKey()=="ESCAPE" and 1==far.Message(M.MUsrBrkPrompt, AppName(), M.MBtnYesNo, "w")
    end
  end

  far.Message(M.MOperationInProgress, AppName(), "")

  -- collect the source editor lines into an array
  while lineno <= editorInfo.TotalLines do
    if CheckBreak() then
      return 0, 0, "broken"
    end
    local line = TT_EditorGetString(nil, lineno)
    if bSelection and (line.SelStart<=0 or line.SelEnd==0) then
      if eol ~= TT_empty then t[#t+1] = TT_empty end
      break
    end
    t[#t+1], eol = line.StringText, line.StringEOL
    lineno = lineno + 1
  end

  -- get the resulting text as a string
  local result, nFound, nReps = TT_Gsub(table.concat(t,TT_newline), tParams.Regex, fReplace)
  if nReps == 0 or op == "count" then
    if data.bAdvanced then tParams.FinalFunc() end
    return nFound, 0
  end

  if CheckBreak(true) then return nFound, 0, "broken" end

  -- OPERATION CHANGING EDITOR CONTENTS --
  editor.UndoRedo(nil, F.EUR_BEGIN)

  -- delete the source editor lines
  editor.SetPosition(nil, bSelection and editorInfo.BlockStartLine or 1, 1)
  for i=bSelection and editorInfo.BlockStartLine or 1,lineno-1 do
    if CheckBreak() then
      editor.UndoRedo(nil, F.EUR_END)
      return nFound, 0, "broken"
    end
    editor.DeleteString()
  end

  -- insert the target editor lines
  lineno = bSelection and editorInfo.BlockStartLine or 1
  for line, eol in TT_gmatch(result, "([^\r\n]*)(\r?\n?)") do
    if CheckBreak() then
      editor.UndoRedo(nil, F.EUR_END)
      return nFound, 0, "broken"
    end
    if eol ~= TT_empty then
      editor.InsertString()
      TT_EditorSetString(nil, lineno, line)
      lineno = lineno+1
    else
      if line == TT_empty then break end
      local L = TT_EditorGetString()
      TT_EditorSetString(nil, nil, line .. L.StringText)
    end
  end

  editor.UndoRedo(nil, F.EUR_END)
  editor.SetPosition(nil, editorInfo)

  if data.bAdvanced then tParams.FinalFunc() end
  return nFound, nReps
end

local function ReplaceWithDialog (data, collect)
  if not EditMain.UnlockEditor(M.MDlgMultilineReplace) then
    return false
  end
  local op = ReplaceDialog(data)
  if op then
    local ok, nFound, nReps, sChoice = pcall(EditorAction, op, data)
    editor.Redraw()
    if ok then
      if sChoice ~= "broken" then
        if nFound == 0 then
          far.Message(M.MNotFound..data.sSearchPat..'"', AppName(), nil, "w")
        elseif op == "replace" then
          libMessage.TableBox(
            {{M.MTotalFound, FormatInt(nFound)}, {M.MTotalReplaced, FormatInt(nReps)}},
            AppName(), nil, "T")
        elseif op == "count" then
          far.Message(("%s%d"):format(M.MTotalFound, nFound), AppName(), nil, "l")
        end
      end
    else
      far.Message(nFound, "Error", nil, "w")
    end
    if collect then collectgarbage("collect") end
    return true
  end
  return false
end

return {
  EditorAction = EditorAction,
  ReplaceWithDialog = ReplaceWithDialog,
}
