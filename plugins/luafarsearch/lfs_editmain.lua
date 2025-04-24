-- lfs_editmain.lua
-- luacheck: globals _Plugin

local Common     = require "lfs_common"
local M          = require "lfs_message"
local EditEngine = require "lfs_editengine"
local Editors    = require "lfs_editors"

local sd         = require "far2.simpledialog"
local libMessage = require "far2.message"

local F = far.Flags
local FormatInt = Common.FormatInt
local band = bit64.band

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
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local searchGuid  = "0B81C198-3E20-4339-A762-FFCBBC0C549C"
local replaceGuid = "FE62AEB9-E0A1-4ED3-8614-D146356F86FF"

local function EditorDialog (aData, aReplace, aScriptCall)
  local insert = table.insert
  local sTitle = aReplace and M.MTitleReplace or M.MTitleSearch
  local HIST_INITFUNC   = _Plugin.DialogHistoryPath .. "InitFunc"
  local HIST_FINALFUNC  = _Plugin.DialogHistoryPath .. "FinalFunc"
  local HIST_FILTERFUNC = _Plugin.DialogHistoryPath .. "FilterFunc"
  ------------------------------------------------------------------------------
  local Items = {
    width = 76;
    guid = aReplace and replaceGuid or searchGuid;
    help = "OperInEditor";
    { tp="dbox"; text=sTitle; },
  }
  local Frame = Common.CreateSRFrame(Items, aData, true, aScriptCall)
  ------------------------------------------------------------------------------
  Frame:InsertInDialog(false, aReplace and "replace" or "search")
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="text";  text=M.MDlgScope; })
  insert(Items, { tp="rbutt"; name="rScopeGlobal";  text=M.MDlgScopeGlobal; x1=6; group=1; noload=1; })
  insert(Items, { tp="rbutt"; name="rScopeBlock";   text=M.MDlgScopeBlock;  x1=6; noload=1; })
  insert(Items, { tp="text";                        text=M.MDlgOrigin; ystep=-2; x1=26; })
  insert(Items, { tp="rbutt"; name="rOriginCursor"; text=M.MDlgOrigCursor; x1=27; group=1; noload=1; })
  insert(Items, { tp="rbutt"; name="rOriginScope";  text=M.MDlgOrigScope;  x1=""; noload=1; })
  insert(Items, { tp="chbox"; name="bWrapAround";   text=M.MDlgWrapAround; ystep=-2; x1=50; })
  insert(Items, { tp="chbox"; name="bSearchBack";   text=M.MDlgReverseSearch;        x1=""; })
  insert(Items, { tp="chbox"; name="bHighlight";    text=M.MDlgHighlightAll;         x1=""; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bAdvanced";            text=M.MDlgAdvanced; })
  insert(Items, { tp="text";  name="labFilterFunc"; x1=39; text=M.MDlgFilterFunc; y1=""; })
  insert(Items, { tp="edit";  name="sFilterFunc";   x1=""; hist=HIST_FILTERFUNC; ext="lua"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="text";  name="labInitFunc";  text=M.MDlgInitFunc; })
  insert(Items, { tp="edit";  name="sInitFunc";    x2=36; hist=HIST_INITFUNC; ext="lua"; })
  insert(Items, { tp="text";  name="labFinalFunc"; x1=39; text=M.MDlgFinalFunc; ystep=-1; })
  insert(Items, { tp="edit";  name="sFinalFunc";   x1=""; hist=HIST_FINALFUNC; ext="lua"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="butt"; name="btnOk";         centergroup=1; text=M.MOk; default=1; nohilite=1; })
  insert(Items, { tp="butt"; name="btnPresets";    centergroup=1; text=M.MDlgBtnPresets; btnnoclose=1; })
  insert(Items, { tp="butt"; name="btnConfig";     centergroup=1; text=M.MDlgBtnConfig;  btnnoclose=1; })
  if not aReplace then
    insert(Items, { tp="butt"; name="btnCount";    centergroup=1; text=M.MDlgBtnCount; })
    insert(Items, { tp="butt"; name="btnShowAll";  centergroup=1; text=M.MDlgBtnShowAll; ystep=1; })
  end
  insert(Items, { tp="butt"; name="btnCancel";     centergroup=1; text=M.MCancel; cancel=1; nohilite=1; })
  ----------------------------------------------------------------------------
  local dlg = sd.New(Items)
  local Pos,Elem = dlg:Indexes()
  Frame:SetDialogObject(dlg,Pos,Elem)

  function Items.proc (hDlg, msg, param1, param2)
    if msg==F.DN_BTNCLICK then
      if param1==Pos.btnPresets then
        Frame:DoPresets(hDlg)
        hDlg:send("DM_SETFOCUS", Pos.btnOk)
        return true
      elseif param1==Pos.btnConfig then
        hDlg:send("DM_SHOWDIALOG", 0)
        Common.EditorConfigDialog()
        hDlg:send("DM_SHOWDIALOG", 1)
        return true
      end
    end
    return Frame:DlgProc(hDlg, msg, param1, param2)
  end
  ----------------------------------------------------------------------------
  dlg:AssignHotKeys()
  dlg:LoadData(aData)
  Frame:OnDataLoaded(aData)
  local out, pos = dlg:Run()
  if not out then return "cancel" end
  return pos==Pos.btnOk      and (aReplace and "replace" or "search") or
         pos==Pos.btnCount   and "count"  or
         pos==Pos.btnShowAll and "showall",
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
    local searchtext = _Plugin.sSearchWord or Common.GetDialogHistory("SearchText")
    if searchtext ~= aData.sSearchPat then
      bReplace = false
      aData.bSearchBack = false
      if searchtext then aData.sSearchPat = searchtext end
    end
    sOperation = bReplace and "replace" or "search"
    tParams = Common.ProcessDialogData (aData, bReplace, true)
    if not tParams then return nil end

  elseif aOp == "searchword" or aOp == "searchword_rev" then
    local word = Common.GetWordUnderCursor(_Plugin.HField("config").bSelectFound)
    if not word then return end
    _Plugin.sSearchWord = word -- it may be used in further operations
    aData = {
      bAdvanced = false;
      bCaseSens = false;
      bRegExpr = false;
      bSearchBack = (aOp == "searchword_rev");
      bWholeWords = true;
      sOrigin = "cursor";
      sScope = "global";
      sSearchPat = word;
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
        tParams,
        aData.fUserChoiceFunc)
    if aData.bAdvanced then tParams.FinalFunc() end
    ---------------------------------------------------------------------------
    if not aScriptCall then
      local function GetTitle()
        if _Plugin.HField("config").bShowSpentTime then
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
    end
    return nFound, nReps, sChoice, nElapsed
  end

  local ok, nFound, nReps, sChoice, nElapsed = xpcall(Work, debug.traceback)
  if ok then
    if not aScriptCall then
      editor.SetTitle(nil, "")
    end
    if sChoice == "newsearch" then
      return EditorAction(aOp, aData, aScriptCall)
    else
      local checked = tParams.bHighlight
      if checked or not Editors.IsHighlightGrep() then
        Editors.SetHighlightPattern(tParams.Regex)
        Editors.ActivateHighlight(checked)
      end
      return nFound, nReps, sChoice, nElapsed
    end
  end
  if not aScriptCall then
    ErrorMsg(nFound,nil,nil,"wl")
    editor.SetTitle(nil, "")
  end
end


return {
  EditorAction = EditorAction,
  UnlockEditor = UnlockEditor,
}
