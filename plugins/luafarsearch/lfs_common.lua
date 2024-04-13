-- lfs_common.lua
-- luacheck: globals _Plugin

local M          = require "lfs_message"
local RepLib     = require "lfs_replib"
local sdialog    = require "far2.simpledialog"
local libHistory = require "far2.history"
local serial     = require "shmuz.serial"

local DefaultLogFileName = "\\D{%Y%m%d-%H%M%S}.log"

local band, bnot, bor = bit64.band, bit64.bnot, bit64.bor
local Utf8, Utf16 = win.Utf16ToUtf8, win.Utf8ToUtf16
local uchar = ("").char
local F = far.Flags
local TransformReplacePat = RepLib.TransformReplacePat
local KEEP_DIALOG_OPEN = 0

local function ErrorMsg (text, title)
  far.Message (text, title or M.MError, nil, "w")
end

local function FormatInt (num)
  return tostring(num):reverse():gsub("...", "%1,"):gsub(",$", ""):reverse()
end

local function GotoEditField (hDlg, id)
  local len = hDlg:send("DM_GETTEXT", id):len()
  hDlg:send("DM_SETFOCUS", id)
  hDlg:send("DM_SETCURSORPOS", id, {X=len, Y=0})
  hDlg:send("DM_SETSELECTION", id, {BlockType="BTYPE_STREAM", BlockStartPos=1, BlockWidth=len})
end

