-- lfs_common.lua
-- luacheck: globals _Plugin

local Editors    = require "lfs_editors"
local M          = require "lfs_message"
local RepLib     = require "lfs_replib"

local libDialog  = require "far2.dialog"
local libHistory = require "far2.history"

local DefaultLogFileName = "\\D{%Y%m%d-%H%M%S}.log"

local type = type
local uchar = ("").char
local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor, bnot = bit64.band, bit64.bor, bit64.bnot
local Utf8, Utf16 = win.Utf16ToUtf8, win.Utf8ToUtf16
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
  hDlg:send("DM_SETCURSORPOS", id, {X=len, Y=1})
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

local function SaveCodePageCombo (hDlg, combo, aData, aSaveCurPos)
  if aSaveCurPos then
    local pos = combo:GetListCurPos (hDlg)
    aData.iSelectedCodePage = combo.ListItems[pos].CodePage
  end
  aData.tCheckedCodePages = {}
  local info = hDlg:send(F.DM_LISTINFO, combo.id)
  for i=1,info.ItemsNumber do
    local item = hDlg:send(F.DM_LISTGETITEM, combo.id, i)
    if 0 ~= band(item.Flags, F.LIF_CHECKED) then
      local t = hDlg:send(F.DM_LISTGETDATA, combo.id, i)
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


local function GetDialogHistoryKey (baseKey)
  return _Plugin.History:field("config").bUseFarHistory and baseKey
      or _Plugin.DialogHistoryPath .. baseKey
end

local function GetDialogHistoryValue (key, index)
  local dh = libHistory.dialoghistory(key, index, index)
  return dh and dh[1] and dh[1].Name
end


local SRFrame = {}
SRFrame.Libs = {"far", "oniguruma", "pcre", "pcre2"}
local SRFrameMeta = {__index = SRFrame}

local function CreateSRFrame (Dlg, aData, bInEditor, bScriptCall)
  local self = {Dlg=Dlg, Data=aData, bInEditor=bInEditor, bScriptCall=bScriptCall}
  return setmetatable(self, SRFrameMeta)
end

