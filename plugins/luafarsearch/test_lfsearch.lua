-- coding: utf-8
-- started: 2009-12-04 by Shmuel Zeigerman
-- luacheck: globals _Plugin lfsearch

local DIRSEP = string.sub(package.config, 1, 1)
local OS_WIN = (DIRSEP == "\\")
local TMPDIR = OS_WIN and assert(win.GetEnv("Temp")) or far.InMyTemp()

local GetHistory = function(s1,s2) return _Plugin.History[s1][s2] end
local SetHistory = function(s1,s2,val) _Plugin.History[s1][s2] = val end

local selftest = {} -- this module

local F = far.Flags
local join = win.JoinPath
local russian_alphabet_utf8 = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя"

local function OpenHelperEditor()
  local ret = editor.Editor ("__tmp__.tmp", nil, nil,nil,nil,nil,
              {EF_NONMODAL=1, EF_IMMEDIATERETURN=1, EF_CREATENEW=1})
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
  editor.SetPosition(nil, 1, 1)
  for i=1, editor.GetInfo().TotalLines do
    t[i] = editor.GetString(nil, i, 2)
  end
  return table.concat(t, "\n")
end

local function SetEditorText(str)
  editor.SetParam(nil, F.ESPT_EXPANDTABS, F.EXPAND_NOTABS)
  editor.SetParam(nil, F.ESPT_AUTOINDENT, false)
  editor.SetPosition(nil,1,1)
  for _=1, editor.GetInfo().TotalLines do
    editor.DeleteString()
  end
  if not OS_WIN then
    str = str:gsub("\n", "\r")
  end
  editor.InsertText(nil,str)
end

local function AssertEditorText(ref, msg)
  ProtectedAssert(GetEditorText() == ref, msg)
end

--//////////////////////////////////////////////////////////////////////////////////////////////////

do -- former selftest.lua

local function RunEditorAction (lib, op, data, refFound, refReps)
  data.sRegexLib = lib
  if not data.KeepCurPos then
    editor.SetPosition(nil, data.CurLine or 1, data.CurPos or 1)
  end
  local nFound, nReps = lfsearch.EditorAction(op, data)
  if nFound ~= refFound or nReps ~= refReps then
    ProtectedError(
      "nFound="        .. tostring(nFound)..
      "; refFound="    .. tostring(refFound)..
      "; nReps="       .. tostring(nReps)..
      "; refReps="     .. tostring(refReps)..
      "; sRegexLib="   .. tostring(data.sRegexLib)..
      "; bCaseSens="   .. tostring(data.bCaseSens)..
      "; bRegExpr="    .. tostring(data.bRegExpr)..
      "; bWholeWords=" .. tostring(data.bWholeWords)..
      "; bExtended="   .. tostring(data.bExtended)..
      "; bSearchBack=" .. tostring(data.bSearchBack)..
      "; bWrapAround=" .. tostring(data.bWrapAround)..
      "; sScope="      .. tostring(data.sScope)..
      "; sOrigin="     .. tostring(data.sOrigin)
    )
  end
end

local function test_Switches (lib)
  SetEditorText("line1\nline2\nline3\nline4\n")
  local dt = { CurLine=2, CurPos=2 }

  for k1=0,1    do dt.bCaseSens   = (k1==1)
  for k2=0,1    do dt.bRegExpr    = (k2==1)
  for k3=0,1    do dt.bWholeWords = (k3==1)
  for k4=0,1    do dt.bExtended   = (k4==1)
  for k5=0,1    do dt.bSearchBack = (k5==1)
  for k6=0,1    do dt.sOrigin     = (k6==1 and "scope" or "cursor")
  for k7=0,1    do dt.bWrapAround = (k7==1)
    local bEnable
    ---------------------------------
    dt.sSearchPat = "a"
    RunEditorAction(lib, "test:search", dt, 0, 0)
    RunEditorAction(lib, "test:count",  dt, 0, 0)
    ---------------------------------
    dt.sSearchPat = "line"
    bEnable = dt.bRegExpr or not dt.bWholeWords
    RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
    RunEditorAction(lib, "test:count",  dt, bEnable and (dt.sOrigin=="scope" and 4 or
      dt.bWrapAround and 4 or dt.bSearchBack and 1 or 2) or 0, 0)
    ---------------------------------
    dt.sSearchPat = "LiNe"
    bEnable = (dt.bRegExpr or not dt.bWholeWords) and not dt.bCaseSens
    RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
    RunEditorAction(lib, "test:count",  dt, bEnable and (dt.sOrigin=="scope" and 4 or
      dt.bWrapAround and 4 or dt.bSearchBack and 1 or 2) or 0, 0)
    ---------------------------------
    dt.sSearchPat = "."
    bEnable = dt.bRegExpr
    RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
    RunEditorAction(lib, "test:count", dt, bEnable and (dt.sOrigin=="scope" and 20 or
      dt.bWrapAround and 20 or dt.bSearchBack and 6 or 14) or 0, 0)
    ---------------------------------
    dt.sSearchPat = " . "
    bEnable = dt.bRegExpr and dt.bExtended
    RunEditorAction(lib, "test:search", dt, bEnable and 1 or 0, 0)
    RunEditorAction(lib, "test:count", dt, bEnable and (dt.sOrigin=="scope" and 20 or
      dt.bWrapAround and 20 or dt.bSearchBack and 6 or 14) or 0, 0)
    ---------------------------------
  end end end end end end end
end

-- the bug was in Linux version
local function test_bug_20220618 (lib)
  SetEditorText("text-текст")
  local dt = { bRegExpr=true; sSearchPat="."; }
  RunEditorAction(lib, "test:count",  dt, 10, 0)
end

local function test_LineFilter (lib)
  SetEditorText("line1\nline2\nline3\n")
  local dt = { sSearchPat="line" }

  RunEditorAction(lib, "test:search", dt, 1, 0)
  RunEditorAction(lib, "test:count",  dt, 3, 0)

  dt.bAdvanced = true
  dt.sFilterFunc = "  "
  RunEditorAction(lib, "test:search", dt, 1, 0)
  RunEditorAction(lib, "test:count",  dt, 3, 0)

  dt.sFilterFunc = "return"
  RunEditorAction(lib, "test:search", dt, 1, 0)
  RunEditorAction(lib, "test:count",  dt, 3, 0)

  dt.sFilterFunc = " return true "
  RunEditorAction(lib, "test:search", dt, 0, 0)
  RunEditorAction(lib, "test:count",  dt, 0, 0)

  dt.sFilterFunc = "return n == 2"
  RunEditorAction(lib, "test:search", dt, 1, 0)
  RunEditorAction(lib, "test:count",  dt, 2, 0)

  dt.sFilterFunc = "return not rex.find(s, '[13]')"
  RunEditorAction(lib, "test:search", dt, 1, 0)
  RunEditorAction(lib, "test:count",  dt, 2, 0)

  dt.sInitFunc = "Var1,Var2 = 'line2','line3'"
  dt.sFilterFunc = "return not(s==Var1 or s==Var2)"
  dt.sFinalFunc = "assert(Var1=='line2')"
  RunEditorAction(lib, "test:search", dt, 1, 0)
  RunEditorAction(lib, "test:count",  dt, 2, 0)

  dt.sInitFunc = nil
  dt.sFinalFunc = "assert(Var1==nil)"
  RunEditorAction(lib, "test:search", dt, 0, 0)
  RunEditorAction(lib, "test:count",  dt, 0, 0)
