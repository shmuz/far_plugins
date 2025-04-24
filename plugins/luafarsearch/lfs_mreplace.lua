-- luacheck: globals _Plugin

local Common     = require "lfs_common"
local EditMain   = require "lfs_editmain"
local M          = require "lfs_message"

local sd         = require "far2.simpledialog"
local libMessage = require "far2.message"

local FormatInt = Common.FormatInt
local AppName = function() return M.MDlgMultilineReplace end

local F=far.Flags
local KEEP_DIALOG_OPEN = 0

local RegexLibs = {"far", "oniguruma", "pcre", "pcre2"}

local function ReplaceDialog (Data)
  local HIST_INITFUNC   = _Plugin.DialogHistoryPath .. "InitFunc"
  local HIST_FINALFUNC  = _Plugin.DialogHistoryPath .. "FinalFunc"

  local WID = 38
  local X2 = WID + 1
  local X3 = X2 + M.MDlgRegexLib:gsub("&",""):len() + 1;
  local X4 = X3 + 12

  local Items = {
    guid = "87ED8B17-E2B2-47D0-896D-E2956F396F1A";
    help = "MReplace";
    width = 2*WID;
    { tp="dbox";  text=M.MDlgMultilineReplace; },
    { tp="text";  text=M.MDlgSearchPat; },
    { tp="edit";  hist="SearchText";    name="sSearchPat";  uselasthistory=1; manualaddhistory=1; },
    { tp="text";  text=M.MDlgReplacePat; },
    { tp="edit";  hist="ReplaceText";   name="sReplacePat"; uselasthistory=1; manualaddhistory=1; },
    { tp="chbox"; text=M.MDlgRepIsFunc; name="bRepIsFunc";  x1=9; },
    { tp="sep"; },
    ------------------------------------------------------------------------------
    { tp="chbox"; text=M.MDlgRegExpr; name="bRegExpr"; },
    { tp="text";  text=M.MDlgRegexLib; x1=X2; y1=""; },
    { tp="combobox"; x1=X3; x2=X4; y1="";   name="cmbRegexLib"; dropdown=1; noload=1;
        list={{Text="Far regex"},{Text="Oniguruma"},{Text="PCRE"},{Text="PCRE2"}}; },
    { tp="chbox"; text=M.MDlgCaseSens;      name="bCaseSens";                  },
    { tp="chbox"; text=M.MDlgFileAsLine;    name="bFileAsLine"; x1=X2; y1="";  },
    { tp="chbox"; text=M.MDlgWholeWords;    name="bWholeWords";                },
    { tp="chbox"; text=M.MDlgMultilineMode; name="bMultiLine";  x1=X2; y1="";  },
    { tp="chbox"; text=M.MDlgExtended;      name="bExtended";                  },
    { tp="sep"; },
    ------------------------------------------------------------------------------
    { tp="chbox"; text=M.MDlgAdvanced;  name="bAdvanced";                      },
    { tp="text";  text=M.MDlgInitFunc;  name="labInitFunc";                    },
    { tp="edit";  hist=HIST_INITFUNC;   name="sInitFunc"; x2=WID-2; ext="lua"; },
    { tp="text";  text=M.MDlgFinalFunc; name="labFinalFunc"; x1=X2; ystep=-1;  },
    { tp="edit";  hist=HIST_FINALFUNC;  name="sFinalFunc";   x1=X2; ext="lua"; },
    { tp="sep"; },
    ------------------------------------------------------------------------------
    { tp="butt"; centergroup=1; default=1; name="btnReplace"; text=M.MDlgBtnReplace; },
    { tp="butt"; centergroup=1;            name="btnCount";   text=M.MDlgBtnCount2;  },
    { tp="butt"; centergroup=1;  cancel=1; nohilite=1;        text=M.MCancel;        },
  }
  local dlg = sd.New(Items)
  local Pos,Elem = dlg:Indexes()

  local function CheckRegexChange (hDlg)
    local bRegex = hDlg:send("DM_GETCHECK", Pos.bRegExpr)
    hDlg:send("DM_ENABLE", Pos.bWholeWords, bRegex==0 and 1 or 0)
    hDlg:send("DM_ENABLE", Pos.bExtended,   bRegex)
    hDlg:send("DM_ENABLE", Pos.bFileAsLine, bRegex)
    hDlg:send("DM_ENABLE", Pos.bMultiLine,  bRegex)
  end

  local function CheckAdvancedEnab (hDlg)
    local bEnab = hDlg:send("DM_GETCHECK", Pos.bAdvanced)
    hDlg:send("DM_ENABLE", Pos.labInitFunc,  bEnab)
    hDlg:send("DM_ENABLE", Pos.sInitFunc,    bEnab)
    hDlg:send("DM_ENABLE", Pos.labFinalFunc, bEnab)
    hDlg:send("DM_ENABLE", Pos.sFinalFunc,   bEnab)
  end

  local closeaction = function(hDlg, param1, tOut)
    local tmpData = {}
    dlg:SaveData(tOut, tmpData)
    tmpData.sRegexLib = RegexLibs[tOut.cmbRegexLib]
    if Common.ProcessDialogData(tmpData, true, true) then
      Data.sRegexLib = tmpData.sRegexLib
      hDlg:send("DM_ADDHISTORY", Pos.sSearchPat, tmpData.sSearchPat)
      hDlg:send("DM_ADDHISTORY", Pos.sReplacePat, tmpData.sReplacePat)
    else
      return KEEP_DIALOG_OPEN
    end
  end

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      CheckRegexChange(hDlg)
      CheckAdvancedEnab(hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1==Pos.bRegExpr then
        CheckRegexChange(hDlg)
      elseif param1==Pos.bAdvanced then
        CheckAdvancedEnab(hDlg)
      end
    elseif msg == "EVENT_KEY" and param2 == "F4" then
      if param1 == Pos.sReplacePat and hDlg:send("DM_GETCHECK", Pos.bRepIsFunc) == 1 then
        local txt = sd.OpenInEditor(hDlg:send("DM_GETTEXT", Pos.sReplacePat), "lua")
        if txt then hDlg:send("DM_SETTEXT", Pos.sReplacePat, txt) end
        return true
      end
    elseif msg == F.DN_CLOSE then
      return closeaction(hDlg, param1, param2)
    end
  end

  dlg:AssignHotKeys()
  dlg:LoadData(Data)
  local list = Elem.cmbRegexLib.list
  list.SelectIndex = 1
  for i,v in ipairs(RegexLibs) do
    if Data.sRegexLib == v then list.SelectIndex = i; break; end
  end

  local tOut, nPos = dlg:Run()
  if tOut then
    dlg:SaveData(tOut, Data)
    return nPos==Pos.btnReplace and "replace" or nPos==Pos.btnCount and "count"
  end
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

  local sFileName = editor.GetFileName()

  local fReplace = function() end
  if op == "replace" then
    local nMatch,nReps = 0,0
    local ff = Common.GetReplaceFunction(tParams.ReplacePat, is_wide, tParams.bNgroupIsWide)
    fReplace = function (collect)
      nMatch = nMatch + 1
      local r1,r2 = ff(collect,nMatch,nReps,nil,sFileName)
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
  for _ = bSelection and editorInfo.BlockStartLine or 1, lineno-1 do
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
  editor.Select(nil, F.BTYPE_NONE) -- prevent leaving an empty selection
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