function SRFrame:InsertInDialog (aPanelsDialog, Y, aOp)
  local sepflags = bor(F.DIF_BOXCOLOR, F.DIF_SEPARATOR)
  local hstflags = bor(F.DIF_HISTORY, F.DIF_MANUALADDHISTORY)
  local Dlg = self.Dlg
  ------------------------------------------------------------------------------
  if aPanelsDialog then
    Dlg.lab       = {"DI_TEXT",   5, Y,   0, 0, 0, 0, 0, 0, M.MDlgFileMask}
    Dlg.sFileMask = {"DI_EDIT",   5, Y+1,70, 0, 0, "Masks", 0, F.DIF_HISTORY, "", _default="*"}
    Y = Y+2
  end
  ------------------------------------------------------------------------------
  Dlg.lab         = {"DI_TEXT",   5,Y,  0, Y, 0, 0, 0, 0, M.MDlgSearchPat}
  Y = Y + 1
  Dlg.sSearchPat  = {"DI_EDIT",   5,Y, 65, Y, 0, GetDialogHistoryKey("SearchText"), 0, hstflags, ""}
  local bSearchEsc ={"DI_BUTTON",67,Y,  0, Y, 0, "", 0, F.DIF_BTNNOCLOSE, "&\\"}
  ------------------------------------------------------------------------------
  if aPanelsDialog and aOp == "grep" then
    Y = Y + 1
    Dlg.lab       = {"DI_TEXT",   5,Y,  0, Y, 0, 0, 0, 0, M.MDlgSkipPat}
    Y = Y + 1
    Dlg.sSkipPat  = {"DI_EDIT",   5,Y, 65, Y, 0, GetDialogHistoryKey("SkipText"), 0, hstflags, ""}
    Dlg.bSkipEsc  = {"DI_BUTTON",67,Y,  0, Y, 0, "", 0, F.DIF_BTNNOCLOSE, "&/"}
  end
  ------------------------------------------------------------------------------
  if aOp == "replace" then
    Y = Y + 1
    Dlg.lab         = {"DI_TEXT",     5,Y,  0, 0, 0, 0, 0, 0, M.MDlgReplacePat}
    Y = Y + 1
    Dlg.sReplacePat = {"DI_EDIT",     5,Y, 65, Y, 0, GetDialogHistoryKey("ReplaceText"), 0, hstflags, ""}
    Dlg.bSearchEsc =  bSearchEsc
    Dlg.bReplaceEsc = {"DI_BUTTON", 67, Y,  0, Y, 0, "", 0, F.DIF_BTNNOCLOSE, "&/"}
    Y = Y + 1
    if aPanelsDialog then
      Dlg.bRepIsFunc       = {"DI_CHECKBOX", 7, Y, 0,0, 0,0,0,0, M.MDlgRepIsFunc}
      Dlg.bMakeBackupCopy  = {"DI_CHECKBOX",27, Y, 0,0, 0,0,0,0, M.MDlgMakeBackupCopy}
      Dlg.bConfirmReplace  = {"DI_CHECKBOX",48, Y, 0,0, 0,0,0,0, M.MDlgConfirmReplace}
    else
      Dlg.bRepIsFunc       = {"DI_CHECKBOX", 7, Y, 0,0, 0,0,0,0, M.MDlgRepIsFunc}
      Dlg.bDelEmptyLine    = {"DI_CHECKBOX",38, Y, 0,0, 0,0,0,0, M.MDlgDelEmptyLine}
      Y = Y + 1
      Dlg.bConfirmReplace  = {"DI_CHECKBOX", 7, Y, 0,0, 0,0,0,0, M.MDlgConfirmReplace}
      Dlg.bDelNonMatchLine = {"DI_CHECKBOX",38, Y, 0,0, 0,0,0,0, M.MDlgDelNonMatchLine}
    end
  else
    Dlg.bSearchEsc = bSearchEsc
  end
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.sep = {"DI_TEXT", 5,Y,0,0, 0,0, 0, sepflags, ""}
  ------------------------------------------------------------------------------
  Y = Y + 1
  local X2 = 40
  local X3 = X2 + M.MDlgRegexLib:gsub("&",""):len() + 1;
  local X4 = X3 + 12
  Dlg.bRegExpr   = {"DI_CHECKBOX",      5,Y,  0, 0, 0, 0, 0, 0, M.MDlgRegExpr}
  Dlg.lab        = {"DI_TEXT",         X2,Y,  0, 0, 0, 0, 0, 0, M.MDlgRegexLib}
  Dlg.cmbRegexLib= {"DI_COMBOBOX",     X3,Y ,X4, 0, {
                       {Text="Far regex"},
                       {Text="Oniguruma"},
                       {Text="PCRE"},
                       {Text="PCRE2"},
                     }, 0, 0, {DIF_DROPDOWNLIST=1}, "", _noauto=true}
  Y = Y + 1
  Dlg.bCaseSens   = {"DI_CHECKBOX",     5,Y,  0, 0, 0, 0, 0, 0, M.MDlgCaseSens}
  Dlg.bExtended   = {"DI_CHECKBOX",    X2,Y,  0, 0, 0, 0, 0, 0, M.MDlgExtended}
  ------------------------------------------------------------------------------
  Y = Y + 1
  Dlg.bWholeWords = {"DI_CHECKBOX",     5,Y,  0, 0, 0, 0, 0, 0, M.MDlgWholeWords}
  ------------------------------------------------------------------------------
  if aPanelsDialog and aOp=="search" then
    Dlg.bFileAsLine    = {"DI_CHECKBOX",X2, Y,  0, 0, 0, 0, 0, 0, M.MDlgFileAsLine}
    Y = Y + 1
    Dlg.bMultiPatterns = {"DI_CHECKBOX", 5, Y,  0, 0, 0, 0, 0, 0, M.MDlgMultiPatterns}
    Dlg.bInverseSearch = {"DI_CHECKBOX",X2, Y,  0, 0, 0, 0, 0, 0, M.MDlgInverseSearch}
  end
  return Y + 1
end

function SRFrame:CheckRegexInit (hDlg, Data)
  local Dlg = self.Dlg
  Dlg.bWholeWords :SetCheck(hDlg, Data.bWholeWords)
  Dlg.bExtended   :SetCheck(hDlg, Data.bExtended)
  Dlg.bCaseSens   :SetCheck(hDlg, Data.bCaseSens)
  self:CheckRegexChange(hDlg)
end

function SRFrame:CheckRegexChange (hDlg)
  local Dlg = self.Dlg
  local bRegex = Dlg.bRegExpr:GetCheck(hDlg)

  if bRegex then Dlg.bWholeWords:SetCheck(hDlg, false) end
  Dlg.bWholeWords:Enable(hDlg, not bRegex)

  if not bRegex then Dlg.bExtended:SetCheck(hDlg, false) end
  Dlg.bExtended:Enable(hDlg, bRegex)

  if Dlg.bFileAsLine then
    if not bRegex then Dlg.bFileAsLine:SetCheck(hDlg, false) end
    Dlg.bFileAsLine:Enable(hDlg, bRegex)
  end
end