end

local function test_Replace (lib)
  for k=0,1 do
  -- test "user choice function"
    SetEditorText("line1\nline2\nline3\n")
    local dt = { sSearchPat=".", sReplacePat="$0", bRegExpr=true,
      bConfirmReplace=true, bSearchBack = (k==1), sOrigin = "scope" }
    for _,ch in ipairs {"yes","all","no","cancel"} do
      local cnt = 0
      dt.fUserChoiceFunc = function() cnt=cnt+1; return ch end
      RunEditorAction(lib, "test:replace", dt,
        ch=="cancel" and 1 or 15, (ch=="yes" or ch=="all") and 15 or 0)
      ProtectedAssert(
        (ch=="yes" or ch=="no") and cnt==15 or
        (ch=="all" or ch=="cancel") and cnt==1)
    end

    -- test empty replace
    dt = { sSearchPat="l", sReplacePat="", bSearchBack = (k==1),
      sOrigin = "scope" }
    SetEditorText("line1\nline2\nline3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("ine1\nine2\nine3\n")

    -- test empty replace with cyrillic characters
    dt = { sSearchPat="с", sReplacePat="", bSearchBack = (k==1),
      sOrigin = "scope" }
    SetEditorText("строка1\nстрока2\nстрока3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("трока1\nтрока2\nтрока3\n")

    -- test replace of empty match
    dt = { sSearchPat=".*?", sReplacePat="-", bSearchBack = (k==1),
      sOrigin = "scope", bRegExpr=true }
    SetEditorText("строка1\nстрока2\n")
    RunEditorAction(lib, "test:replace", dt, 17, 17)
    AssertEditorText("-с-т-р-о-к-а-1-\n-с-т-р-о-к-а-2-\n-")

    -- test non-empty replace
    dt = { sSearchPat="l", sReplacePat="LL", bSearchBack = (k==1),
      sOrigin = "scope" }
    SetEditorText("line1\nline2\nline3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("LLine1\nLLine2\nLLine3\n")

    -- Test regular expression replace with replace string containing cyrillic characters.
    -- [*] This test hangs Far Manager >= 3.0.5459 (replace of "slnunicode" library with "luautf8"),
    --     with LFS versions <= 3.43.6 --> fixed in LFS version 3.43.7.
    -- [*] The hanging occured in function IsChar() in file lfs_replib.lua.
    -- [*] LFS version 3.43.7 must work with _all_ Far Manager versions >= 3.0.4878.
    dt = { sSearchPat="l", sReplacePat="абвгд", bRegExpr=true; bSearchBack = (k==1), sOrigin = "scope" }
    SetEditorText("line1\n")
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    AssertEditorText("абвгдine1\n")

    -- test replace from cursor
    dt = { sSearchPat="l", sReplacePat="LL", CurLine=2, CurPos=2, bSearchBack = (k==1) }
    for m=1,2 do
      dt.bWrapAround = (m==2)
      SetEditorText("line1\nline2\nline3\n")
      if dt.bSearchBack then
        RunEditorAction(lib, "test:replace", dt, m==1 and 2 or 3, m==1 and 2 or 3)
        AssertEditorText(m==1 and "LLine1\nLLine2\nline3\n" or "LLine1\nLLine2\nLLine3\n")
      else
        RunEditorAction(lib, "test:replace", dt, m==1 and 1 or 3, m==1 and 1 or 3)
        AssertEditorText(m==1 and "line1\nline2\nLLine3\n" or "LLine1\nLLine2\nLLine3\n")
      end
    end

    -- test replace with wrap-around when replacing string is shorter than search string
    dt = { sSearchPat="li", sReplacePat="", CurLine=2, CurPos=2, bSearchBack = (k==1) }
    dt.bWrapAround = true
    SetEditorText("line1\nline2\nline3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("ne1\nne2\nne3\n")

    -- test replace from cursor while inserting new lines
    dt = { sSearchPat="l", sReplacePat="A\nB", CurLine=2, CurPos=2, bSearchBack = (k==1) }
    for m=1,2 do
      dt.bWrapAround = (m==2)
      SetEditorText("line1\nline2\nline3\n")
      if dt.bSearchBack then
        RunEditorAction(lib, "test:replace", dt, m==1 and 2 or 3, m==1 and 2 or 3)
        AssertEditorText(m==1 and "A\nBine1\nA\nBine2\nline3\n" or "A\nBine1\nA\nBine2\nA\nBine3\n")
      else
        RunEditorAction(lib, "test:replace", dt, m==1 and 1 or 3, m==1 and 1 or 3)
        AssertEditorText(m==1 and "line1\nline2\nA\nBine3\n" or "A\nBine1\nA\nBine2\nA\nBine3\n")
      end
    end

    -- test inserting new lines and preserving missing EOL of the starting line
    dt = { sSearchPat=".*", bRegExpr=true, sOrigin="cursor", bSearchBack = (k==1) }
    for aa = 1,3 do for bb = 1,2 do
      dt.sReplacePat = (aa == 1) and "$0\n" or (aa == 2) and "$0\r" or "$0\r\n"
      dt.sOrigin = (bb == 1) and "scope" or "cursor"
      SetEditorText("")
      RunEditorAction(lib, "test:replace", dt, 1, 1)
      AssertEditorText("\n")
    end end

    -- test submatches (captures)
    local function makerep(fmt)
      local s = ""
      for k=35,0,-1 do s = s .. fmt:format(k) end
      return s
    end
    dt = { sSearchPat=("(.)"):rep(35); bRegExpr=true; sOrigin="scope"; }
    dt.bSearchBack = (k==1)
    local subj = "123456789abcdefghijklmnopqrstuvwxyz###"
    for m=1,2 do
      local fmt = (m==1) and "$%d" or "${%d}"
      dt.sReplacePat = makerep(fmt)
      SetEditorText(subj)
      RunEditorAction(lib, "test:replace", dt, 1, 1)
      AssertEditorText(dt.bSearchBack and
        subj:sub(1,3) .. subj:sub(4):reverse() .. subj:sub(4) or
        subj:sub(1,35):reverse() .. subj)
    end

    -- test named groups
    dt = { sSearchPat = lib=="far"
             and "(?{foo}\\w+)(?{space}\\s+)(?{bar}\\w+)"
              or "(?<foo>\\w+)(?<space>\\s+)(?<bar>\\w+)",
           sReplacePat="${bar}${space}${foo}",
           bRegExpr=true,
           bSearchBack = (k==1),
           sOrigin = "scope" }
    SetEditorText("@@@ word1  \t\t  WORD2 @@@")
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    AssertEditorText("@@@ WORD2  \t\t  word1 @@@")

    dt.bRepIsFunc = true
    dt.sReplacePat = "return T.bar .. T.space .. T.foo"
    SetEditorText("@@@ word1  \t\t  WORD2 @@@")
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    AssertEditorText("@@@ WORD2  \t\t  word1 @@@")

    -- test escaped dollar and backslash
    dt = { sSearchPat="abc", sReplacePat=[[$0\$0\t\\t]], bRegExpr=true }
    dt.bSearchBack = (k==1)
    dt.sOrigin = "scope"
    SetEditorText("abc")
    RunEditorAction(lib, "test:replace", dt, 1, 1)
    AssertEditorText("abc$0\t\\t")

    -- test date/time insertion
    dt = { sSearchPat=".+", sReplacePat=[[\D{$ \n date is %Y-%m-%d : }$0]], bRegExpr=true }
    dt.bSearchBack = (k==1)
    dt.sOrigin = "scope"
    SetEditorText("line1\nline2\n")
    RunEditorAction(lib, "test:replace", dt, 2, 2)
    local ref = ("$ \\n date is %d%d%d%d%-%d%d%-%d%d : line%d\n"):rep(2)
    ProtectedAssert(GetEditorText():match(ref))
  end

  -- test escape sequences in replace pattern
  local dt = { sSearchPat="b", sReplacePat=[[\a\e\f\n\r\t]], bRegExpr=true }
  for i=0,127 do dt.sReplacePat = dt.sReplacePat .. ("\\x%x"):format(i) end
  SetEditorText("abc")
  RunEditorAction(lib, "test:replace", dt, 1, 1)
  local result = "a\7\27\12\10\13\9"
  for i=0,127 do result = result .. string.char(i) end
  result = result:gsub("\13", "\10") .. "c"
  AssertEditorText(result)

  -- test text case modifiers
  dt = { sSearchPat="abAB",
    sReplacePat=[[\l$0 \u$0 \L$0\E $0 \U$0\E $0 \L\u$0\E \U\l$0\E \L\U$0\E$0\E]],
    bRegExpr=true }
  SetEditorText("abAB")
  RunEditorAction(lib, "test:replace", dt, 1, 1)
  AssertEditorText("abAB AbAB abab abAB ABAB abAB Abab aBAB ABABabab")

  -- test counter
  dt = { sSearchPat=".+", sReplacePat=[[\R$0]], bRegExpr=true }
  SetEditorText("a\nb\nc\nd\ne\nf\ng\nh\ni\nj\n")
  RunEditorAction(lib, "test:replace", dt, 10, 10)
  AssertEditorText("1a\n2b\n3c\n4d\n5e\n6f\n7g\n8h\n9i\n10j\n")
  --------
  dt.sReplacePat=[[\R{-5}$0]]
  SetEditorText("a\nb\nc\nd\ne\nf\ng\nh\ni\nj\n")
  RunEditorAction(lib, "test:replace", dt, 10, 10)
  AssertEditorText("-5a\n-4b\n-3c\n-2d\n-1e\n0f\n1g\n2h\n3i\n4j\n")
  --------
  dt.sReplacePat=[[\R{5,3}$0]]
  SetEditorText("a\nb\nc\nd\ne\nf\ng\nh\ni\nj\n")
  RunEditorAction(lib, "test:replace", dt, 10, 10)
  AssertEditorText("005a\n006b\n007c\n008d\n009e\n010f\n011g\n012h\n013i\n014j\n")

  -- test replace in selection
  dt = { sSearchPat="in", sReplacePat="###", sScope="block" }
  SetEditorText("line1\nline2\nline3\nline4\n")
  editor.Select(nil,"BTYPE_STREAM",2,1,-1,2)
  RunEditorAction(lib, "test:replace", dt, 2, 2)
  AssertEditorText("line1\nl###e2\nl###e3\nline4\n")
  --------
  dt = { sSearchPat=".+", sReplacePat="###", sScope="block", bRegExpr=true }
  SetEditorText("line1\nline2\nline3\nline4\n")
  editor.Select(nil,"BTYPE_COLUMN",2,2,2,2)
  RunEditorAction(lib, "test:replace", dt, 2, 2)
  AssertEditorText("line1\nl###e2\nl###e3\nline4\n")

  -------- replace in mixed tab/spaces vertical selection
  -------- (testing for a bug fixed on 2025-02-17)
  dt = { sSearchPat="^\\s+", sReplacePat="\t\t", sScope="block", bRegExpr=true,
         bConfirmReplace=true, fUserChoiceFunc = function() return "yes" end }
  editor.SetParam(nil, F.ESPT_TABSIZE, 4)
  SetEditorText("\t\t\tABC\n            DEF\n") -- 3 tabs + 12 spaces
  editor.Select(nil,"BTYPE_COLUMN",1,1,12,2)
  RunEditorAction(lib, "test:replace", dt, 2, 2)
  AssertEditorText("\t\tABC\n\t\tDEF\n")

  -- test "function mode"
  dt = { sSearchPat="\\w+", bRepIsFunc=true, bRegExpr=true,
         sReplacePat=[[return M~=2 and ("%d.%d.%d. %s;"):format(LN, M, R, T[0])]]
       }
  SetEditorText("\n\nгруша\nяблоко\nслива вишня\n")
  RunEditorAction(lib, "test:replace", dt, 4, 3)
  AssertEditorText("\n\n3.1.1. груша;\nяблоко\n5.3.2. слива; 5.4.3. вишня;\n")
  --------
  dt = { sSearchPat="(.)(.)(.)(.)(.)(.)(.)(.)(.)", bRepIsFunc=true,
         bRegExpr=true,
         sReplacePat = "V=(V or 1)*3; return V..T[9]..T[8]..T[7]..T[6]..T[5]..T[4]..T[3]..T[2]..T[1]"
  }
  SetEditorText("abcdefghiabcdefghiabcdefghi")
  RunEditorAction(lib, "test:replace", dt, 3, 3)
  AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba")
  --------
  dt.sSearchPat = ".+"
  dt.sReplacePat = [[return T[0] .. '--' .. rex.match(T[0], '\\d\\d')]]
  RunEditorAction(lib, "test:replace", dt, 1, 1)
  AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba--27")
  --------
  dt.sSearchPat = ".+"
  dt.sReplacePat = nil
  RunEditorAction(lib, "test:replace", dt, 1, 0)
  --------
  dt.sReplacePat = ""
  RunEditorAction(lib, "test:replace", dt, 1, 0)
  --------
  dt.sReplacePat = "return false"
  RunEditorAction(lib, "test:replace", dt, 1, 0)

  -- test 1-st return == true
  dt = { sSearchPat="\\D+", bRepIsFunc=true, bRegExpr=true,
         sReplacePat=[[return R==2 or "string"]]
       }
  SetEditorText("line1\nline2\nline3\n")
  RunEditorAction(lib, "test:replace", dt, 3, 3)
  AssertEditorText("string1\nstring3\n")

  -- test 2-nd return == true
  dt = { sSearchPat="\\D+", bRepIsFunc=true, bRegExpr=true,
         sReplacePat=[[return "string", R==2]]
       }
  SetEditorText("line1\nline2\nline3\n")
  RunEditorAction(lib, "test:replace", dt, 2, 2)
  AssertEditorText("string1\nstring2\nline3\n")

  -- test replace patterns containing \n or \r
  local dt = { sSearchPat=".", sReplacePat="a\nb", bRegExpr=true }
  dt.sOrigin = "scope"
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("L1\nL2\n")
    RunEditorAction(lib, "test:replace", dt, 4, 4)
    AssertEditorText("a\nba\nb\na\nba\nb\n")
  end

  -- test "Delete empty line"
  local dt = { sSearchPat=".*a.*", sReplacePat="", bRegExpr=true }
  dt.sOrigin = "scope"
  dt.bDelEmptyLine = true
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("foo1\nbar1\nfoo2\nbar2\nfoo3\nbar3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("foo1\nfoo2\nfoo3\n")
  end
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("bar1\nbar2\nbar3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("")
  end
  dt.sScope = "block"
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("foo1\nbar1\nfoo2\nbar2\nfoo3\nbar3\nfoo4\nbar4\n")
    editor.Select(nil,"BTYPE_STREAM",3,1,-1,4)
    RunEditorAction(lib, "test:replace", dt, 2, 2)
    AssertEditorText("foo1\nbar1\nfoo2\nfoo3\nfoo4\nbar4\n")
  end

  -- bug discovered 2011-09-26 -------------------------------------------------
  local dt = { sSearchPat=".+", sReplacePat="$0\n", bRegExpr=true }
  dt.sOrigin = "scope"
  dt.bDelEmptyLine = true
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("foo1\nfoo2\nfoo3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 3)
    AssertEditorText("foo1\n\nfoo2\n\nfoo3\n\n")
  end

  -- test "Delete non-matched line"
  local dt = { sSearchPat=".*a.*", sReplacePat="$0", bRegExpr=true }
  dt.sOrigin = "scope"
  dt.bDelNonMatchLine = true
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("foo1\nbar1\nfoo2\nbar2\nfoo3\nbar3\n")
    RunEditorAction(lib, "test:replace", dt, 3, 7)
    AssertEditorText("bar1\nbar2\nbar3\n")
  end
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("foo1\nfoo2\nfoo3\n")
    RunEditorAction(lib, "test:replace", dt, 0, 4)
    AssertEditorText("")
  end
  dt.sScope = "block"
  for k=0,1 do
    dt.bSearchBack = (k==1)
    SetEditorText("foo1\nbar1\nfoo2\nbar2\nfoo3\nbar3\nfoo4\nbar4\n")
    editor.Select(nil,"BTYPE_STREAM",3,1,-1,4)
    RunEditorAction(lib, "test:replace", dt, 2, 4)
    AssertEditorText("foo1\nbar1\nbar2\nbar3\nfoo4\nbar4\n")
  end
  ------------------------------------------------------------------------------
end

local function test_Encodings (lib)
  local dt = { bRegExpr=true }
  dt.sSearchPat = "\\w+"
  --------
  SetEditorText(russian_alphabet_utf8)
  dt.sReplacePat = ""
  RunEditorAction(lib, "test:replace", dt, 1, 1)
  AssertEditorText("")
  --------
  SetEditorText(russian_alphabet_utf8)
  dt.sReplacePat = "\\L$0"
  RunEditorAction(lib, "test:replace", dt, 1, 1)
  local s = GetEditorText()
  ProtectedAssert(s:sub(1,33)==s:sub(34))
  --------
  SetEditorText(russian_alphabet_utf8)
  dt.sReplacePat = "\\U$0"
  RunEditorAction(lib, "test:replace", dt, 1, 1)
  local s = GetEditorText()
  ProtectedAssert(s:sub(1,33)==s:sub(34))
  --------
end

local function test_bug_20090208 (lib)
  local dt = { bRegExpr=true, sReplacePat="\n$0", sScope="block" }
  dt.sSearchPat = "\\w+"
  SetEditorText(("my table\n"):rep(5))
  editor.Select(nil,"BTYPE_STREAM",2,1,-1,2)
  RunEditorAction(lib, "test:replace", dt, 4, 4)
  AssertEditorText("my table\n\nmy \ntable\n\nmy \ntable\nmy table\nmy table\n")
end

local function test_bug_20100802 (lib)
  local dt = { sOrigin="scope", bRegExpr=true, sReplacePat="" }
  for k = 0, 1 do
    dt.bSearchBack = (k == 1)

    SetEditorText("line1\nline2\n")
    dt.sSearchPat = "^."
    RunEditorAction(lib, "test:replace", dt, 2, 2)
    AssertEditorText("ine1\nine2\n")

    SetEditorText("line1\nline2\n")
    dt.sSearchPat = ".$"
    RunEditorAction(lib, "test:replace", dt, 2, 2)
    AssertEditorText("line\nline\n")
  end
end

local function test_EmptyMatch (lib)
  local dt = { bRegExpr=true, sReplacePat="-" }
  dt.sSearchPat = ".*?"
  SetEditorText(("line1\nline2\n"))
  RunEditorAction(lib, "test:replace", dt, 13, 13)
  AssertEditorText("-l-i-n-e-1-\n-l-i-n-e-2-\n-")

  dt.sSearchPat, dt.sReplacePat = ".*", "1. $0"
  SetEditorText(("line1\nline2\n"))
  RunEditorAction(lib, "test:replace", dt, 3, 3)
  AssertEditorText("1. line1\n1. line2\n1. ")
end

local function test_Anchors (lib)
  local dt = { bRegExpr=true, sOrigin="scope" }
  SetEditorText("line\nline\n")
  for k1 = 0, 1 do dt.sSearchPat = (k1 == 0) and "^." or ".$"
  for k2 = 0, 1 do dt.bSearchBack = (k2 == 1)
    RunEditorAction(lib, "test:count", dt, 2, 0)
  end end
end

local function test_bug1_20111114 (lib)
  local bSelectFound = GetHistory("config", "bSelectFound")
  if not bSelectFound then SetHistory("config", "bSelectFound", true) end

  SetEditorText("Д121") -- 1-st char takes 2 bytes in UTF-8

  local dt = { sSearchPat="1", sOrigin="cursor", CurPos=3 }
  RunEditorAction(lib, "test:search", dt, 1, 0)
  if not bSelectFound then SetHistory("config", "bSelectFound", false) end

  local info, SI = editor.GetInfo(), editor.GetString()
  ProtectedAssert(info.CurPos == 5)
  ProtectedAssert(SI.SelStart == 4)
  ProtectedAssert(SI.SelEnd == 4)

  dt.CurPos = 1
  RunEditorAction(lib, "test:count", dt, 2, 0)
end

local function test_bug2_20111114 (lib)
  local bSelectFound = GetHistory("config", "bSelectFound")
  if not bSelectFound then SetHistory("config", "bSelectFound", true) end

  SetEditorText("Д121") -- 1-st char takes 2 bytes in UTF-8

  local dt = { sSearchPat="1", sOrigin="cursor", sScope="block", CurPos=3 }
  editor.Select(nil,"BTYPE_STREAM",1,1,4,1)
  RunEditorAction(lib, "test:search", dt, 1, 0)
  if not bSelectFound then SetHistory("config", "bSelectFound", false) end

  local info, SI = editor.GetInfo(), editor.GetString()
  ProtectedAssert(info.CurPos == 5)
  ProtectedAssert(SI.SelStart == 4)
  ProtectedAssert(SI.SelEnd == 4)

  dt.CurPos = 1
  editor.Select(nil,"BTYPE_STREAM",1,1,3,1)
  RunEditorAction(lib, "test:count", dt, 1, 0)

  editor.Select(nil,"BTYPE_STREAM",1,1,4,1)
  RunEditorAction(lib, "test:count", dt, 2, 0)
end

local function test_bug_20120301 (lib)
  SetEditorText("-\tabc")
  local dt = { sSearchPat="abc", sReplacePat="", sScope="block" }
  local pos = editor.RealToTab(nil, 1, 3)
  editor.Select(nil, "BTYPE_COLUMN", 1, pos, 3, 1)
  RunEditorAction(lib, "test:replace", dt, 1, 1)
end

local function test_FindWordUnderCursor (lib)
  SetEditorText("abc\nabc\nabc\nabc")
  local dt = { sSearchPat="1234" }
  for k=1,3 do
    if k==2 then dt.KeepCurPos=true end
    RunEditorAction(lib, "searchword", dt, 1, 0)
  end
  for _=1,3 do RunEditorAction(lib, "searchword_rev", dt, 1, 0) end
end

-- При полностью выделенных N строках, не должна захватываться (N+1)-я строка.
local function test_bug_20161108 (lib)
  for k=1,2 do
    SetEditorText("line1\nline2\n")
    local dt = { sSearchPat="$", sReplacePat="-", sScope="block", sOrigin="scope", bRegExpr=true }
    dt.bSearchBack = (k==2)
    editor.Select(nil, "BTYPE_STREAM", 1, 1, 0, 3)
    RunEditorAction(lib, "test:count", dt, 2, 0)
    RunEditorAction(lib, "test:replace", dt, 2, 2)
    AssertEditorText("line1-\nline2-\n")
  end
end

function selftest.test_editor_search_replace (lib)
  assert(type(lfsearch) == "table")
  OpenHelperEditor()
  test_Switches     (lib)
  test_bug_20220618 (lib)
  test_LineFilter   (lib)
  test_Replace      (lib)
  test_Encodings    (lib)
  test_Anchors      (lib)
  test_EmptyMatch   (lib)
  test_bug_20090208 (lib)
  test_bug_20100802 (lib)
  test_bug1_20111114(lib)
  test_bug2_20111114(lib)
  test_bug_20120301 (lib)
  test_FindWordUnderCursor(lib)
  test_bug_20161108 (lib)
  CloseHelperEditor()
end

end

--//////////////////////////////////////////////////////////////////////////////////////////////////

do -- former test_mreplace.lua

local function RunEditorAction (lib, op, data, refFound, refReps)
  data.sRegexLib = lib
  if not data.KeepCurPos then
    editor.SetPosition(nil, data.CurLine or 1, data.CurPos or 1)
  end
  local nFound, nReps = lfsearch.MReplaceEditorAction(op, data)
  if nFound ~= refFound or nReps ~= refReps then
    ProtectedError(
      "nFound="        .. tostring(nFound)..
      "; refFound="    .. tostring(refFound)..
      "; nReps="       .. tostring(nReps)..
      "; refReps="     .. tostring(refReps)..
      "; sRegexLib="   .. tostring(data.sRegexLib)..
      "; bCaseSens="   .. tostring(data.bCaseSens)..
      "; bRegExpr="    .. tostring(data.bRegExpr)..
      "; bWholeWords=" .. tostring(data.bWholeWords)..
      "; bExtended="   .. tostring(data.bExtended)..
      "; bFileAsLine=" .. tostring(data.bFileAsLine)..
      "; bMultiLine="  .. tostring(data.bMultiLine)
    )
  end
end

local function test_Switches (lib)
  SetEditorText("line1\nline2\nline3\nline4\n")
  local dt = {}

  for k1=0,1    do dt.bCaseSens   = (k1==1)
  for k2=0,1    do dt.bRegExpr    = (k2==1)
  for k3=0,1    do dt.bWholeWords = (k3==1)
  for k4=0,1    do dt.bExtended   = (k4==1)
  for k5=0,1    do dt.bFileAsLine = (k5==1)
  for k6=0,1    do dt.bMultiLine  = (k6==1)
    local bEnable
    ---------------------------------
    dt.sSearchPat = "a"
    RunEditorAction(lib, "count",  dt, 0, 0)
    ---------------------------------
    dt.sSearchPat = "line"
    bEnable = dt.bRegExpr or not dt.bWholeWords
    RunEditorAction(lib, "count",  dt, bEnable and 4 or 0, 0)
    ---------------------------------
    dt.sSearchPat = "LiNe"
    bEnable = (dt.bRegExpr or not dt.bWholeWords) and not dt.bCaseSens
    RunEditorAction(lib, "count",  dt, bEnable and 4 or 0, 0)
    ---------------------------------
    dt.sSearchPat = "."
    bEnable = dt.bRegExpr
    RunEditorAction(lib, "count", dt, bEnable and (dt.bFileAsLine and 24 or 20) or 0, 0)
    ---------------------------------
    dt.sSearchPat = " . "
    bEnable = dt.bRegExpr and dt.bExtended
    RunEditorAction(lib, "count", dt, bEnable and (dt.bFileAsLine and 24 or 20) or 0, 0)
    ---------------------------------
    dt.sSearchPat = "^\\w+"
    bEnable = dt.bRegExpr
    RunEditorAction(lib, "count", dt, bEnable and (dt.bMultiLine and 4 or 1) or 0, 0)
    ---------------------------------
    dt.sSearchPat = "\\w+$"
    bEnable = dt.bRegExpr
    local nRef1 = lib=="far" and 0 or 1 -- see flag PCRE_DOLLAR_ENDONLY
    RunEditorAction(lib, "count", dt, bEnable and (dt.bMultiLine and 4 or nRef1) or 0, 0)
    ---------------------------------
  end end end end end end
end

-- the bug was in Linux version
local function test_bug_20220618 (lib)
  SetEditorText("text-текст")
  local dt = { bRegExpr=true; sSearchPat="."; }
  RunEditorAction(lib, "test:count",  dt, 10, 0)
end

local function test_Replace (lib)
  -- test empty replace
  local dt = { sSearchPat="l", sReplacePat="" }
  SetEditorText("line1\nline2\nline3\n")
  RunEditorAction(lib, "replace", dt, 3, 3)
  AssertEditorText("ine1\nine2\nine3\n")

  -- test non-empty replace
  dt = { sSearchPat="l", sReplacePat="LL" }
  SetEditorText("line1\nline2\nline3\n")
  RunEditorAction(lib, "replace", dt, 3, 3)
  AssertEditorText("LLine1\nLLine2\nLLine3\n")

  -- test submatches (captures)
  local function makerep(fmt)
    local s = ""
    for k=35,0,-1 do s = s .. fmt:format(k) end
    return s
  end
  dt = { sSearchPat=("(.)"):rep(35); bRegExpr=true; }
  local subj = "123456789abcdefghijklmnopqrstuvwxyz###"
  for m=1,2 do
    local fmt = (m==1) and "$%d" or "${%d}"
    dt.sReplacePat = makerep(fmt)
    SetEditorText(subj)
    RunEditorAction(lib, "replace", dt, 1, 1)
    AssertEditorText(subj:sub(1,35):reverse() .. subj)
  end

  -- test escaped dollar and backslash
  dt = { sSearchPat="abc", sReplacePat=[[$0\$0\t\\t]], bRegExpr=true }
  SetEditorText("abc")
  RunEditorAction(lib, "replace", dt, 1, 1)
  AssertEditorText("abc$0\t\\t")

  -- test escape sequences in replace pattern
  local dt = { sSearchPat="b", sReplacePat=[[\a\e\f\n\r\t]], bRegExpr=true }
  for i=0,127 do dt.sReplacePat = dt.sReplacePat .. ("\\x%x"):format(i) end
  SetEditorText("abc")
  RunEditorAction(lib, "replace", dt, 1, 1)
  local result = "a\7\27\12\10\13\9"
  for i=0,127 do result = result .. string.char(i) end
  result = result:gsub("\13", "\10") .. "c"
  AssertEditorText(result)

  -- test replace in selection
  dt = { sSearchPat="in", sReplacePat="###", sScope="block" }
  SetEditorText("line1\nline2\nline3\nline4\n")
  editor.Select(nil,"BTYPE_STREAM",2,1,-1,2)
  RunEditorAction(lib, "replace", dt, 2, 2)
  AssertEditorText("line1\nl###e2\nl###e3\nline4\n")

  -- test replace patterns containing \n or \r
  local dt = { sSearchPat=".", sReplacePat="a\nb", bRegExpr=true }
  dt.sOrigin = "scope"
  SetEditorText("L1\nL2\n")
  RunEditorAction(lib, "replace", dt, 4, 4)
  AssertEditorText("a\nba\nb\na\nba\nb\n")

  -- test date/time insertion
  dt = { sSearchPat=".+", sReplacePat=[[\D{$ \n date is %Y-%m-%d : }$0]], bRegExpr=true }
  SetEditorText("line1\nline2\n")
  RunEditorAction(lib, "replace", dt, 2, 2)
  local ref = ("$ \\n date is %d%d%d%d%-%d%d%-%d%d : line%d\n"):rep(2)
  ProtectedAssert(GetEditorText():match(ref))

  -- test "function mode"
  dt = { sSearchPat=".+", bRepIsFunc=true, bRegExpr=true,
         sReplacePat=[[return M~=2 and ("%d.%d. %s"):format(M, R, T[0])]]
       }
  SetEditorText("line1\nline2\nline3\n")
  RunEditorAction(lib, "replace", dt, 3, 2)
  AssertEditorText("1.1. line1\nline2\n3.2. line3\n")
  --------
  dt = { sSearchPat="(.)(.)(.)(.)(.)(.)(.)(.)(.)", bRepIsFunc=true,
         bRegExpr=true,
         sReplacePat = "V=(V or 1)*3; return V..T[9]..T[8]..T[7]..T[6]..T[5]..T[4]..T[3]..T[2]..T[1]"
  }
  SetEditorText("abcdefghiabcdefghiabcdefghi")
  RunEditorAction(lib, "replace", dt, 3, 3)
  AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba")
  --------
  dt.sSearchPat = ".+"
  dt.sReplacePat = [[return T[0] .. '--' .. rex.match(T[0], '\\d\\d')]]
  RunEditorAction(lib, "replace", dt, 1, 1)
  AssertEditorText("3ihgfedcba9ihgfedcba27ihgfedcba--27")
  --------
  dt.sReplacePat = ""
  RunEditorAction(lib, "replace", dt, 1, 0)
  --------
  dt.sReplacePat = "return false"
  RunEditorAction(lib, "replace", dt, 1, 0)

  -- test 2-nd return == true
  dt = { sSearchPat="[^\\d\\s]+", bRepIsFunc=true, bRegExpr=true,
         sReplacePat=[[return "string", R==2]]
       }
  SetEditorText("line1\nline2\nline3\n")
  RunEditorAction(lib, "replace", dt, 2, 2)
  AssertEditorText("string1\nstring2\nline3\n")
  ------------------------------------------------------------------------------
end

local function test_Encodings (lib)
  local dt = { bRegExpr=true }
  dt.sSearchPat = "\\w+"
  --------
  SetEditorText(russian_alphabet_utf8)
  dt.sReplacePat = ""
  RunEditorAction(lib, "replace", dt, 1, 1)
  AssertEditorText("")
  --------
  SetEditorText(russian_alphabet_utf8)
  dt.sReplacePat = "\\L$0"
  RunEditorAction(lib, "replace", dt, 1, 1)
  local s = GetEditorText()
  ProtectedAssert(s:sub(1,33)==s:sub(34))
  --------
  SetEditorText(russian_alphabet_utf8)
  dt.sReplacePat = "\\U$0"
  RunEditorAction(lib, "replace", dt, 1, 1)
  local s = GetEditorText()
  ProtectedAssert(s:sub(1,33)==s:sub(34))
  --------
end

local function test_bug_20090208 (lib)
  local dt = { bRegExpr=true, sReplacePat="\n$0" }
  dt.sSearchPat = "\\w+"
  SetEditorText(("my table\n"):rep(5))
  editor.Select(nil,"BTYPE_STREAM",2,1,-1,2)
  RunEditorAction(lib, "replace", dt, 4, 4)
  AssertEditorText("my table\n\nmy \ntable\n\nmy \ntable\nmy table\nmy table\n")
end

local function test_bug_20100802 (lib)
  local dt = { bRegExpr=true, sReplacePat="", bMultiLine=true }
  SetEditorText("line1\nline2\n")
  dt.sSearchPat = "^."
  RunEditorAction(lib, "replace", dt, 2, 2)
  AssertEditorText("ine1\nine2\n")

  SetEditorText("line1\nline2\n")
  dt.sSearchPat = ".$"
  RunEditorAction(lib, "replace", dt, 2, 2)
  AssertEditorText("line\nline\n")
end

local function test_EmptyMatch (lib)
  local dt = { bRegExpr=true, sSearchPat=".*?", sReplacePat="-" }
  dt.sSearchPat = ".*?"
  SetEditorText(("line1\nline2\n"))
  RunEditorAction(lib, "replace", dt, 13, 13)
  AssertEditorText("-l-i-n-e-1-\n-l-i-n-e-2-\n-")

  dt.sSearchPat, dt.sReplacePat = ".*", "1. $0"
  SetEditorText(("line1\nline2\n"))
  RunEditorAction(lib, "replace", dt, 3, 3)
  AssertEditorText("1. line1\n1. line2\n1. ")
end

function selftest.test_editor_multiline_replace (lib)
  assert(type(lfsearch) == "table")
  OpenHelperEditor()
  test_Switches     (lib)
  test_bug_20220618 (lib)
  test_Replace      (lib)
  test_Encodings    (lib)
  test_bug_20090208 (lib)
  test_bug_20100802 (lib)
  test_EmptyMatch   (lib)
  CloseHelperEditor()
end

end

--//////////////////////////////////////////////////////////////////////////////////////////////////

do -- former selftest2.lua

local TestDir = join(TMPDIR, "LFSearch_Test")
local CurDir = assert(panel.GetPanelDirectory(nil, 1)).Name
if CurDir == "" then CurDir = far.GetCurrentDirectory() end
--------------------------------------------------------------------------------

local function CreateTree(dir)
  dir = dir or TestDir
  assert(win.CreateDir(dir, "t"))
end

local function RemoveTree(dir)
  dir = dir or TestDir
  far.RecursiveSearch(dir, "*",
    function(fdata,fullpath)
      if fdata.FileAttributes:find("d") then
        RemoveTree(fullpath)
      else
        assert(win.DeleteFile(fullpath))
      end
    end,
    0) -- don't use flag FRS_RECUR here
  assert(win.RemoveDir(dir))
end

local function AddFile(dir, name, contents)
  dir = dir or TestDir
  local fp = assert(io.open(join(dir,name), "wb"))
  if contents then fp:write(contents) end
  fp:close()
end

local function RemoveFiles(dir, files)
  dir = dir or TestDir
  for _,f in ipairs(files) do
    win.DeleteFile(join(dir,f))
  end
end

local function ReadFile(file)
  local s, fp = nil, io.open(file, "rb")
  if fp then
    s = fp:read("*all")
    fp:close()
  end
  return s
end

local function PrAssert(condition, ...) -- protected assert
  if condition then return condition, ... end
  panel.SetPanelDirectory(nil, 1, CurDir)
  RemoveTree()
  error((...) or "assertion failed", 3)
end
--------------------------------------------------------------------------------

local function test_one_mask (mask, files, num_cs, num_notcs)
  for _,f in ipairs(files) do AddFile(nil, f) end
  PrAssert(panel.SetPanelDirectory(nil, 1, TestDir))
  local dt = { sFileMask = mask, sSearchArea = "OnlyCurrFolder" }
  for k=1, OS_WIN and 1 or 2 do
    local cs = (k == 2)
    dt.bCaseSensFileMask = cs
    local arr = lfsearch.SearchFromPanel(dt)
    PrAssert(arr)
    if cs then PrAssert(#arr == num_cs)
    else PrAssert(#arr == num_notcs)
    end
  end
end

local function test_masks()
  local files = {
    "file-01.txt", "file-02.txt", "FILE-03.TXT",
    "file-01.bin", "file-02.bin", "FILE-03.BIN",
    "файл-01.бин", "файл-02.бин", "ФАЙЛ-03.БИН",
  }
  test_one_mask("*",           {},    0, 0)
  test_one_mask("abc",         files, 0, 0)
  test_one_mask("*abc*",       files, 0, 0)
  test_one_mask("*",           files, 9, 9)
  test_one_mask("*.*",         files, 9, 9)
  test_one_mask("*.txt",       files, 2, 3)
  test_one_mask("*.bin",       files, 2, 3)
  test_one_mask("*.бин",       files, 2, 3)
  test_one_mask("file-01.txt", files, 1, 1)
  test_one_mask("file-01.*",   files, 2, 2)
  test_one_mask("*01.*",       files, 3, 3)
  ------------------------------------------------------------------------------
  test_one_mask("file*,файл*", files, 6, 9)
  test_one_mask("*.txt,*.бин", files, 4, 6)
  test_one_mask("*|*.txt",     files, 7, 6)
  test_one_mask("*|*.txt,*.bin", files, 5, 3)
  test_one_mask("*|*.txt,*.bin,*.бин", files, 3, 0)
  ------------------------------------------------------------------------------
  test_one_mask("/.*/",        files, 9, 9)
  test_one_mask("/.+/",        files, 9, 9)
  test_one_mask("/^f/",        files, 4, 4)
  test_one_mask("/^f/i",       files, 6, 6)
  test_one_mask("/f/",         files, 4, 4)
  test_one_mask("/f/i",        files, 6, 6)
  test_one_mask("/i/",         files, 4, 4)
  test_one_mask("/^i/",        files, 0, 0)
  test_one_mask("/n$/",        files, 2, 2)
  ------------------------------------------------------------------------------
  RemoveFiles(nil, files)
end

local function test_one_search(dt, num)
  local arr = lfsearch.SearchFromPanel(dt)
  PrAssert(arr)
  PrAssert(#arr == num)
end

local function test_search (lib)
  local files = {
    "file-01.txt", "file-02.txt", "file-03.txt",
    "file-01.bin", "file-02.bin", "file-03.bin",
    "файл-01.бин", "файл-02.бин", "файл-03.бин",
  }

  PrAssert(panel.SetPanelDirectory(nil, 1, TestDir))
  for _,f in ipairs(files) do AddFile(nil, f, f) end

  local dt = { sFileMask = "*", sSearchArea = "OnlyCurrFolder" }
  -- dt.iSelectedCodePage = 65001

  dt.sRegexLib = lib

  dt.bRegExpr = nil
  dt.sSearchPat = nil; test_one_search(dt, 9)
  dt.sSearchPat = ".."; test_one_search(dt, 0)
  dt.sSearchPat = "file-02.txt"; test_one_search(dt, 1)

  dt.bRegExpr = true
  dt.sSearchPat = nil; test_one_search(dt, 9)
  dt.sSearchPat = ".."; test_one_search(dt, 9)
  dt.sSearchPat = "file"; test_one_search(dt, 6)
  dt.sSearchPat = "файл"; test_one_search(dt, 3)

  dt.bInverseSearch = true
  dt.sSearchPat = nil; test_one_search(dt, 9)
  dt.sSearchPat = ".."; test_one_search(dt, 0)
  dt.sSearchPat = "file"; test_one_search(dt, 3)
  dt.sSearchPat = "файл"; test_one_search(dt, 6)

  dt.bInverseSearch = nil
  dt.bMultiPatterns = true
  dt.sSearchPat = "1 txt";       test_one_search(dt, 5)
  dt.sSearchPat = "+1 +txt";     test_one_search(dt, 1)
  dt.sSearchPat = "-1 -бин";     test_one_search(dt, 4)
  dt.sSearchPat = "-123";        test_one_search(dt, 9)
  dt.sSearchPat = "123";         test_one_search(dt, 0)
  dt.sSearchPat = "+123";        test_one_search(dt, 0)
  dt.sSearchPat = "-.";          test_one_search(dt, 0)
  dt.sSearchPat = "i й -01";     test_one_search(dt, 6)
  dt.sSearchPat = "+f +02 t";    test_one_search(dt, 1)
  dt.sSearchPat = "+f +02 t -x"; test_one_search(dt, 0)
  dt.sSearchPat = "+f +02 t -и"; test_one_search(dt, 1)

  RemoveFiles(nil, files)
end

local function test_replace (lib)
  local files = {
    "file-01.txt", "file-02.txt", "file-03.txt",
    "file-01.bin", "file-02.bin", "file-03.bin",
    "файл-01.бин", "файл-02.бин", "файл-03.бин",
  }

  PrAssert(panel.SetPanelDirectory(nil, 1, TestDir))

  -- a file will contain 4 lines with its name in each line
  local function AddMyFiles()
    for _,f in ipairs(files) do AddFile(nil, f, (f.."\n"):rep(4)) end
  end

  local dt = { sFileMask="*", sSearchArea="OnlyCurrFolder", sRegexLib=lib, bRegExpr=true }
  dt.sSearchPat = "(.)(.)"
  dt.sReplacePat = "$2$1$0"
  local refReplacePat = "%2%1%0"

  local function MyTest (dt, common_ref)
    for _,f in ipairs(files) do
      local ref = common_ref or (f:gsub(dt.sSearchPat,refReplacePat).."\n"):rep(4)
      PrAssert(ref == ReadFile(join(TestDir,f)))
    end
  end

  -- Test simple regexp replace
  AddMyFiles()
  lfsearch.ReplaceFromPanel(dt)
  MyTest(dt)

  -- test "function mode"
  AddMyFiles()
  local dtfm = { sFileMask="*", sSearchArea="OnlyCurrFolder", sRegexLib=lib,
         sSearchPat=".+", bRepIsFunc=true, bRegExpr=true,
         sReplacePat=[[return ("%d.%d.%d.line;"):format(LN, M, R)]]
       }
  lfsearch.ReplaceFromPanel(dtfm)
  MyTest(dtfm, "1.1.1.line;\n2.2.2.line;\n3.3.3.line;\n4.4.4.line;\n")

  -- Test named groups
  AddMyFiles()
  local dt2 = setmetatable({}, {__index=dt})
  dt2.sSearchPat = lib=="far" and "(?{first}.)(?{second}.)" or "(?<first>.)(?<second>.)"
  dt2.sReplacePat = "${second}${first}$0"
  lfsearch.ReplaceFromPanel(dt2)
  MyTest(dt)

  -- Same test but in function mode
  AddMyFiles()
  dt2.bRepIsFunc = true
  dt2.sReplacePat = "return T.second .. T.first .. T[0]"
  lfsearch.ReplaceFromPanel(dt2)
  MyTest(dt)

  -- Test custom user choice function
  AddMyFiles()
  dt.bConfirmReplace = true

  for _,ret in ipairs {"no","fCancel","cancel"} do
    dt.fUserChoiceFuncP = function() return ret end
    lfsearch.ReplaceFromPanel(dt)
    for _,f in ipairs(files) do
      local ref = (f.."\n"):rep(4)
      PrAssert(ref == ReadFile(join(TestDir,f)))
    end
  end

  for _,ret in ipairs {"yes","fAll","all"} do
    dt.fUserChoiceFuncP = function() return ret end
    AddMyFiles()
    lfsearch.ReplaceFromPanel(dt)
    MyTest(dt)
  end

  RemoveFiles(nil, files)
end

local function test_dir_filter()
  local root_dir = join(TestDir, "dir_filter")
  CreateTree(join(root_dir, "dir1", "subdir1"))
  CreateTree(join(root_dir, "dir1", "subdir2"))
  CreateTree(join(root_dir, "dir2", "subdir1"))
  CreateTree(join(root_dir, "dir2", "subdir2"))
  far.RecursiveSearch(TestDir, "*", function(item, fullpath)
    if item.FileAttributes:find"d" then
      AddFile(fullpath, "file1.txt")
      AddFile(fullpath, "file2.txt")
    end
  end, "FRS_RECUR")

  PrAssert(panel.SetPanelDirectory(nil, 1, root_dir))

  local dt = { sFileMask = "*", sSearchArea = "FromCurrFolder" }

  local function test (use, mask, fullpath1, exmask, fullpath2, ref)
   dt.bUseDirFilter = use
   dt.sDirMask = mask
   dt.bDirMask_ProcessPath = fullpath1
   dt.sDirExMask = exmask
   dt.bDirExMask_ProcessPath = fullpath2
   test_one_search(dt, ref)
  end

  test(false,      nil,       false,      nil,        false,    14) -- filters are disabled
  test(false,      "aaa",     false,      "*",        false,    14) -- ditto

  test(true,       nil,       false,      nil,        false,    14) -- filters not specified
  test(true,       "",        false,      "",         false,    14) -- ditto
  test(true,       "subdir?", false,      "",         false,     8) -- 4 dirs * 2 files/dir
  test(true,       "subdir?", true,       "",         false,     0) -- no match with full path
  test(true,       "subdir*", true,       "",         false,     0) -- ditto

  test(true,       "",        false,      "subdir?",  false,     6) -- skip 4 dirs * 2 files/dir
  test(true,       "",        false,      "subdir?",  true,     14) -- no match with full path
  test(true,       "",        false,      "*subdir*", true,      6) -- skip 4 dirs * 2 files/dir
  test(true,       "",        false,      "*subdir*", false,     6) -- ditto

  test(true,       "",        false,      "dir1",     false,     8) -- skip 3 dirs * 2 files/dir
  test(true,       "",        false,      "dir?",     false,     2) -- skip 6 dirs * 2 files/dir
  test(true,       "",        false,      "sub*",     false,     6) -- skip 4 dirs * 2 files/dir

  RemoveTree(root_dir)
end

local function test_panel_encodings (lib)
  assert(win.GetOEMCP() == 866, "this test requires OEM codepage to be 866")
  assert(win.GetACP() == 1251, "this test requires ANSI codepage to be 1251")

  local dir = os.getenv("FARHOME").."/Plugins/luafar/lua_share/far2/test/codepage"
  PrAssert(panel.SetPanelDirectory(nil, 1, dir))

  local total = 0
  for k=1,10000 do
    local item = panel.GetPanelItem(nil,1,k)
    if not item then break end
    if not item.FileAttributes:find("d") then
      local enc = item.FileName:match("^%d+")
      if enc and enc ~= "65000" then -- skip UTF-7
        total = total + 1
      end
    end
  end
  PrAssert(total > 0)

  local dt = {
    sFileMask         = "/^\\d+.*\\.txt$/";
    sSearchArea       = "OnlyCurrFolder";
    iSelectedCodePage = -1; -- default code pages
    sRegexLib         = lib;
  }

  for k=1,2 do
    dt.sSearchPat = k==1 and "foobar" or "вхождение"
    local arr = lfsearch.SearchFromPanel(dt)
    PrAssert(arr and #arr == (k==1 and 0 or total))
  end
end

function selftest.test_panels_search_replace (lib_list)
  assert(type(lfsearch) == "table")
  CreateTree()
  test_masks()
  for _,lib in ipairs(lib_list) do
    test_search(lib)
    test_replace(lib)
    if not OS_WIN then
      test_panel_encodings(lib)
    end
  end
  test_dir_filter()
  panel.SetPanelDirectory(nil, 1, CurDir)
  RemoveTree()
end

end

--//////////////////////////////////////////////////////////////////////////////////////////////////

function selftest.test_all()
  local lib_list = OS_WIN and {"far","oniguruma","pcre","pcre2"} or {"far","oniguruma","pcre"}
  for _,lib in ipairs(lib_list) do
    selftest.test_editor_search_replace(lib)
    selftest.test_editor_multiline_replace(lib)
  end
  selftest.test_panels_search_replace(lib_list)
  far.AdvControl("ACTL_REDRAWALL")
end

-- use as a script (rather than a module)
local arg = ...
if arg == "run" or type(arg)=="table" then
  selftest.test_all()
end

return selftest
