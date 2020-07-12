-- edt_main.lua
-- luacheck: globals _Plugin

local Common     = require "lfs_common"
local M          = require "lfs_message"
local EditEngine = require "lfs_editengine"
local Editors    = require "lfs_editors"

local libDialog  = require "far2.dialog"
local libMessage = require "far2.message"

local F = far.Flags
local FormatInt = Common.FormatInt
local band, bor = bit64.band, bit64.bor

local function ErrorMsg (text, title, buttons, flags)
  far.Message (text, title or M.MError, buttons, flags or "w")
end

local function UnlockEditor (Title, EI)
  EI = EI or editor.GetInfo()
  if band(EI.CurState,F.ECSTATE_LOCKED) ~= 0 then
    if far.Message(M.MEditorLockedPrompt, Title, M.MBtnYesNo)==1 then
      if editor.SetParam(nil,"ESPT_LOCKMODE",false) then
        editor.Redraw()
        return true
      end
    end
    return false
  end
  return true
end
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local searchGuid  = win.Uuid("0b81c198-3e20-4339-a762-ffcbbc0c549c")
local replaceGuid = win.Uuid("fe62aeb9-e0a1-4ed3-8614-d146356f86ff")

local function EditorDialog (aData, aReplace, aScriptCall)
  local sTitle = aReplace and M.MTitleReplace or M.MTitleSearch
  local HIST_INITFUNC   = _Plugin.DialogHistoryPath .. "InitFunc"
  local HIST_FINALFUNC  = _Plugin.DialogHistoryPath .. "FinalFunc"
  local HIST_FILTERFUNC = _Plugin.DialogHistoryPath .. "FilterFunc"
  ------------------------------------------------------------------------------
  local BF = F.DIF_CENTERGROUP
  local Dlg = libDialog.NewDialog()
  local Frame = Common.CreateSRFrame(Dlg, aData, true, aScriptCall)
  Dlg.frame       = {"DI_DOUBLEBOX",    3,1, 72,17, 0, 0, 0, 0, sTitle}
  ------------------------------------------------------------------------------
  local Y = Frame:InsertInDialog(false, 2, aReplace and "replace" or "search")
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.lab         = {"DI_TEXT",        5,Y,   0, 0, 0, 0, 0, 0, M.MDlgScope}
  Dlg.rScopeGlobal= {"DI_RADIOBUTTON", 6,Y+1, 0, 0, 0, 0, 0, "DIF_GROUP",
                                              M.MDlgScopeGlobal, _noauto=true}
  Dlg.rScopeBlock = {"DI_RADIOBUTTON", 6,Y+2, 0, 0, 0, 0, 0, 0,
                                              M.MDlgScopeBlock, _noauto=true}
  Dlg.lab         = {"DI_TEXT",       26,Y,0, 0, 0, 0, 0, 0,    M.MDlgOrigin}
  Dlg.rOriginCursor={"DI_RADIOBUTTON",27,Y+1, 0, 0, 0, 0, 0, "DIF_GROUP",
                                              M.MDlgOrigCursor, _noauto=true}
  Dlg.rOriginScope= {"DI_RADIOBUTTON",27,Y+2, 0, 0, 0, 0, 0, 0,
                                              M.MDlgOrigScope, _noauto=true}
  Dlg.bWrapAround = {"DI_CHECKBOX",   50,Y,   0, 0, 0, 0, 0, "DIF_3STATE", M.MDlgWrapAround}
  Dlg.bSearchBack = {"DI_CHECKBOX",   50,Y+1, 0, 0, 0, 0, 0, 0, M.MDlgReverseSearch}
  Dlg.bHighlight  = {"DI_CHECKBOX",   50,Y+2, 0, 0, 0, 0, 0, 0, M.MDlgHighlightAll}
  ------------------------------------------------------------------------------
  Y = Y + 3
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.bAdvanced   = {"DI_CHECKBOX",    5,Y,  0, 0, 0, 0, 0, 0, M.MDlgAdvanced}
  Y = Y + 1
  Dlg.labFilterFunc={"DI_TEXT",        5,Y,  0, 0, 0, 0, 0, 0, M.MDlgFilterFunc}
  Y = Y + 1
  Dlg.sFilterFunc = {"DI_EDIT",        5,Y, 70, 4, 0, HIST_FILTERFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.labInitFunc = {"DI_TEXT",        5,Y,   0, 0, 0, 0, 0, 0, M.MDlgInitFunc}
  Dlg.sInitFunc   = {"DI_EDIT",        5,Y+1,36, 0, 0, HIST_INITFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  Dlg.labFinalFunc= {"DI_TEXT",       39,Y,   0, 0, 0, 0, 0, 0, M.MDlgFinalFunc}
  Dlg.sFinalFunc  = {"DI_EDIT",       39,Y+1,70, 6, 0, HIST_FINALFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  ------------------------------------------------------------------------------
  Y = Y + 2
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  ------------------------------------------------------------------------------
  local btnNum = 0
  local function NN (str) btnNum=btnNum+1 return "&"..btnNum..str end
  Y = Y + 1
  Dlg.btnOk       = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, 0, bor(BF, F.DIF_DEFAULTBUTTON), M.MOk}
  Dlg.btnPresets  = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, 0, bor(BF, F.DIF_BTNNOCLOSE), NN(M.MDlgBtnPresets)}
  Dlg.btnConfig   = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, 0, bor(BF, F.DIF_BTNNOCLOSE), NN(M.MDlgBtnConfig)}
  if not aReplace then
    Dlg.btnCount  = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, 0, BF, NN(M.MDlgBtnCount)}
    Y = Y + 1
    Dlg.btnShowAll= {"DI_BUTTON",      0,Y,   0, 0, 0, 0, 0, BF, NN(M.MDlgBtnShowAll)}
  end
  Dlg.btnCancel   = {"DI_BUTTON",      0,Y,   0, 0, 0, 0, 0, BF, M.MCancel}
  Dlg.frame.Y2 = Y+1
  ----------------------------------------------------------------------------
  local function DlgProc (hDlg, msg, param1, param2)
    if msg==F.DN_BTNCLICK and param1==Dlg.btnPresets.id then
      Frame:DoPresets(hDlg)
      hDlg:send(F.DM_SETFOCUS, Dlg.btnOk.id)
    elseif msg==F.DN_BTNCLICK and param1==Dlg.btnConfig.id then
      hDlg:send("DM_SHOWDIALOG", 0)
      Common.EditorConfigDialog()
      hDlg:send("DM_SHOWDIALOG", 1)
    elseif not Common.Check_F4_On_DI_EDIT(Dlg, hDlg, msg, param1, param2) then
      return Frame:DlgProc(hDlg, msg, param1, param2)
    end
  end
  ----------------------------------------------------------------------------
  Common.AssignHotKeys(Dlg)
  libDialog.LoadData(Dlg, aData)
  Frame:OnDataLoaded(aData)
  local Guid = aReplace and replaceGuid or searchGuid
  local ret = far.Dialog (Guid,-1,-1,76,Y+3,"OperInEditor",Dlg,0,DlgProc)
  if ret < 0 or ret == Dlg.btnCancel.id then return "cancel" end

  return ret==Dlg.btnOk.id and (aReplace and "replace" or "search") or
         ret==Dlg.btnCount.id and "count" or
         ret==Dlg.btnShowAll.id and "showall",
         Frame.close_params