function SRFrame:CheckAdvancedEnab (hDlg)
  local Dlg = self.Dlg
  if Dlg.bAdvanced then
    local bEnab = Dlg.bAdvanced:GetCheck(hDlg)
    Dlg.labInitFunc   :Enable(hDlg, bEnab)
    Dlg.sInitFunc     :Enable(hDlg, bEnab)
    Dlg.labFinalFunc  :Enable(hDlg, bEnab)
    Dlg.sFinalFunc    :Enable(hDlg, bEnab)
    if Dlg.sFilterFunc then
      Dlg.labFilterFunc :Enable(hDlg, bEnab)
      Dlg.sFilterFunc   :Enable(hDlg, bEnab)
    end
  end
end

function SRFrame:CheckWrapAround (hDlg)
  local Dlg = self.Dlg
  if self.bInEditor and Dlg.bWrapAround then
    local enb = Dlg.rScopeGlobal:GetCheck(hDlg) and Dlg.rOriginCursor:GetCheck(hDlg)
    Dlg.bWrapAround:Enable(hDlg, enb)
  end
end

local function SetSearchFieldNotEmpty (Dlg)
  -- Try plugin history (it may be not stored in dialog history)
  local h = _Plugin.History
  local s = not h:field("config").bUseFarHistory and h:field("main").sSearchPat

  -- Try dialog history
  if not s or s == "" then
    local key = GetDialogHistoryKey("SearchText")
    s = GetDialogHistoryValue(key, -1)
    if s == "" then
      s = GetDialogHistoryValue(key, -2)
    end
  end

  if s then Dlg.sSearchPat.Data = s end
end

function SRFrame:OnDataLoaded (aData)
  local Dlg = self.Dlg
  if not self.bScriptCall then
    if Dlg.sReplacePat then Dlg.sReplacePat.Flags = bor(Dlg.sReplacePat.Flags, F.DIF_USELASTHISTORY) end
    if Dlg.sFileMask then Dlg.sFileMask.Flags = bor(Dlg.sFileMask.Flags, F.DIF_USELASTHISTORY) end
    if self.bInEditor then
      local from = _Plugin.History:field("config").rPickFrom
      if from == "history" then
        SetSearchFieldNotEmpty(Dlg)
      elseif from == "nowhere" then
        Dlg.sSearchPat.Data = ""
        if Dlg.sReplacePat then Dlg.sReplacePat.Data = ""; end
      else -- (default) if from == "editor" then
        local word = GetWordUnderCursor()
        if word then Dlg.sSearchPat.Data = word
        else         SetSearchFieldNotEmpty(Dlg)
        end
      end
    else
      if Dlg.sReplacePat then SetSearchFieldNotEmpty(Dlg) end
    end
  end

  local items = Dlg.cmbRegexLib.ListItems
  items.SelectIndex = 1
  for i,v in ipairs(self.Libs) do
    if aData.sRegexLib == v then items.SelectIndex = i; break; end
  end
end


function SRFrame:CompleteLoadData (hDlg, Data, LoadFromPreset)
  local Dlg = self.Dlg
  local bScript = self.bScriptCall or LoadFromPreset

  if self.bInEditor then
    -- Set scope
    local EI = editor.GetInfo()
    if EI.BlockType == F.BTYPE_NONE then
      Dlg.rScopeGlobal:SetCheck(hDlg, true)
      Dlg.rScopeBlock:Enable(hDlg, false)
    else
      local bScopeBlock
      local bForceBlock = _Plugin.History:field("config").bForceScopeToBlock
      if bScript or not bForceBlock then
        bScopeBlock = (Data.sScope == "block")
      else
        local line = editor.GetStringW(nil, EI.BlockStartLine+1) -- test the 2-nd selected line
        bScopeBlock = line and line.SelStart>0
      end
      Dlg[bScopeBlock and "rScopeBlock" or "rScopeGlobal"]:SetCheck(hDlg, true)
    end

    -- Set origin
    local key = bScript and "sOrigin"
                or Dlg.rScopeGlobal:GetCheck(hDlg) and "sOriginInGlobal"
                or "sOriginInBlock"
    local name = Data[key]=="scope" and "rOriginScope" or "rOriginCursor"
    Dlg[name]:SetCheck(hDlg, true)

    self:CheckWrapAround(hDlg)
  end

  self:CheckAdvancedEnab(hDlg)
  self:CheckRegexInit(hDlg, Data)
end


