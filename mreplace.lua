--local regex = require "rex_pcre"

local F=far.Flags
local AppName = "Multiline Replace"

local M = require "lf4ed_message"
local far2_dialog = require "far2.dialog"

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
    [[ \\x([0-9a-f]{1,4}) | \\(.) | (\%) | \$([0-9]) ]],
    function(j,k,l,m)
      if j then
        j = unicode.utf8.char(tonumber(j,16))
        return j=="%" and "%%" or j
      end
      return k and (subst[k] or k) or l and "%%" or "%"..m
    end, nil, "ix")
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

--------------------------------------------------------------------------------
------------------------- Test Suite BEGIN -------------------------------------
--------------------------------------------------------------------------------

local function OpenHelperEditor()
  local ret = editor.Editor ("__tmp__.tmp", nil, nil,nil,nil,nil,
              {EF_NONMODAL=1, EF_IMMEDIATERETURN=1, EF_CREATENEW=1}, 0, 0)
  assert (ret == F.EEC_MODIFIED, "could not open file")
end

local function CloseHelperEditor()
  editor.Quit()
  far.AdvControl("ACTL_COMMIT")
end

local function ProtectedError(msg, level)
  CloseHelperEditor()
  error(msg, level)
end

local function ProtectedAssert(condition, msg)
  if not condition then ProtectedError(msg or "assertion failed") end
end

local function GetEditorText()
  local t = {}
  editor.SetPosition(nil, 0, 0)
  for i=1, editor.GetInfo().TotalLines do
    t[i] = editor.GetString(nil, i-1, 2)
  end
  return table.concat(t, "\r")
end

local function SetEditorText(str)
  editor.SetPosition(nil,0,0)
  for i=1, editor.GetInfo().TotalLines do
    editor.DeleteString()
  end
  editor.InsertText(nil, str)
end

local function AssertEditorText(ref, msg)
  ProtectedAssert(GetEditorText() == ref, msg)
end

local function RunOneTest (lib, op, data, refFound, refReps)
  data.sRegexLib = lib
  editor.SetPosition(nil, data.CurLine or 0, data.CurPos or 0)
  local nFound, nReps = EditorAction(op, data)
  if nFound ~= refFound or nReps ~= refReps then
    ProtectedError(
      "nFound="        .. nFound..
      "; refFound="    .. refFound..
      "; nReps="       .. nReps..
      "; refReps="     .. refReps..
      "; sRegexLib="   .. tostring(data.sRegexLib)..
      "; bCaseSens="   .. tostring(data.bCaseSens)..
      "; bRegExpr="    .. tostring(data.bRegExpr)..
      "; bWholeWords=" .. tostring(data.bWholeWords)..
      "; bExtended="   .. tostring(data.bExtended)..
      "; bSearchBack=" .. tostring(data.bSearchBack)..
      "; sScope="      .. tostring(data.sScope)..
      "; sOrigin="     .. tostring(data.sOrigin)
    )
  end
end

local function test_Replace (lib)
  -- test empty replace
  local dt = { sSearchPat="l", sReplacePat="" }
  SetEditorText("line1\rline2\rline3\r")
  RunOneTest(lib, "test:replace", dt, 3, 3)
  AssertEditorText("ine1\rine2\rine3\r")

  -- test non-empty replace
  dt = { sSearchPat="l", sReplacePat="LL" }
  SetEditorText("line1\rline2\rline3\r")
  RunOneTest(lib, "test:replace", dt, 3, 3)
  AssertEditorText("LLine1\rLLine2\rLLine3\r")

  -- test submatches (captures)
  dt = { sSearchPat="(.)(.)(.)(.)(.)(.)(.)(.)(.)",
         sReplacePat="-$9-$8-$7-$6-$5-$4-$3-$2-$1-$0-",
         bRegExpr=true }
  local subj = "abcdefghi1234"
  SetEditorText(subj)
  RunOneTest(lib, "test:replace", dt, 1, 1)
  AssertEditorText("-i-h-g-f-e-d-c-b-a-abcdefghi-1234")

  -- test escaped dollar and backslash
  dt = { sSearchPat="abc", sReplacePat=[[$0\$0\t\\t]], bRegExpr=true }
  SetEditorText("abc")
  RunOneTest(lib, "test:replace", dt, 1, 1)
  AssertEditorText("abc$0\t\\t")

  -- test escape sequences in replace pattern
  local dt = { sSearchPat="b", sReplacePat=[[\a\e\f\n\r\t]], bRegExpr=true }
  for i=0,127 do dt.sReplacePat = dt.sReplacePat .. ("\\x%x"):format(i) end
  SetEditorText("abc")
  RunOneTest(lib, "test:replace", dt, 1, 1)
  local result = "a\7\27\12\13\13\9"
  for i=0,127 do result = result .. string.char(i) end
  result = result:gsub("\10", "\13", 1) .. "c"
  AssertEditorText(result)

  -- test replace in selection
  dt = { sSearchPat="in", sReplacePat="###", sScope="block" }
  SetEditorText("line1\rline2\rline3\rline4\r")
  editor.Select(nil, "BTYPE_STREAM",1,0,-1,2)
  RunOneTest(lib, "test:replace", dt, 2, 2)
  AssertEditorText("line1\rl###e2\rl###e3\rline4\r")

  -- test replace patterns containing \n or \r
  local dt = { sSearchPat=".", sReplacePat="a\rb", bRegExpr=true }
  dt.sOrigin = "scope"
  SetEditorText("L1\rL2\r")
  RunOneTest(lib, "test:replace", dt, 4, 4)
  AssertEditorText("a\rba\rb\ra\rba\rb\r")
  ------------------------------------------------------------------------------
end

local function Test()
  OpenHelperEditor()
  test_Replace("regex")
  CloseHelperEditor()
end

--------------------------------------------------------------------------------
------------------------- Test Suite END ---------------------------------------
--------------------------------------------------------------------------------

do
  local arg = ...
  if type(arg)=="table" and arg[1]=="dialog" then
    local histData = arg[2]
    if ReplaceDialog(histData) then
      local ok, ret = pcall(EditorAction, "replace", histData)
      editor.Redraw()
      if ok then
        local msg = (ret==0) and "No match found" or
          ("%d replacement%s made."):format(ret, ret==1 and "" or "s")
        far.Message(msg, AppName)
      else
        far.Message(ret, "Error", nil, "w")
      end
    end
  else
    Test()
    far.Message("All tests OK", AppName)
  end
end