end


local ValidOperations = {
  [ "config"       ] = true,
  [ "repeat"       ] = true,
  [ "repeat_rev"   ] = true,
  [ "replace"      ] = true,
  [ "search"       ] = true,
  [ "searchword"   ] = true,
  [ "searchword_rev" ] = true,
  [ "test:count"   ] = true,
  [ "test:replace" ] = true,
  [ "test:search"  ] = true,
  [ "test:showall" ] = true,
}


--[[-------------------------------------------------------------------------
  *  'aScriptCall' being true means we are called from a script rather than from
     the standard user interface.
  *  If it is true, then the search pattern in the dialog should be initialized
     strictly from aData.sSearchPat, otherwise it will depend on the global
     value 'config.rPickFrom'.
------------------------------------------------------------------------------]]
local function EditorAction (aOp, aData, aScriptCall)
  assert(ValidOperations[aOp], "invalid operation")

  if aOp == "config" then
    Common.EditorConfigDialog()
    return nil
  end

  local EInfo = editor.GetInfo()
  local State = Editors.GetState(EInfo.EditorID)
  local bReplace = aOp:find("replace") or (aOp:find("repeat") and (State.sLastOp == "replace"))
  if not aScriptCall and bReplace and not UnlockEditor(M.MTitleReplace) then
    return
  end

  local bFirstSearch, sOperation, tParams
  aData.sSearchPat = aData.sSearchPat or ""
  aData.sReplacePat = aData.sReplacePat or ""
  local bTest = aOp:find("^test:")

  if bTest then
    bFirstSearch = true
    bReplace = (aOp == "test:replace")
    sOperation = aOp:sub(6) -- skip "test:"
    tParams = assert(Common.ProcessDialogData (aData, bReplace, true))

  elseif aOp == "search" or aOp == "replace" then
    bFirstSearch = true
    bReplace = (aOp == "replace")
    sOperation, tParams = EditorDialog(aData, bReplace, aScriptCall)
    if sOperation == "cancel" then return nil end
    -- sOperation : either of "search", "count", "showall", "replace"

  elseif aOp == "repeat" or aOp == "repeat_rev" then
    bReplace = (State.sLastOp == "replace")
    local key = Common.GetDialogHistoryKey("SearchText")
    local searchtext = Common.GetDialogHistoryValue(key, -1)
    if searchtext == "" then searchtext = Common.GetDialogHistoryValue(key, -2) end
    if searchtext ~= aData.sSearchPat then
      bReplace = false
      aData.bSearchBack = false
      if searchtext then aData.sSearchPat = searchtext end
    end
    sOperation = bReplace and "replace" or "search"
    tParams = Common.ProcessDialogData (aData, bReplace, true)
    if not tParams then return nil end

  elseif aOp == "searchword" or aOp == "searchword_rev" then
    local searchtext = Common.GetWordUnderCursor(_Plugin.History:field("config").bSelectFound)
    if not searchtext then return end
    aData = {
      bAdvanced = false;
      bCaseSens = false;
      bRegExpr = false;
      bSearchBack = (aOp == "searchword_rev");
      bWholeWords = true;
      sOrigin = "cursor";
      sScope = "global";
      sSearchPat = searchtext;
    }
    bFirstSearch = true
    bReplace = false
    sOperation = "searchword"
    tParams = assert(Common.ProcessDialogData (aData, false, true))

  end

  State.sLastOp = bReplace and "replace" or "search"
  tParams.sScope = bFirstSearch and aData.sScope or "global"
  if aOp=="repeat_rev" then tParams.bSearchBack = not tParams.bSearchBack end
  ---------------------------------------------------------------------------

  local function Work()
    if aData.bAdvanced then tParams.InitFunc() end
    local nFound, nReps, sChoice, nElapsed = EditEngine.DoAction(
        sOperation,
        bFirstSearch,
        aScriptCall,
        _Plugin.Repeat,
        tParams.Regex,
        tParams.sScope=="block",
        tParams.sOrigin=="scope",
        tParams.bWrapAround,
        tParams.bSearchBack,
        tParams.FilterFunc,
        tParams.sSearchPat,
        tParams.ReplacePat,
        tParams.bConfirmReplace,
        tParams.bDelEmptyLine,
        tParams.bDelNonMatchLine,
        aData.fUserChoiceFunc)
    if aData.bAdvanced then tParams.FinalFunc() end
    ---------------------------------------------------------------------------
    local function GetTitle()
      if _Plugin.History:field("config").bShowSpentTime then
        return ("%s [ %s s ]"):format(M.MMenuTitle, Common.FormatTime(nElapsed))
      else
        return M.MMenuTitle
      end
    end
    if not bTest and sOperation ~= "searchword" and sChoice ~= "broken" and sChoice ~= "cancel" then
      if nFound == 0 and nReps == 0 then
        ErrorMsg (M.MNotFound .. aData.sSearchPat .. "\"", GetTitle())
      elseif sOperation == "count" then
        far.Message (M.MTotalFound .. FormatInt(nFound), GetTitle())
      elseif bReplace and (sChoice=="initial" or sChoice=="all") then
        libMessage.TableBox( {
          { M.MTotalFound,    FormatInt(nFound) },
          { M.MTotalReplaced, FormatInt(nReps) },
        },
        GetTitle(), nil, "T")
      end
    end
    return nFound, nReps, sChoice, nElapsed
  end

  local ok, nFound, nReps, sChoice, nElapsed = xpcall(Work, debug.traceback)
  if ok then
    editor.SetTitle(nil, "")
    if sChoice == "newsearch" then
      return EditorAction(aOp, aData, aScriptCall)
    else
      return nFound, nReps, sChoice, nElapsed
    end
  end
  ErrorMsg(nFound,nil,nil,"wl")
  editor.SetTitle(nil, "")
end


return {
  EditorAction = EditorAction,
  UnlockEditor = UnlockEditor,
}