function SRFrame:SaveDataDyn (hDlg, Data)
  local Dlg = self.Dlg
  ------------------------------------------------------------------------
  Dlg.sSearchPat:SaveText(hDlg, Data)
  Dlg.bCaseSens:SaveCheck(hDlg, Data)
  Dlg.bRegExpr:SaveCheck(hDlg, Data)

  Dlg.bWholeWords:SaveCheck(hDlg, Data)
  Dlg.bExtended:SaveCheck(hDlg, Data)
  if Dlg.bFileAsLine then Dlg.bFileAsLine:SaveCheck(hDlg, Data) end
  if Dlg.bInverseSearch then Dlg.bInverseSearch:SaveCheck(hDlg, Data) end
  if Dlg.bMultiPatterns then Dlg.bMultiPatterns:SaveCheck(hDlg, Data) end
  ------------------------------------------------------------------------
  if self.bInEditor then
    Dlg.bWrapAround:SaveCheck(hDlg, Data)
    Dlg.bSearchBack:SaveCheck(hDlg, Data)
    Dlg.bHighlight:SaveCheck(hDlg, Data)
    Data.sScope = Dlg.rScopeGlobal:GetCheck(hDlg) and "global" or "block"
    Data.sOrigin = Dlg.rOriginCursor:GetCheck(hDlg) and "cursor" or "scope"

    if not self.bScriptCall then
      local key = Data.sScope == "global" and "sOriginInGlobal" or "sOriginInBlock"
      Data[key] = Data.sOrigin -- to be passed to execution
    end
  else
    Dlg.sFileMask:SaveText(hDlg, Data)
    if Dlg.bSearchFolders then Dlg.bSearchFolders:SaveCheck(hDlg, Data) end
    Dlg.bSearchSymLinks:SaveCheck(hDlg, Data)
    Data.sSearchArea = IndexToSearchArea(Dlg.cmbSearchArea:GetListCurPos(hDlg))
    if Dlg.bGrepHighlight then -- Grep dialog
      Dlg.sSkipPat:SaveText(hDlg, Data)
      Dlg.bGrepShowLineNumbers:SaveCheck(hDlg, Data)
      Dlg.bGrepHighlight:SaveCheck(hDlg, Data)
      Dlg.bGrepInverseSearch:SaveCheck(hDlg, Data)
      Dlg.sGrepLinesBefore:SaveText(hDlg, Data)
      Dlg.sGrepLinesAfter:SaveText(hDlg, Data)
    end
  end
  ------------------------------------------------------------------------
  if Dlg.bAdvanced then
    Dlg.bAdvanced  :SaveCheck(hDlg, Data)
    Dlg.sInitFunc  :SaveText(hDlg, Data)
    Dlg.sFinalFunc :SaveText(hDlg, Data)
    if Dlg.sFilterFunc then
      Dlg.sFilterFunc:SaveText(hDlg, Data)
    end
  end
  ------------------------------------------------------------------------
  if Dlg.sReplacePat then
    Dlg.sReplacePat :SaveText(hDlg, Data)
    Dlg.bRepIsFunc  :SaveCheck(hDlg, Data)
    if Dlg.bDelEmptyLine then Dlg.bDelEmptyLine:SaveCheck(hDlg, Data) end
    if Dlg.bDelNonMatchLine then Dlg.bDelNonMatchLine:SaveCheck(hDlg, Data) end
    if Dlg.bMakeBackupCopy then Dlg.bMakeBackupCopy:SaveCheck(hDlg, Data) end
    if Dlg.bConfirmReplace then Dlg.bConfirmReplace:SaveCheck(hDlg, Data) end
  end
  ------------------------------------------------------------------------
  Data.sRegexLib = self.Libs[ Dlg.cmbRegexLib:GetListCurPos(hDlg) ]
end