local function MakeGsub (mode)
  local sub, len
  if     mode == "widechar"  then sub, len = win.subW, win.lenW
  elseif mode == "byte"      then sub, len = string.sub, string.len
  elseif mode == "multibyte" then sub, len = ("").sub, ("").len
  else return nil
  end

  return function (aSubj, aRegex, aRepFunc, ...)
    local ufind_method = mode=="widechar" and aRegex.ufindW or aRegex.ufind
    local nFound, nReps = 0, 0
    local tOut = {}
    local x, last_to = 1, -1
    local len_limit = 1 + len(aSubj)

    while x <= len_limit do
      local from, to, collect = ufind_method(aRegex, aSubj, x)
      if not from then break end

      if to == last_to then
        -- skip empty match adjacent to previous match
        tOut[#tOut+1] = sub(aSubj, x, x)
        x = x + 1
      else
        last_to = to
        tOut[#tOut+1] = sub(aSubj, x, from-1)
        collect[0] = sub(aSubj, from, to)
        nFound = nFound + 1

        local sRepFinal, ret2 = aRepFunc(collect, ...)
        if type(sRepFinal) == "string" then
          tOut[#tOut+1] = sRepFinal
          nReps = nReps + 1
        else
          tOut[#tOut+1] = sub(aSubj, from, to)
        end

        if from <= to then
          x = to + 1
        else
          tOut[#tOut+1] = sub(aSubj, from, from)
          x = from + 1
        end

        if ret2 then break end
      end
    end
    tOut[#tOut+1] = sub(aSubj, x)
    return table.concat(tOut), nFound, nReps
  end
end

local Gsub  = MakeGsub("byte")
local GsubW = MakeGsub("widechar")
local GsubMB = MakeGsub("multibyte")

local function FormatTime (tm)
  if tm < 0 then tm = 0 end
  local fmt = (tm < 10) and "%.2f" or (tm < 100) and "%.1f" or "%.0f"
  return fmt:format(tm)
end


local function SaveCodePageCombo (hDlg, combo_pos, combo_list, aData, aSaveCurPos)
  if aSaveCurPos then
    local pos = hDlg:send("DM_LISTGETCURPOS", combo_pos).SelectPos
    aData.iSelectedCodePage = combo_list[pos].CodePage
  end
  aData.tCheckedCodePages = {}
  local info = hDlg:send("DM_LISTINFO", combo_pos)
  for i=1,info.ItemsNumber do
    local item = hDlg:send("DM_LISTGETITEM", combo_pos, i)
    if 0 ~= band(item.Flags, F.LIF_CHECKED) then
      local t = hDlg:send("DM_LISTGETDATA", combo_pos, i)
      if t then table.insert(aData.tCheckedCodePages, t) end
    end
  end
end

local function pack_results (from, to, ...)
  if from then return from, to, {...} end
end

local SearchAreas = {
  { name = "FromCurrFolder",  msg = "MSaFromCurrFolder" },
  { name = "OnlyCurrFolder",  msg = "MSaOnlyCurrFolder" },
  { name = "SelectedItems",   msg = "MSaSelectedItems"  },
  { name = "RootFolder",      msg = ""                  },
  { name = "NonRemovDrives",  msg = "MSaNonRemovDrives" },
  { name = "LocalDrives",     msg = "MSaLocalDrives"    },
  { name = "PathFolders",     msg = "MSaPathFolders"    },
}
for k,v in ipairs(SearchAreas) do SearchAreas[v.name]=k end

local function IndexToSearchArea(index)
  index = index or 1
  if index < 1 or index > #SearchAreas then index = 1 end
  return SearchAreas[index].name
end

local function SearchAreaToIndex(area)
  return type(area)=="string" and SearchAreas[area] or 1
end

local function CheckSearchArea(area)
  assert(not area or SearchAreas[area], "invalid search area")
  return SearchAreas[SearchAreaToIndex(area)].name
end

local function GetSearchAreas(aData)
  local Info = panel.GetPanelInfo(nil, 1)
  local bPlugin = band(Info.Flags, F.PFLAGS_PLUGIN) ~= 0
  local RootFolderItem = {}
  if Info.PanelType==F.PTYPE_FILEPANEL and not bPlugin then
    RootFolderItem.Text = M.MSaRootFolder .. panel.GetPanelDirectory(nil,1).Name:sub(1,2)
  else
    RootFolderItem.Text = M.MSaRootFolder
    RootFolderItem.Flags = F.LIF_GRAYED
  end

  local T = {}
  for k,v in ipairs(SearchAreas) do
    T[k] = v.name == "RootFolder" and RootFolderItem or { Text = M[v.msg] }
  end

  local idx = SearchAreaToIndex(aData.sSearchArea)
  if (idx < 1) or (idx > #T) or (T[idx].Flags == F.LIF_GRAYED) then
    idx = 1
  end
  T.SelectIndex = idx
  return T
end


-- Make possible to use <libname>'s dependencies residing in the plugin's directory.
local function require_ex (libname)
  if package.loaded[libname] then
    return package.loaded[libname]
  end
  local oldpath = win.GetEnv("PATH") or ""
  win.SetEnv("PATH", far.PluginStartupInfo().ModuleDir..";"..oldpath)
  local ok, ret2 = pcall(require, libname)
  win.SetEnv("PATH", oldpath)
  if not ok then error(ret2); end
  return ret2
end


--------------------------------------------------------------------------------
-- @param lib_name
--    Either of ("far", "pcre", "pcre2", "oniguruma").
-- @return
--    A table that "mirrors" the specified library's table (via
--    metatable.__index) and that may have its own version of function "new".

--    This function also inserts some methods into the existing methods table
--    of the compiled regex for the specified library.
--    Inserted are methods "ufind" and/or "ufindW", "gsub" and/or "gsubW".
--------------------------------------------------------------------------------
local function GetRegexLib (lib_name)
  local base, deriv = nil, {}
  -----------------------------------------------------------------------------
  if lib_name == "far" then
    base = regex
    local tb_methods = getmetatable(regex.new(".")).__index
    tb_methods.ufind = tb_methods.ufind or
      function (r,subj,init) return pack_results(r:find(subj,init)) end
    tb_methods.ufindW = tb_methods.ufindW or
      function (r,subj,init) return pack_results(r:findW(subj,init)) end
    tb_methods.capturecount = function(r) return r:bracketscount() - 1 end
  -----------------------------------------------------------------------------
  elseif lib_name == "pcre" then
    base = require_ex("rex_pcre")
    local ff = base.flags()
    local CFlags = bor(ff.NEWLINE_ANYCRLF, ff.UTF8)
    local v1, v2 = base.version():match("(%d+)%.(%d+)")
    v1, v2 = tonumber(v1), tonumber(v2)
    if 1000*v1 + v2 >= 8010 then
      CFlags = bor(CFlags, ff.UCP)
    end
    local TF = { i=ff.CASELESS, m=ff.MULTILINE, s=ff.DOTALL, x=ff.EXTENDED, U=ff.UNGREEDY, X=ff.EXTRA }
    deriv.new = function (pat, cf)
      local cflags = CFlags
      if cf then
        for c in cf:gmatch(".") do cflags = bor(cflags, TF[c] or 0) end
      end
      return base.new (pat, cflags)
    end
    local tb_methods = getmetatable(base.new(".")).__index
    tb_methods.ufind = tb_methods.tfind
    tb_methods.gsub = function(patt, subj, rep) return base.gsub(subj, patt, rep) end
    tb_methods.capturecount = function(patt) return patt:fullinfo().CAPTURECOUNT end
  -----------------------------------------------------------------------------
  elseif lib_name == "pcre2" then
    base = require_ex("rex_pcre2")
    local ff = base.flags()
    local CFlags = bor(ff.NEWLINE_ANYCRLF, ff.UTF, ff.UCP)
    local TF = { i=ff.CASELESS, m=ff.MULTILINE, s=ff.DOTALL, x=ff.EXTENDED, U=ff.UNGREEDY }
    deriv.new = function (pat, cf)
      local cflags = CFlags
      if cf then
        for c in cf:gmatch(".") do cflags = bor(cflags, TF[c] or 0) end
      end
      return base.new (pat, cflags)
    end
    local tb_methods = getmetatable(base.new(".")).__index
    tb_methods.ufind = tb_methods.tfind
    tb_methods.gsub = function(patt, subj, rep) return base.gsub(subj, patt, rep) end
    tb_methods.capturecount = function(patt) return patt:patterninfo().CAPTURECOUNT end
  -----------------------------------------------------------------------------
  elseif lib_name == "oniguruma" then
    base = require_ex("rex_onig")
    deriv.new = function (pat, cf) return base.new (Utf16(pat), cf, "UTF16_LE", "PERL_NG") end
    local tb_methods = getmetatable(base.new(".")).__index
    if tb_methods.ufindW == nil then
      local tfindW = tb_methods.tfind
      tb_methods.ufindW = function(r, s, init)
        local from, to, t = tfindW(r, s, 2*init-1)
        if from then from, to = (from+1)/2, to/2; return from, to, t; end
      end
      tb_methods.gsubW = function(patt, subj, rep) return base.gsub(subj, patt, rep) end
    end
    -- tb_methods.capturecount = tb_methods.capturecount -- this method is already available
  -----------------------------------------------------------------------------
  else
    error "unsupported name of regexp library"
  end
  return setmetatable(deriv, {__index=base})
end


-- If cursor is right after the word pick up the word too.
local function GetWordUnderCursor (select)
  local line = editor.GetString()
  local pos = editor.GetInfo().CurPos
  local r = regex.new("(\\w+)")
  local offset = r:find(line.StringText:sub(pos==1 and pos or pos-1, pos))
  if offset then
    local _, last = r:find(line.StringText, pos==1 and pos or (pos+offset-2))
    local from, to, word = r:find(line.StringText:reverse(), line.StringLength-last+1)
    if select then
      editor.Select(nil, "BTYPE_STREAM", nil, line.StringLength-to+1, to-from+1, 1)
    end
    return word:reverse()
  end
end


local function GetReplaceFunction (aReplacePat, is_wide)
  local fSame = function(s) return s end
  local U8 = is_wide and Utf8 or fSame
  local U16 = is_wide and Utf16 or fSame

  if type(aReplacePat) == "function" then
    return is_wide and
      function(collect,nMatch,nReps,nLine) -- this implementation is inefficient as it works in UTF-8 !
        local ccopy = {}
        for k,v in pairs(collect) do
          local key = type(k)=="number" and k or U8(k)
          ccopy[key] = v and U8(v)
        end
        local R1,R2 = aReplacePat(ccopy,nMatch,nReps+1,nLine)
        local tp1 = type(R1)
        if     tp1 == "string" then R1 = U16(R1)
        elseif tp1 == "number" then R1 = U16(tostring(R1))
        end
        return R1, R2
      end or
      function(collect,nMatch,nReps,nLine)
        local R1,R2 = aReplacePat(collect,nMatch,nReps+1,nLine)
        if type(R1)=="number" then R1=tostring(R1) end
        return R1, R2
      end

  elseif type(aReplacePat) == "string" then
    return function() return U16(aReplacePat) end

  elseif type(aReplacePat) == "table" then
    return RepLib.GetReplaceFunction(aReplacePat, is_wide)

  else
    error("invalid type of replace pattern", 2)
  end
end


local function EscapeSearchPattern(pat)
  pat = string.gsub(pat, "[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]", "\\%1")
  return pat
end


local function GetCFlags (aData, bInEditor)
  local cflags = aData.bCaseSens and "" or "i"
  if aData.bRegExpr then
    if aData.bExtended then cflags = cflags.."x" end
    if aData.bFileAsLine then cflags = cflags.."s" end
    if not bInEditor or aData.bMultiLine then cflags = cflags.."m" end
  end
  return cflags
end


local function ProcessSinglePattern (rex, aPattern, aData)
  aPattern = aPattern or ""
  local SearchPat = aPattern
  if not aData.bRegExpr then
    SearchPat = EscapeSearchPattern(SearchPat)
    if aData.bWholeWords then
      if rex.find(aPattern, "^\\w") then SearchPat = "\\b"..SearchPat end
      if rex.find(aPattern, "\\w$") then SearchPat = SearchPat.."\\b" end
    end
  end
  return SearchPat
end


-- There are 2 sequence types recognized:
-- (1) starts with non-space && non-quote, ends before a space
-- (2) enclosed in quotes, may contain inside pairs of quotes, ends before a space
local OnePattern = [[
  ([+\-] | (?! [+\-]))
  (?:
    ([^\s"]\S*) |
    "((?:[^"] | "")+)" (?=\s|$)
  ) |
  (\S)
]]

local function ProcessMultiPatterns (aData, rex)
  local subject = aData.sSearchPat or ""
  local cflags = GetCFlags(aData, false)
  local Plus, Minus, Usual = {}, {}, {}
  local PlusGuard = {}
  local NumPatterns = 0
  for sign, nonQ, Q, tail in regex.gmatch(subject, OnePattern, "x") do
    if tail then error("invalid multi-pattern") end
    local pat = nonQ or Q:gsub([[""]], [["]])
    pat = ProcessSinglePattern(rex, pat, aData)
    if sign == "+" then
      if not PlusGuard[pat] then
        Plus[ rex.new(pat, cflags) ] = true
        PlusGuard[pat] = true
      end
    elseif sign == "-" then
      Minus[#Minus+1] = "(?:"..pat..")"
    else
      Usual[#Usual+1] = "(?:"..pat..")"
    end
    NumPatterns = NumPatterns + 1
  end
  Minus = Minus[1] and table.concat(Minus, "|")
  Usual = Usual[1] and table.concat(Usual, "|")
  Minus = Minus and rex.new(Minus, cflags)
  Usual = Usual and rex.new(Usual, cflags)
  return { Plus=Plus, Minus=Minus, Usual=Usual, NumPatterns=NumPatterns }
end


local function ProcessDialogData (aData, bReplace, bInEditor, bUseMultiPatterns, bSkip)
  local params = {}
  params.bFileAsLine = aData.bFileAsLine
  params.bInverseSearch = aData.bInverseSearch
  params.bConfirmReplace = aData.bConfirmReplace
  params.bWrapAround = aData.bWrapAround
  params.bSearchBack = aData.bSearchBack
  params.bDelEmptyLine = aData.bDelEmptyLine
  params.bDelNonMatchLine = aData.bDelNonMatchLine
  params.bHighlight = aData.bHighlight
  params.sOrigin = aData.sOrigin
  params.sSearchPat = aData.sSearchPat or ""
  params.FileFilter = aData.bUseFileFilter and aData.FileFilter
  ---------------------------------------------------------------------------
  params.Envir = setmetatable({}, {__index=_G})
  params.Envir.dofile = function(fname)
    local f = assert(loadfile(fname))
    return setfenv(f, params.Envir)()
  end
  ---------------------------------------------------------------------------
  local libname = aData.sRegexLib or "far"
  local ok, rex = pcall(GetRegexLib, libname)
  if not ok then
    ErrorMsg(rex, "Error loading '"..libname.."'")
    return
  end
  params.Envir.rex = rex

  if bUseMultiPatterns and aData.bMultiPatterns then
    local ok, ret = pcall(ProcessMultiPatterns, aData, rex)
    if ok then params.tMultiPatterns, params.Regex = ret, rex.new(".")
    else ErrorMsg(ret, M.MSearchPattern..": "..M.MSyntaxError); return nil,"sSearchPat"
    end
  else
    local SearchPat = ProcessSinglePattern(rex, aData.sSearchPat, aData)
    local cflags = GetCFlags(aData, bInEditor)
    if libname=="far" then cflags = cflags.."o"; end -- optimize
    local ok, ret = pcall(rex.new, SearchPat, cflags)
    if not ok then
      ErrorMsg(ret, M.MSearchPattern..": "..M.MSyntaxError)
      return nil,"sSearchPat"
    end
    if bSkip then
      local SkipPat = ProcessSinglePattern(rex, aData.sSkipPat, aData)
      ok, ret = pcall(rex.new, SkipPat, cflags)
      if not ok then
        ErrorMsg(ret, M.MSkipPattern..": "..M.MSyntaxError)
        return nil,"sSkipPat"
        end
      local Pat = "("..SkipPat..")" .. "|" .. "(?:"..SearchPat..")" -- SkipPat has priority over SearchPat
      ret = assert(rex.new(Pat, cflags), "invalid combined reqular expression")
      params.bSkip = true
    end
    params.Regex = ret
  end
  ---------------------------------------------------------------------------
  if bReplace then
    if aData.bRepIsFunc then
      local func, msg = loadstring("local T,M,R,LN = ...\n"..aData.sReplacePat, M.MReplaceFunction)
      if func then params.ReplacePat = setfenv(func, params.Envir)
      else ErrorMsg(msg, M.MReplaceFunction..": "..M.MSyntaxError); return nil,"sReplacePat"
      end
    else
      params.ReplacePat = aData.sReplacePat
      if aData.bRegExpr then
        local repl, msg = TransformReplacePat(params.ReplacePat)
        if repl then
          if repl.MaxGroupNumber > params.Regex:capturecount() then
            ErrorMsg(M.MReplacePattern..": "..M.MErrorGroupNumber); return nil,"sReplacePat"
          end
          params.ReplacePat = repl
        else
          ErrorMsg(msg, M.MReplacePattern..": "..M.MSyntaxError); return nil,"sReplacePat"
        end
      end
    end
  end
  ---------------------------------------------------------------------------
  if aData.bAdvanced then
    if aData.sFilterFunc then
      local func, msg = loadstring("local s,n=...\n"..aData.sFilterFunc, "Line Filter")
      if func then params.FilterFunc = setfenv(func, params.Envir)
      else ErrorMsg(msg, "Line Filter function: " .. M.MSyntaxError); return nil,"sFilterFunc"
      end
    end
    -------------------------------------------------------------------------
    local func, msg = loadstring (aData.sInitFunc or "", "Initial")
    if func then params.InitFunc = setfenv(func, params.Envir)
    else ErrorMsg(msg, "Initial Function: " .. M.MSyntaxError); return nil,"sInitFunc"
    end
    func, msg = loadstring (aData.sFinalFunc or "", "Final")
    if func then params.FinalFunc = setfenv(func, params.Envir)
    else ErrorMsg(msg, "Final Function: " .. M.MSyntaxError); return nil,"sFinalFunc"
    end
    -------------------------------------------------------------------------
  end
  return params
end


local function GetDialogHistoryValue (key, index)
  local dh = libHistory.dialoghistory(key, index, index)
  return dh and dh[1] and dh[1].Name
end


local function GetDialogHistory (key)
  local dh = libHistory.dialoghistory(key, -1, -1)
  return dh and dh[1] and dh[1].Name
end


local SRFrame = {}
SRFrame.Libs = {"far", "oniguruma", "pcre", "pcre2"}
local SRFrameMeta = {__index = SRFrame}

local function CreateSRFrame (Items, aData, bInEditor, bScriptCall)
  local self = {Items=Items, Data=aData, bInEditor=bInEditor, bScriptCall=bScriptCall}
  return setmetatable(self, SRFrameMeta)
end

function SRFrame:SetDialogObject (dlg, Pos, Elem)
  self.Dlg = dlg
  self.Pos,self.Elem = Pos,Elem
end

function SRFrame:InsertInDialog (aPanelsDialog, aOp)
  local insert = table.insert
  local Items = self.Items
  local md = 40 -- "middle"
  ------------------------------------------------------------------------------
  if aPanelsDialog then
    insert(Items, { tp="text"; text=M.MDlgFileMask; })
    insert(Items, { tp="edit"; name="sFileMask"; hist="Masks"; uselasthistory=1; })
  end
  ------------------------------------------------------------------------------
  insert(Items, { tp="text"; text=M.MDlgSearchPat; })
  insert(Items, { tp="edit"; name="sSearchPat"; hist="SearchText"; })
  ------------------------------------------------------------------------------
  if aPanelsDialog and aOp == "grep" then
    insert(Items, { tp="text";  text=M.MDlgSkipPat; })
    insert(Items, { tp="edit";  name="sSkipPat";  hist="SkipText"; })
  end
  ------------------------------------------------------------------------------
  if aOp == "replace" then
    insert(Items, { tp="text";  text=M.MDlgReplacePat; })
    insert(Items, { tp="edit";  name="sReplacePat"; hist="ReplaceText"; })
    insert(Items, { tp="chbox"; name="bRepIsFunc";         x1=7;         text=M.MDlgRepIsFunc; })
    if aPanelsDialog then
      insert(Items, { tp="chbox"; name="bMakeBackupCopy";  x1=27, y1=""; text=M.MDlgMakeBackupCopy; })
      insert(Items, { tp="chbox"; name="bConfirmReplace";  x1=48, y1=""; text=M.MDlgConfirmReplace; })
    else
      insert(Items, { tp="chbox"; name="bDelEmptyLine";    x1=md, y1=""; text=M.MDlgDelEmptyLine; })
      insert(Items, { tp="chbox"; name="bConfirmReplace";  x1=7,         text=M.MDlgConfirmReplace; })
      insert(Items, { tp="chbox"; name="bDelNonMatchLine"; x1=md, y1=""; text=M.MDlgDelNonMatchLine; })
    end
  end
  ------------------------------------------------------------------------------
  insert(Items, { tp="sep"; })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bRegExpr";                         text=M.MDlgRegExpr;  })
  insert(Items, { tp="text";                         y1=""; x1=md;     text=M.MDlgRegexLib; })
  local x1 = md + M.MDlgRegexLib:gsub("&",""):len() + 1;
  insert(Items, { tp="combobox"; name="cmbRegexLib"; y1=""; x1=x1; width=14; dropdown=1; noload=1;
           list = { {Text="Far regex"}, {Text="Oniguruma"}, {Text="PCRE"}, {Text="PCRE2"} };  })
  ------------------------------------------------------------------------------
  insert(Items, { tp="chbox"; name="bCaseSens";                        text=M.MDlgCaseSens; })
  insert(Items, { tp="chbox"; name="bExtended"; x1=md; y1="";          text=M.MDlgExtended; })
  insert(Items, { tp="chbox"; name="bWholeWords";                      text=M.MDlgWholeWords; })
  ------------------------------------------------------------------------------
  if aPanelsDialog and aOp=="search" then
    insert(Items, { tp="chbox"; name="bFileAsLine";    x1=md; y1="";   text=M.MDlgFileAsLine;    })
    insert(Items, { tp="chbox"; name="bMultiPatterns";                 text=M.MDlgMultiPatterns; })
    insert(Items, { tp="chbox"; name="bInverseSearch"; x1=md; y1="";   text=M.MDlgInverseSearch; })
  end
end

function SRFrame:CheckRegexInit (hDlg, Data)
  local Pos = self.Pos
  hDlg:send("DM_SETCHECK", Pos.bWholeWords, Data.bWholeWords and 1 or 0)
  hDlg:send("DM_SETCHECK", Pos.bExtended,   Data.bExtended and 1 or 0)
  hDlg:send("DM_SETCHECK", Pos.bCaseSens,   Data.bCaseSens and 1 or 0)
  self:CheckRegexChange(hDlg)
end

function SRFrame:CheckRegexChange (hDlg)
  local Pos = self.Pos
  local bRegex = hDlg:send("DM_GETCHECK", Pos.bRegExpr)

  if bRegex==1 then hDlg:send("DM_SETCHECK", Pos.bWholeWords, 0) end
  hDlg:send("DM_ENABLE", Pos.bWholeWords, bRegex==0 and 1 or 0)

  if bRegex==0 then hDlg:send("DM_SETCHECK", Pos.bExtended, 0) end
  hDlg:send("DM_ENABLE", Pos.bExtended, bRegex)

  if Pos.bFileAsLine then
    if bRegex==0 then hDlg:send("DM_SETCHECK", Pos.bFileAsLine, 0) end
    hDlg:send("DM_ENABLE", Pos.bFileAsLine, bRegex)
  end
end

function SRFrame:CheckAdvancedEnab (hDlg)
  local Pos = self.Pos
  if Pos.bAdvanced then
    hDlg:send("DM_ENABLEREDRAW", 0)
    local bEnab = hDlg:send("DM_GETCHECK", Pos.bAdvanced)
    hDlg:send("DM_ENABLE", Pos.labInitFunc,   bEnab)
    hDlg:send("DM_ENABLE", Pos.sInitFunc,     bEnab)
    hDlg:send("DM_ENABLE", Pos.labFinalFunc,  bEnab)
    hDlg:send("DM_ENABLE", Pos.sFinalFunc,    bEnab)
    if Pos.sFilterFunc then
      hDlg:send("DM_ENABLE", Pos.labFilterFunc, bEnab)
      hDlg:send("DM_ENABLE", Pos.sFilterFunc,   bEnab)
    end
    hDlg:send("DM_ENABLEREDRAW", 1)
  end
end

function SRFrame:CheckWrapAround (hDlg)
  local Pos = self.Pos
  if self.bInEditor and Pos.bWrapAround then
    local bEnab = hDlg:send("DM_GETCHECK", Pos.rScopeGlobal)==1 and hDlg:send("DM_GETCHECK", Pos.rOriginCursor)==1
    hDlg:send("DM_ENABLE", Pos.bWrapAround, bEnab and 1 or 0)
  end
end

function SRFrame:OnDataLoaded (aData)
  local Pos = self.Pos
  local Items = self.Items
  local bInEditor = self.bInEditor

  if not self.bScriptCall then
    if bInEditor then
      local config = _Plugin.History:field("config")
      if config.rPickHistory then
        Items[Pos.sSearchPat].uselasthistory = true
      elseif config.rPickNowhere then
        Items[Pos.sSearchPat].val = ""
        if Pos.sReplacePat then Items[Pos.sReplacePat].val = ""; end
      else -- (default) if config.rPickEditor then
        Items[Pos.sSearchPat].val = GetWordUnderCursor() or ""
      end
    else
      Items[Pos.sSearchPat].val =
        aData.sSearchPat == "" and ""
      --or GetDialogHistory("SearchText")
        or aData.sSearchPat
        or ""
    end
  end

  local item = Items[Pos.cmbRegexLib]
  item.val = 1
  for i,v in ipairs(self.Libs) do
    if aData.sRegexLib == v then item.val = i; break; end
  end
end


function SRFrame:CompleteLoadData (hDlg, Data, LoadFromPreset)
  local Pos = self.Pos
  local bScript = self.bScriptCall or LoadFromPreset

  if self.bInEditor then
    -- Set scope
    local EI = editor.GetInfo()
    if EI.BlockType == F.BTYPE_NONE then
      hDlg:send("DM_SETCHECK", Pos.rScopeGlobal, 1)
      hDlg:send("DM_ENABLE", Pos.rScopeBlock, 0)
    else
      local bScopeBlock
      local bForceBlock = _Plugin.History:field("config").bForceScopeToBlock
      if bScript or not bForceBlock then
        bScopeBlock = (Data.sScope == "block")
      else
        local line = editor.GetString(nil,EI.BlockStartLine+1) -- test the 2-nd selected line
        bScopeBlock = line and line.SelStart>0
      end
      hDlg:send("DM_SETCHECK", Pos[bScopeBlock and "rScopeBlock" or "rScopeGlobal"], 1)
    end

    -- Set origin
    local key = bScript and "sOrigin"
                or hDlg:send("DM_GETCHECK", Pos.rScopeGlobal)==1 and "sOriginInGlobal"
                or "sOriginInBlock"
    local name = Data[key]=="scope" and "rOriginScope" or "rOriginCursor"
    hDlg:send("DM_SETCHECK", Pos[name], 1)

    self:CheckWrapAround(hDlg)
  end

  self:CheckAdvancedEnab(hDlg)
  self:CheckRegexInit(hDlg, Data)
end


function SRFrame:SaveDataDyn (hDlg, Data)
  local state = self.Dlg:GetDialogState(hDlg)
  ------------------------------------------------------------------------
  for k,v in pairs(state) do Data[k]=v end
  ------------------------------------------------------------------------
  if self.bInEditor then
    Data.sScope = state.rScopeGlobal and "global" or "block"
    Data.sOrigin = state.rOriginCursor and "cursor" or "scope"

    if not self.bScriptCall then
      local key = Data.sScope == "global" and "sOriginInGlobal" or "sOriginInBlock"
      Data[key] = Data.sOrigin -- to be passed to execution
    end
  else
    Data.sSearchArea = IndexToSearchArea(state.cmbSearchArea)
  end
  ------------------------------------------------------------------------
  Data.sRegexLib = self.Libs[ state.cmbRegexLib ]
end

function SRFrame:GetLibName (hDlg)
  local pos = hDlg:send("DM_LISTGETCURPOS", self.Pos.cmbRegexLib)
  return self.Libs[pos.SelectPos]
end

function SRFrame:DlgProc (hDlg, msg, param1, param2)
  local Pos = self.Pos
  local Data, bInEditor = self.Data, self.bInEditor
  local bReplace = Pos.sReplacePat
  ----------------------------------------------------------------------------
  if msg == F.DN_INITDIALOG then
    assert(self.Dlg, "self.Dlg not set; probably Frame:SetDialogObject was not called")
    self:CompleteLoadData(hDlg, Data, false)
    if _Plugin.sSearchWord and not self.bScriptCall then
      if _Plugin.History:field("config").rPickHistory then
        hDlg:send("DM_SETTEXT", Pos.sSearchPat, _Plugin.sSearchWord)
      end
      hDlg:send("DM_ADDHISTORY", Pos.sSearchPat, _Plugin.sSearchWord)
      _Plugin.sSearchWord = nil
    end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_BTNCLICK then
    if param1==Pos.bRegExpr then
      self:CheckRegexChange(hDlg)
    else
      if bInEditor then
        self:CheckWrapAround(hDlg)
      end
      if Pos.bAdvanced and param1==Pos.bAdvanced then
        self:CheckAdvancedEnab(hDlg)
      end
    end
  ----------------------------------------------------------------------------
  elseif msg == "EVENT_KEY" and param2 == "F4" then
    if param1 == Pos.sReplacePat and hDlg:send("DM_GETCHECK", Pos.bRepIsFunc) == 1 then
      local txt = sdialog.OpenInEditor(hDlg:send("DM_GETTEXT", Pos.sReplacePat), "lua")
      if txt then hDlg:send("DM_SETTEXT", Pos.sReplacePat, txt) end
      return true
    end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_EDITCHANGE then
    if param1 == Pos.cmbRegexLib then self:CheckRegexChange(hDlg) end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_CLOSE then
    if Pos.btnOk      and param1 == Pos.btnOk       or
       Pos.btnCount   and param1 == Pos.btnCount    or
       Pos.btnShowAll and param1 == Pos.btnShowAll
    then
      if bInEditor then
        if hDlg:send("DM_GETTEXT", Pos.sSearchPat) == "" then
          ErrorMsg(M.MSearchFieldEmpty)
          GotoEditField(hDlg, Pos.sSearchPat)
          return KEEP_DIALOG_OPEN
        end
      end
      local tmpdata, key = {}
      for k,v in pairs(Data) do tmpdata[k]=v end
      self:SaveDataDyn(hDlg, tmpdata)
      local bSkip = Pos.sSkipPat and tmpdata.sSkipPat ~= ""
      self.close_params, key = ProcessDialogData(tmpdata, bReplace, bInEditor, Pos.bMultiPatterns, bSkip)
      if self.close_params then
        for k,v in pairs(tmpdata) do Data[k]=v end
        hDlg:send("DM_ADDHISTORY", Pos.sSearchPat, Data.sSearchPat)
        if Pos.sReplacePat then hDlg:send("DM_ADDHISTORY", Pos.sReplacePat, Data.sReplacePat) end
        if Pos.sSkipPat    then hDlg:send("DM_ADDHISTORY", Pos.sSkipPat,    Data.sSkipPat)    end
      else
        if key and Pos[key] then GotoEditField(hDlg, Pos[key]) end
        return KEEP_DIALOG_OPEN
      end

    end
  end
end


function SRFrame:DoPresets (hDlg)
  local Pos = self.Pos
  local HistPresetNames = _Plugin.DialogHistoryPath .. "Presets"
  hDlg:send("DM_SHOWDIALOG", 0)
  local props = { Title=M.MTitlePresets, Bottom = "F1", HelpTopic="Presets", }
  local presets = _Plugin.History:field("presets")
  local bkeys = {
    {  action="Save";    BreakKey="F2";      },
    {  action="SaveAs";  BreakKey="INSERT";  },
    {  action="Delete";  BreakKey="DELETE";  },
    {  action="Rename";  BreakKey="F6";      },
    {  action="Export";  BreakKey="C+S";     },
    {  action="Import";  BreakKey="C+O";     },
  }

  while true do
    local items = {}
    for name, preset in pairs(presets) do
      local t = { text=name, preset=preset }
      items[#items+1] = t
      if name == self.PresetName then t.selected,t.checked = true,true; end
    end
    table.sort(items, function(a,b) return win.CompareString(a.text,b.text,nil,"cS") < 0; end)
    ----------------------------------------------------------------------------
    local item, pos = far.Menu(props, items, bkeys)
    ----------------------------------------------------------------------------
    if not item then break end
    ----------------------------------------------------------------------------
    props.SelectIndex = pos
    if item.preset then
      self.PresetName = item.text
      local data = item.preset
      self.Dlg:SetDialogState(hDlg, data)

      if Pos.cmbSearchArea and data.sSearchArea then
        hDlg:send("DM_LISTSETCURPOS", Pos.cmbSearchArea, {SelectPos=SearchAreaToIndex(data.sSearchArea)} )
      end

      if Pos.cmbCodePage then
        local info = hDlg:send("DM_LISTINFO", Pos.cmbCodePage)
        if data.tCheckedCodePages then
          local map = {}
          for i,v in ipairs(data.tCheckedCodePages) do map[v]=i end
          for i=3,info.ItemsNumber do -- skip "Default code pages" and "Checked code pages"
            local cp = hDlg:send("DM_LISTGETDATA", Pos.cmbCodePage, i)
            if cp then
              local listItem = hDlg:send("DM_LISTGETITEM", Pos.cmbCodePage, i)
              listItem.Index = i
              if map[cp] then listItem.Flags = bor(listItem.Flags, F.LIF_CHECKED)
              else listItem.Flags = band(listItem.Flags, bnot(F.LIF_CHECKED))
              end
              hDlg:send("DM_LISTUPDATE", Pos.cmbCodePage, listItem)
            end
          end
        end
        if data.iSelectedCodePage then
          local scp = data.iSelectedCodePage
          for i=1,info.ItemsNumber do
            if scp == hDlg:send("DM_LISTGETDATA", Pos.cmbCodePage, i) then
              hDlg:send("DM_LISTSETCURPOS", Pos.cmbCodePage, {SelectPos=i})
              break
            end
          end
        end
      end

      local index
      for i,v in ipairs(self.Libs) do
        if data.sRegexLib == v then index = i; break; end
      end
      hDlg:send("DM_LISTSETCURPOS", Pos.cmbRegexLib, {SelectPos=index or 1})

      self:CompleteLoadData(hDlg, data, true)
      break
    ----------------------------------------------------------------------------
    elseif item.action == "Save" or item.action == "SaveAs" then
      local pure_save_name = item.action == "Save" and self.PresetName
      local name = pure_save_name or
        far.InputBox(nil, M.MSavePreset, M.MEnterPresetName, HistPresetNames,
                     self.PresetName, nil, nil, F.FIB_NOUSELASTHISTORY)
      if name then
        if pure_save_name or not presets[name] or
          far.Message(M.MPresetOverwrite, M.MConfirm, M.MBtnYesNo, "w") == 1
        then
          props.SelectIndex = nil
          local data = self.Dlg:GetDialogState(hDlg)
          presets[name] = data
          self.PresetName = name
          self:SaveDataDyn(hDlg, data)
          if Pos.cmbCodePage then
            SaveCodePageCombo(hDlg, Pos.cmbCodePage, self.Items[Pos.cmbCodePage].list, data, true)
          end
          _Plugin.History:save()
          if pure_save_name then
            far.Message(M.MPresetWasSaved, M.MMenuTitle)
            break
          end
        end
      end
    ----------------------------------------------------------------------------
    elseif item.action == "Delete" and items[1] then
      local name = items[pos].text
      local msg = ([[%s "%s"?]]):format(M.MDeletePreset, name)
      if far.Message(msg, M.MConfirm, M.MBtnYesNo, "w") == 1 then
        if pos == #items then
          props.SelectIndex = pos-1
        end
        if self.PresetName == name then
          self.PresetName = nil
        end
        presets[name] = nil
        _Plugin.History:save()
      end
    ----------------------------------------------------------------------------
    elseif item.action == "Rename" and items[1] then
      local oldname = items[pos].text
      local name = far.InputBox(nil, M.MRenamePreset, M.MEnterPresetName, HistPresetNames, oldname)
      if name and name ~= oldname then
        if not presets[name] or far.Message(M.MPresetOverwrite, M.MConfirm, M.MBtnYesNo, "w") == 1 then
          if self.PresetName == oldname then
            self.PresetName = name
          end
          presets[name], presets[oldname] = presets[oldname], nil
          _Plugin.History:save()
        end
      end
    ----------------------------------------------------------------------------
    elseif item.action == "Export" and items[1] then
      local fname = far.InputBox(nil, M.MPresetExportTitle, M.MPresetExportPrompt)
      if fname then
        fname = far.ConvertPath(fname)
        if not win.GetFileAttr(fname) or 1==far.Message(
          fname.."\n"..M.MPresetOverwriteQuery, M.MWarning, ";YesNo", "w")
        then
          local fp = io.open(fname, "w")
          if fp then
            fp:write("local presets\n", serial.SaveToString("presets",presets), "\nreturn presets")
            fp:close()
            far.Message(M.MPresetExportSuccess, M.MMenuTitle)
          else
            ErrorMsg(M.MPresetExportFailure)
          end
        end
      end
    ----------------------------------------------------------------------------
    elseif item.action == "Import" then
      local fname = far.InputBox(nil, M.MPresetImportTitle, M.MPresetImportPrompt)
      if fname then
        local func, msg = loadfile(far.ConvertPath(fname))
        if func then
          local t = setfenv(func, {})()
          if type(t) == "table" then
            for k,v in pairs(t) do
              if type(k)=="string" and type(v)=="table" then
                if not presets[k] then
                  presets[k] = v
                else
                  local root = k:match("%(%d+%)(.*)") or k
                  for m=1,1000 do
                    local k2 = ("(%d)%s"):format(m, root)
                    if not presets[k2] then
                      presets[k2] = v; break
                    end
                  end
                end
              end
            end
            _Plugin.History:save()
          else
            ErrorMsg(M.MPresetImportDataNotTable)
          end
        else
          ErrorMsg(msg)
        end
      end
    ----------------------------------------------------------------------------
    end
  end
  hDlg:send("DM_SHOWDIALOG", 1)
end


local function TransformLogFilePat (aStr)
  local T = { MaxGroupNumber=0 }
  local patt = [[
    \\D \{ ([^\}]+) \} |
    (.) |
    ($)
  ]]

  for date,char,dollar in regex.gmatch(aStr,patt,"sx") do
    if date then
      T[#T+1] = { "date", date }
    elseif char then
      if T[#T] and T[#T][1]=="literal" then T[#T][2] = T[#T][2] .. char
      else T[#T+1] = { "literal", char }
      end
    elseif dollar then
      if not T[1] then return nil, "empty pattern" end
    end

    local curr = T[#T]
    if curr[1]=="literal" then
      local c = curr[2]:match("[\\/:*?\"<>|%c%z]")
      if c then
        return nil, "invalid filename character: "..c
      end
    end
  end
  return T
end


local function ConfigDialog()
  local HIST_LOG = _Plugin.DialogHistoryPath .. "LogFileName"
  local X1 = 5 + (M.MRenameLogFileName):len()

  local Items = {
    guid="6C2BC7AF-8739-499E-BFA2-7E967B0BDDA9";
    help="Configuration";
    { tp="dbox";  text=M.MConfigTitleCommon;                            },
    { tp="text";  text=M.MRenameLogFileName; ystep=2;                   },
    { tp="edit";  hist=HIST_LOG; uselasthistory=1; name="sLogFileName";
                  text=DefaultLogFileName; y1=""; x1=X1;                },
    { tp="sep";   ystep=2;                                              },
    { tp="butt";  centergroup=1; text=M.MOk;     default=1;             },
    { tp="butt";  centergroup=1; text=M.MCancel; cancel=1;              },
  }
  ----------------------------------------------------------------------------
  local Dlg = sdialog.New(Items)

  local function closeaction (hDlg, param1, state)
    local ok, errmsg = TransformLogFilePat(state.sLogFileName)
    if not ok then
      ErrorMsg(errmsg, "Log file name")
      return KEEP_DIALOG_OPEN
    end
  end

  function Items.proc (hDlg, Msg, Par1, Par2)
    if Msg == F.DN_CLOSE then
      return closeaction(hDlg, Par1, Par2)
    end
  end

  local Data = _Plugin.History:field("config")
  Dlg:LoadData(Data)
  local state = Dlg:Run()
  if state then
    Dlg:SaveData(state, Data)
    _Plugin.History:save()
    return true
  end
end


local function EditorConfigDialog()
  local offset = 5 + math.max(M.MBtnHighlightColor:len(),
                              M.MBtnGrepLineNumMatchedColor:len(),
                              M.MBtnGrepLineNumContextColor:len()) + 5
  ----------------------------------------------------------------------------
  local Items = {
    guid = "69E53E0A-D63E-40CC-B153-602E9633956E";
    width = 76;
    help = "Contents";
    {tp="dbox";  text=M.MConfigTitleEditor; },
    {tp="chbox"; name="bForceScopeToBlock";  text=M.MOptForceScopeToBlock; },
    {tp="chbox"; name="bSelectFound";        text=M.MOptSelectFound; },
    {tp="chbox"; name="bShowSpentTime";      text=M.MOptShowSpentTime; },
    {tp="text";  text=M.MOptPickFrom; ystep=2; },
    {tp="rbutt"; x1=7;  name="rPickEditor";  text=M.MOptPickEditor; group=1; val=1; },
    {tp="rbutt"; x1=27; name="rPickHistory"; text=M.MOptPickHistory; y1=""; },
    {tp="rbutt"; x1=47; name="rPickNowhere"; text=M.MOptPickNowhere; y1=""; },

    {tp="sep"; ystep=2; text=M.MSepHighlightColors; },
    {tp="butt"; name="btnHighlight"; text=M.MBtnHighlightColor; btnnoclose=1; },
    {tp="text"; name="labHighlight"; text=M.MTextSample; x1=offset; y1=""; width=M.MTextSample:len(); },
    {tp="butt"; name="btnGrepLNum1"; text=M.MBtnGrepLineNumMatchedColor; btnnoclose=1; },
    {tp="text"; name="labGrepLNum1"; text=M.MTextSample; x1=offset; y1=""; width=M.MTextSample:len(); },
    {tp="butt"; name="btnGrepLNum2"; text=M.MBtnGrepLineNumContextColor; btnnoclose=1; },
    {tp="text"; name="labGrepLNum2"; text=M.MTextSample; x1=offset; y1=""; width=M.MTextSample:len(); },

    {tp="sep"; },
    {tp="butt"; centergroup=1; text=M.MOk;    default=1; },
    {tp="butt"; centergroup=1; text=M.MCancel; cancel=1; },
  }
  ----------------------------------------------------------------------------
  local dlg = sdialog.New(Items)
  local Pos = dlg:Indexes()
  local Data = _Plugin.History:field("config")
  dlg:LoadData(Data)

  local hColor0 = Data.EditorHighlightColor
  local hColor1 = Data.GrepLineNumMatchColor
  local hColor2 = Data.GrepLineNumContextColor

  Items.proc = function(hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == Pos.btnHighlight then
        local c = far.ColorDialog(hColor0)
        if c then hColor0 = c; hDlg:send(F.DM_REDRAW); end
      elseif param1 == Pos.btnGrepLNum1 then
        local c = far.ColorDialog(hColor1)
        if c then hColor1 = c; hDlg:send(F.DM_REDRAW); end
      elseif param1 == Pos.btnGrepLNum2 then
        local c = far.ColorDialog(hColor2)
        if c then hColor2 = c; hDlg:send(F.DM_REDRAW); end
      end

    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Pos.labHighlight then param2[1] = hColor0; return param2; end
      if param1 == Pos.labGrepLNum1 then param2[1] = hColor1; return param2; end
      if param1 == Pos.labGrepLNum2 then param2[1] = hColor2; return param2; end
    end
  end

  local out = dlg:Run()
  if out then
    dlg:SaveData(out, Data)
    Data.EditorHighlightColor = hColor0
    Data.GrepLineNumMatchColor = hColor1
    Data.GrepLineNumContextColor = hColor2
    _Plugin.History:save()
    return true
  end
end


local TUserBreak = {
  time       = nil;
  cancel     = nil;
  fullcancel = nil;
}
local UserBreakMeta = { __index=TUserBreak }

local function NewUserBreak()
  return setmetatable({ time=0 }, UserBreakMeta)
end

function TUserBreak:ConfirmEscape (in_file)
  local ret
  if win.ExtractKey() == "ESCAPE" then
    local hScreen = far.SaveScreen()
    local msg = M.MInterrupted.."\n"..M.MConfirmCancel
    local t1 = os.clock()
    if in_file then
      -- [Cancel current file] [Cancel all files] [Continue]
      local r = far.Message(msg, M.MMenuTitle, M.MButtonsCancelOnFile, "w")
      if r == 2 then
        self.fullcancel = true
      end
      ret = r==1 or r==2
    else
      -- [Yes] [No]
      local r = far.Message(msg, M.MMenuTitle, M.MBtnYesNo, "w")
      if r == 1 then
        self.fullcancel = true
        ret = true
      end
    end
    self.time = self.time + os.clock() - t1
    far.RestoreScreen(hScreen); far.Text();
  end
  return ret
end

function TUserBreak:fInterrupt()
  local c = self:ConfirmEscape("in_file")
  self.cancel = c
  return c
end


local function set_progress (LEN, ratio, space)
  space = space or ""
  local uchar1, uchar2 = uchar(9608), uchar(9617)
  local len = math.floor(ratio*LEN + 0.5)
  local text = uchar1:rep(len) .. uchar2:rep(LEN-len) .. space .. ("%3d%%"):format(ratio*100)
  return text
end


local DisplaySearchState do
  local lastclock = 0
  local wMsg, wHead = 60, 10
  local wTail = wMsg - wHead - 3
  DisplaySearchState = function (fullname, cntFound, cntTotal, ratio, userbreak)
    local newclock = far.FarClock()
    if newclock >= lastclock then
      lastclock = newclock + 2e5 -- period = 0.2 sec
      local len = fullname:len()
      local s = len<=wMsg and fullname..(" "):rep(wMsg-len) or
                fullname:sub(1,wHead).. "..." .. fullname:sub(-wTail)
      far.Message(
        (s.."\n") .. (set_progress(wMsg-4, ratio).."\n") .. (M.MFilesFound..cntFound.."/"..cntTotal),
        M.MTitleSearching, "")
      return userbreak and userbreak:ConfirmEscape()
    end
  end
end


local function DisplayReplaceState (fullname, cnt, ratio)
  local WID, W1 = 60, 3
  local W2 = WID - W1 - 3
  local len = fullname:len()
  local s = len<=WID and fullname..(" "):rep(WID-len) or
            fullname:sub(1,W1).. "..." .. fullname:sub(-W2)
  far.Message(
    (s.."\n") .. (set_progress(W2, ratio, " ").."\n") .. (M.MPanelFin_FilesProcessed.." "..cnt),
    M.MTitleProcessing, "")
end


local function CheckMask (mask)
  return far.ProcessName("PN_CHECKMASK", mask, nil, "PN_SHOWERRORMESSAGE")
end


return {
  CheckMask = CheckMask,
  CheckSearchArea = CheckSearchArea,
  ConfigDialog = ConfigDialog,
  CreateSRFrame = CreateSRFrame,
  DefaultLogFileName = DefaultLogFileName,
  DisplayReplaceState = DisplayReplaceState,
  DisplaySearchState = DisplaySearchState,
  EditorConfigDialog = EditorConfigDialog,
  ErrorMsg = ErrorMsg,
  FormatInt = FormatInt,
  FormatTime = FormatTime,
  GetDialogHistory = GetDialogHistory,
  GetDialogHistoryValue = GetDialogHistoryValue,
  GetRegexLib = GetRegexLib,
  GetReplaceFunction = GetReplaceFunction,
  GetSearchAreas = GetSearchAreas,
  GetWordUnderCursor = GetWordUnderCursor,
  GotoEditField = GotoEditField,
  Gsub = Gsub,
  GsubMB = GsubMB,
  GsubW = GsubW,
  IndexToSearchArea = IndexToSearchArea,
  NewUserBreak = NewUserBreak,
  ProcessDialogData = ProcessDialogData,
  SaveCodePageCombo = SaveCodePageCombo,
  TransformLogFilePat = TransformLogFilePat,
}