function SRFrame:DlgProc (hDlg, msg, param1, param2)
  local Dlg, Data, bInEditor = self.Dlg, self.Data, self.bInEditor
  local bReplace = Dlg.sReplacePat
  ----------------------------------------------------------------------------
  if msg == F.DN_INITDIALOG then
    self:CompleteLoadData(hDlg, Data, false)
  ----------------------------------------------------------------------------
  elseif msg == F.DN_BTNCLICK then
    if param1==Dlg.bRegExpr.id then
      self:CheckRegexChange(hDlg)
    elseif Dlg.bSearchEsc and param1==Dlg.bSearchEsc.id then
      local txt = Dlg.sSearchPat:GetText(hDlg)
      if #txt < 1e6 then -- protect against memory exhaustion
        txt = EscapeSearchPattern(txt)
        Dlg.sSearchPat:SetText(hDlg, txt)
        hDlg:send("DM_SETFOCUS", Dlg.sSearchPat.id)
      end
    elseif Dlg.bSkipEsc and param1==Dlg.bSkipEsc.id then
      local txt = Dlg.sSkipPat:GetText(hDlg)
      if #txt < 1e6 then -- protect against memory exhaustion
        txt = EscapeSearchPattern(txt)
        Dlg.sSkipPat:SetText(hDlg, txt)
        hDlg:send("DM_SETFOCUS", Dlg.sSkipPat.id)
      end
    elseif Dlg.bReplaceEsc and param1==Dlg.bReplaceEsc.id then
      local txt = Dlg.sReplacePat:GetText(hDlg)
      if #txt < 1e6 then -- protect against memory exhaustion
        txt = txt:gsub("[$\\]", "\\%1")
        Dlg.sReplacePat:SetText(hDlg, txt)
        hDlg:send("DM_SETFOCUS", Dlg.sReplacePat.id)
      end
    else
      if bInEditor then
        self:CheckWrapAround(hDlg)
      end
      if Dlg.bAdvanced and param1==Dlg.bAdvanced.id then
        self:CheckAdvancedEnab(hDlg)
      end
    end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_EDITCHANGE then
    if param1 == Dlg.cmbRegexLib.id then self:CheckRegexChange(hDlg) end
  ----------------------------------------------------------------------------
  elseif msg == F.DN_CLOSE then
    if Dlg.btnOk      and param1 == Dlg.btnOk.id       or
       Dlg.btnCount   and param1 == Dlg.btnCount.id    or
       Dlg.btnShowAll and param1 == Dlg.btnShowAll.id
    then
      if bInEditor then
        if Dlg.sSearchPat:GetText(hDlg) == "" then
          ErrorMsg(M.MSearchFieldEmpty)
          GotoEditField(hDlg, Dlg.sSearchPat.id)
          return KEEP_DIALOG_OPEN
        end
      end
      local tmpdata, key = {}
      for k,v in pairs(Data) do tmpdata[k]=v end
      self:SaveDataDyn(hDlg, tmpdata)
      local bSkip = Dlg.sSkipPat and tmpdata.sSkipPat ~= ""
      self.close_params, key = ProcessDialogData(tmpdata, bReplace, bInEditor, Dlg.bMultiPatterns, bSkip)
      if self.close_params then
        for k,v in pairs(tmpdata) do Data[k]=v end
        hDlg:send("DM_ADDHISTORY", Dlg.sSearchPat.id, Data.sSearchPat)
        if Dlg.sReplacePat then hDlg:send("DM_ADDHISTORY", Dlg.sReplacePat.id, Data.sReplacePat) end
        if Dlg.sSkipPat    then hDlg:send("DM_ADDHISTORY", Dlg.sSkipPat.id,    Data.sSkipPat)    end
        if Dlg.bHighlight then
          local checked = Dlg.bHighlight:GetCheck(hDlg)
          if checked or not Editors.IsHighlightGrep() then
            Editors.SetHighlightPattern(self.close_params.Regex)
            Editors.ActivateHighlight(checked)
          end
        end
      else
        if key and Dlg[key] then GotoEditField(hDlg, Dlg[key].id) end
        return KEEP_DIALOG_OPEN
      end

    end
  end
end


function SRFrame:DoPresets (hDlg)
  local Dlg = self.Dlg
  local HistPresetNames = _Plugin.DialogHistoryPath .. "Presets"
  hDlg:send("DM_SHOWDIALOG", 0)
  local props = { Title=M.MTitlePresets, Bottom = "Esc,Enter,F2,Ins,F6,Del", HelpTopic="Presets", }
  local presets = _Plugin.History:field("presets")
  local bkeys = { {BreakKey="F2"}, {BreakKey="INSERT"}, {BreakKey="DELETE"}, {BreakKey="F6"} }

  while true do
    local items = {}
    for name, preset in pairs(presets) do
      local t = { text=name, preset=preset }
      items[#items+1] = t
      if name == self.PresetName then t.selected,t.checked = true,true; end
    end
    table.sort(items, function(a,b) return win.CompareString(a.text,b.text,nil,"cS") < 0; end)
    local item, pos = far.Menu(props, items, bkeys)
    if not item then break end
    ----------------------------------------------------------------------------
    if item.preset then
      self.PresetName = item.text
      local data = item.preset
      libDialog.LoadDataDyn (hDlg, Dlg, data, true)

      if Dlg.cmbSearchArea and data.sSearchArea then
        Dlg.cmbSearchArea:SetListCurPos(hDlg, SearchAreaToIndex(data.sSearchArea))
      end

      if Dlg.cmbCodePage then
        local combo = Dlg.cmbCodePage
        local info = hDlg:send(F.DM_LISTINFO, combo.id)
        if data.tCheckedCodePages then
          local map = {}
          for i,v in ipairs(data.tCheckedCodePages) do map[v]=i end
          for i=3,info.ItemsNumber do -- skip "Default code pages" and "Checked code pages"
            local cp = hDlg:send(F.DM_LISTGETDATA, combo.id, i)
            if cp then
              local listItem = hDlg:send(F.DM_LISTGETITEM, combo.id, i)
              listItem.Index = i
              if map[cp] then listItem.Flags = bor(listItem.Flags, F.LIF_CHECKED)
              else listItem.Flags = band(listItem.Flags, bnot(F.LIF_CHECKED))
              end
              hDlg:send(F.DM_LISTUPDATE, combo.id, listItem)
            end
          end
        end
        if data.iSelectedCodePage then
          local scp = data.iSelectedCodePage
          for i=1,info.ItemsNumber do
            if scp == hDlg:send(F.DM_LISTGETDATA, combo.id, i) then
              combo:SetListCurPos(hDlg, i)
              break
            end
          end
        end
      end

      local index, lib = 1, data.sRegexLib
      for i,v in ipairs(self.Libs) do
        if lib == v then index = i; break; end
      end
      Dlg.cmbRegexLib:SetListCurPos(hDlg, index)

      self:CompleteLoadData(hDlg, data, true)
      break
    ----------------------------------------------------------------------------
    elseif item.BreakKey == "F2" or item.BreakKey == "INSERT" then
      local pure_save_name = item.BreakKey == "F2" and self.PresetName
      local name = pure_save_name or
        far.InputBox(nil, M.MSavePreset, M.MEnterPresetName, HistPresetNames,
                     self.PresetName, nil, nil, F.FIB_NOUSELASTHISTORY)
      if name then
        if pure_save_name or not presets[name] or
          far.Message(M.MPresetOverwrite, M.MConfirm, M.MBtnYesNo, "w") == 1
        then
          local data = {}
          presets[name] = data
          self.PresetName = name
          self:SaveDataDyn (hDlg, data)
          if Dlg.cmbCodePage then SaveCodePageCombo(hDlg, Dlg.cmbCodePage, data, true) end
          _Plugin.History:save()
          if pure_save_name then
            far.Message(M.MPresetWasSaved, M.MMenuTitle)
            break
          end
        end
      end
    ----------------------------------------------------------------------------
    elseif item.BreakKey == "DELETE" and items[1] then
      local name = items[pos].text
      local msg = ([[%s "%s"?]]):format(M.MDeletePreset, name)
      if far.Message(msg, M.MConfirm, M.MBtnYesNo, "w") == 1 then
        if self.PresetName == name then
          self.PresetName = nil
        end
        presets[name] = nil
        _Plugin.History:save()
      end
    ----------------------------------------------------------------------------
    elseif item.BreakKey == "F6" and items[1] then
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
  local CfgGuid = win.Uuid("6C2BC7AF-8739-499E-BFA2-7E967B0BDDA9")
  local HIST_LOG = _Plugin.DialogHistoryPath .. "LogFileName"
  local X1 = 5 + (M.MRenameLogFileName):len()
  local Dlg = libDialog.NewDialog()
  Dlg.frame           = {"DI_DOUBLEBOX",   3, 1,72, 8,  0, 0, 0,  0,  M.MConfigTitleCommon}
  Dlg.bUseFarHistory  = {"DI_CHECKBOX",    5, 2, 0, 0,  0, 0, 0,  0,  M.MUseFarHistory}
  Dlg.lab             = {"DI_TEXT",        5, 4, 0, 0,  0, 0, 0,  0,  M.MRenameLogFileName}
  Dlg.sLogFileName    = {"DI_EDIT",       X1, 4,70, 0,  0, HIST_LOG, 0, {DIF_HISTORY=1,DIF_USELASTHISTORY=1},
                                                                      DefaultLogFileName}
  Dlg.sep             = {"DI_TEXT",        5, 6, 0, 0,  0, 0, 0,  {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  Dlg.btnOk           = {"DI_BUTTON",      0, 7, 0, 0,  0, 0, 0,  {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MOk}
  Dlg.btnCancel       = {"DI_BUTTON",      0, 7, 0, 0,  0, 0, 0,  "DIF_CENTERGROUP", M.MCancel}
  ----------------------------------------------------------------------------
  local Data = _Plugin.History:field("config")
  libDialog.LoadData(Dlg, Data)

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_CLOSE then
      if param1 == Dlg.btnOk.id then
        local ok, errmsg = TransformLogFilePat(Dlg.sLogFileName:GetText(hDlg))
        if not ok then
          ErrorMsg(errmsg, "Log file name")
          return KEEP_DIALOG_OPEN
        end
      end
    end
  end

  local ret = far.Dialog (CfgGuid, -1, -1, 76, 10, "Configuration", Dlg, 0, DlgProc)
  if ret == Dlg.btnOk.id then
    libDialog.SaveData(Dlg, Data)
    _Plugin.History:save()
    return true
  end
end


local function EditorConfigDialog()
  local CfgGuid = win.Uuid("69E53E0A-D63E-40CC-B153-602E9633956E")
  local Dlg = libDialog.NewDialog()
  local offset = 5 + math.max(M.MBtnHighlightColor:len(),
                              M.MBtnGrepLineNumMatchedColor:len(),
                              M.MBtnGrepLineNumContextColor:len()) + 5
  Dlg.frame           = {"DI_DOUBLEBOX",   3, 1,72,15,  0, 0, 0,  0,  M.MConfigTitleEditor}
  Dlg.bForceScopeToBlock={"DI_CHECKBOX",   5, 2, 0, 0,  0, 0, 0,  0,  M.MOptForceScopeToBlock}
  Dlg.bSelectFound    = {"DI_CHECKBOX",    5, 3, 0, 0,  0, 0, 0,  0,  M.MOptSelectFound}
  Dlg.bShowSpentTime  = {"DI_CHECKBOX",    5, 4, 0, 0,  0, 0, 0,  0,  M.MOptShowSpentTime}
  Dlg.lab             = {"DI_TEXT",        5, 6, 0, 0,  0, 0, 0,  0,  M.MOptPickFrom}
  Dlg.rPickEditor     = {"DI_RADIOBUTTON", 7, 7, 0, 0,  0, 0, 0,  "DIF_GROUP", M.MOptPickEditor, _noauto=1}
  Dlg.rPickHistory    = {"DI_RADIOBUTTON",27, 7, 0, 0,  0, 0, 0,  0,           M.MOptPickHistory, _noauto=1}
  Dlg.rPickNowhere    = {"DI_RADIOBUTTON",47, 7, 0, 0,  0, 0, 0,  0,           M.MOptPickNowhere, _noauto=1}

  Dlg.sep             = {"DI_TEXT",       -1, 9, 0, 0,  0, 0, 0,  {DIF_BOXCOLOR=nil,DIF_SEPARATOR=1,DIF_CENTERTEXT=1}, M.MSepHighlightColors}
  Dlg.btnHighlight    = {"DI_BUTTON",      5,10, 0, 0,  0, 0, 0,  "DIF_BTNNOCLOSE", M.MBtnHighlightColor}
  Dlg.labHighlight    = {"DI_TEXT",   offset,10, 0, 0,  0, 0, 0,  0,  M.MTextSample}
  Dlg.btnGrepLNum1    = {"DI_BUTTON",      5,11, 0, 0,  0, 0, 0,  "DIF_BTNNOCLOSE", M.MBtnGrepLineNumMatchedColor}
  Dlg.labGrepLNum1    = {"DI_TEXT",   offset,11, 0, 0,  0, 0, 0,  0,  M.MTextSample}
  Dlg.btnGrepLNum2    = {"DI_BUTTON",      5,12, 0, 0,  0, 0, 0,  "DIF_BTNNOCLOSE", M.MBtnGrepLineNumContextColor}
  Dlg.labGrepLNum2    = {"DI_TEXT",   offset,12, 0, 0,  0, 0, 0,  0,  M.MTextSample}

  Dlg.sep             = {"DI_TEXT",        5,13, 0, 0,  0, 0, 0,  {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  Dlg.btnOk           = {"DI_BUTTON",      0,14, 0, 0,  0, 0, 0,  {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MOk}
  Dlg.btnCancel       = {"DI_BUTTON",      0,14, 0, 0,  0, 0, 0,  "DIF_CENTERGROUP", M.MCancel}
  ----------------------------------------------------------------------------
  local Data = _Plugin.History:field("config")
  libDialog.LoadData(Dlg, Data)
  if Data.rPickFrom     == "history" then Dlg.rPickHistory.Selected = 1
  elseif Data.rPickFrom == "nowhere" then Dlg.rPickNowhere.Selected = 1
  else                                    Dlg.rPickEditor.Selected  = 1
  end

  local hColor0 = Data.EditorHighlightColor
  local hColor1 = Data.GrepLineNumMatchColor
  local hColor2 = Data.GrepLineNumContextColor

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == Dlg.btnHighlight.id then
        local c = far.ColorDialog(hColor0)
        if c then hColor0 = c; hDlg:send(F.DM_REDRAW); end
      elseif param1 == Dlg.btnGrepLNum1.id then
        local c = far.ColorDialog(hColor1)
        if c then hColor1 = c; hDlg:send(F.DM_REDRAW); end
      elseif param1 == Dlg.btnGrepLNum2.id then
        local c = far.ColorDialog(hColor2)
        if c then hColor2 = c; hDlg:send(F.DM_REDRAW); end
      end

    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Dlg.labHighlight.id then param2[1] = hColor0; return param2; end
      if param1 == Dlg.labGrepLNum1.id then param2[1] = hColor1; return param2; end
      if param1 == Dlg.labGrepLNum2.id then param2[1] = hColor2; return param2; end
    end
  end

  local ret = far.Dialog (CfgGuid, -1, -1, 76, 17, "Configuration", Dlg, 0, DlgProc)
  if ret == Dlg.btnOk.id then
    libDialog.SaveData(Dlg, Data)
    Data.EditorHighlightColor    = hColor0
    Data.GrepLineNumMatchColor   = hColor1
    Data.GrepLineNumContextColor = hColor2
    Data.rPickFrom =
        Dlg.rPickHistory.Selected ~= 0 and "history" or
        Dlg.rPickNowhere.Selected ~= 0 and "nowhere" or "editor"
    _Plugin.History:save()
    return true
  end
end


--- Automatically assign hot keys in LuaFAR dialog items.
-- NOTE: uses the "hilite" module.
-- @param Dlg : an array of dialog items (tables);
--              an item may have a boolean field 'NoHilite' that means no automatic highlighting;
local function AssignHotKeys (Dlg)
  local fHilite = require "shmuz.hilite"
  local typeIndex = 1  -- index of the "Type" element in a dialog item (Far 3 API)
  local dataIndex = 10 -- index of the "Data" element in a dialog item (Far 3 API)
  local types = { [F.DI_BUTTON]=1;[F.DI_CHECKBOX]=1;[F.DI_RADIOBUTTON]=1;[F.DI_TEXT]=1;[F.DI_VTEXT]=1; }
  local arr, idx = {}, {}
  for i,v in ipairs(Dlg) do
    local iType = type(v[typeIndex])=="number" and v[typeIndex] or F[v[typeIndex]] -- convert flag to number
    if types[iType] and not v.NoHilite then
      local n = #arr+1
      arr[n], idx[n] = v[dataIndex], i
    end
  end
  local out = fHilite(arr)
  for k,v in pairs(out) do
    if type(k)=="number" then Dlg[idx[k]][dataIndex]=v end
  end
end


--- Switch from DI_EDIT dialog field to modal editor, edit text there and put it into the field.
-- @param  hDlg     dialog handle
-- @param  itempos  position of a DI_EDIT item in the dialog
-- @param  ext      extension to give a temporary file, e.g. ".lua" (for syntax highlighting)
local function OpenInEditor (hDlg, itempos, ext)
  local fname = win.GetEnv("TEMP").."\\far3-"..win.Uuid(win.Uuid()):sub(1,8)..(ext or "")
  local fp = io.open(fname, "w")
  if fp then
    local txt = hDlg:send("DM_GETTEXT", itempos)
    fp:write(txt or "")
    fp:close()
    local flags = {EF_DISABLEHISTORY=1,EF_DISABLESAVEPOS=1}
    if editor.Editor(fname,nil,nil,nil,nil,nil,flags,nil,nil,65001) == F.EEC_MODIFIED then
      fp = io.open(fname)
      if fp then
        txt = fp:read("*all")
        fp:close()
        hDlg:send("DM_SETTEXT", itempos, txt)
      end
    end
    win.DeleteFile(fname)
    far.AdvControl("ACTL_REDRAWALL")
  end
end


local function Check_F4_On_DI_EDIT (Dlg, hDlg, msg, param1, param2)
  if msg == F.DN_CONTROLINPUT and param2.EventType == F.KEY_EVENT and param2.KeyDown then
    if param2.VirtualKeyCode == VK.F4 and param2.ControlKeyState%0x20 == 0 then
      local item = Dlg[param1]
      if (item[1]==F.DI_EDIT or item[1]=="DI_EDIT") and not item.skipF4 then
        local ext = item.F4 or
          (item==Dlg.sReplacePat and Dlg.bRepIsFunc and Dlg.bRepIsFunc:GetCheck(hDlg) and ".lua")
        OpenInEditor(hDlg, param1, ext)
        return true
      end
    end
  end
  return false
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
  AssignHotKeys = AssignHotKeys,
  Check_F4_On_DI_EDIT = Check_F4_On_DI_EDIT,
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
  GetDialogHistoryKey = GetDialogHistoryKey,
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
