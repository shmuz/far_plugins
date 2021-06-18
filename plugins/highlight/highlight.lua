-- Encoding: utf-8
-- Started: 2014-10-06
-- Author: Shmuel Zeigerman

-- luacheck: globals rex Editors MenuPos

local function LOG(fmt,...) win.OutputDebugString(fmt:format(...)) end
local function ErrMsg (msg, title, flags)
  far.Message(msg, title or "[Highlight] Error", nil, (flags or "").."w")
end

-- Global variables
rex = rex or {}
Editors = Editors or {}
MenuPos = MenuPos or 1

if not rex.new then
  local DllName = far.PluginStartupInfo().ModuleDir .. "rex_onig.dl"
  local luaopen = package.loadlib(DllName, "luaopen_rex_onig")
  if not luaopen then
    ErrMsg("Could not load\n" .. DllName)
    return
  end

  rex = luaopen()
  local Utf8ToUtf16 = win.Utf8ToUtf16
  local orig_new = rex.new
  rex.new = function (pat, cf, syn)
    return orig_new(Utf8ToUtf16(pat), cf, "UTF16_LE", syn or "PERL_NG")
  end

  local methods = getmetatable(orig_new(".")).__index
  methods.findW = function(r, s, init) -- simplified method: only 1-st capture
    local from, to, cap = r:find(s, 2*init-1)
    if from then from, to = (from+1)/2, to/2; return from, to, cap; end
  end
  methods.tfindW = function(r, s, init)
    local from, to, t = r:tfind(s, 2*init-1)
    if from then from, to = (from+1)/2, to/2; return from, to, t; end
  end
end

local function NormalizeFastLines (p)
  p = math.floor(tonumber(p) or 200)
  p = math.max(p, 0)
  p = math.min(p, 999999)
  return p
end

local function NormalizeColorPriority (p)
  p = math.floor(tonumber(p) or 10)
  p = math.max(p, 0)
  p = math.min(p, 0xFFFFFFFF)
  return p
end

local F = far.Flags
local band, bor, bxor, lshift = bit64.band, bit64.bor, bit64.bxor, bit64.lshift

local acFlags = bor(F.ECF_TABMARKCURRENT, F.ECF_AUTODELETE)
local AppTitle
local Hist_Config, Config
local Hist_Extra, Extra
local Owner
local PatEndLine = rex.new("$")
local Classes = {}
local libDialog = require "far2.dialog"
local libHistory = require "far2.history"

-- initialize AppTitle, Owner, Hist_Config, Config.
do
  local info = export.GetGlobalInfo()
  AppTitle, Owner = info.Title, info.Guid

  Hist_Config = libHistory.newsettings(nil, "Config")
  Config = Hist_Config.Data
  Hist_Extra = libHistory.newsettings(nil, "ExtraData")
  Extra = Hist_Extra.Data

  far.ReloadDefaultScript = Config.bDebugMode
  Config.nColorPriority = NormalizeColorPriority(Config.nColorPriority)
  Config.nFastLines = NormalizeFastLines(Config.nFastLines)
  if Config.bFastMode==nil then Config.bFastMode=true end -- default=true
  if Config.On==nil then Config.On=true end -- default=true
end

-- NOT USED: IS IT REALLY NEEDED?
local function toreal(id, y, pos) return editor.TabToReal(id, y, pos) end

local function template(str, ...)
  local rep = {...}
  str = str:gsub("%%(.)",
    function(c)
      local n = tonumber(c)
      return n and rep[n] and win.Utf16ToUtf8(rep[n]) or c
    end)
  return str
end

local COLNAMES = {
  black      =0x0;
  darkblue   =0x1;
  darkgreen  =0x2;
  darkaqua   =0x3;
  darkred    =0x4;
  darkpurple =0x5;
  darkyellow =0x6;  gold =0x6;
  darkwhite  =0x7;  gray7=0x7; grey7=0x7;

  gray       =0x8;  grey =0x8; gray8=0x8; grey8=0x8;
  blue       =0x9;
  green      =0xA;
  aqua       =0xB;
  red        =0xC;
  purple     =0xD;
  yellow     =0xE;
  white      =0xF;
}

local function ProcessFullColor(color)
  if type(color) == "number" then
    return color
  elseif type(color) == "string" then
    local fg,bg = color:match("(%l+)[%- ]+on[%- ]+(%l+)") -- e.g. "yellow on gold"
    if fg and COLNAMES[fg] and COLNAMES[bg] then
      return bor(COLNAMES[fg], lshift(COLNAMES[bg],4))
    end
    if COLNAMES[color] then -- specified only one color, let it be frground; inverse for bkground
      return bor(COLNAMES[color], lshift(bxor(COLNAMES[color],0x8),4))
    end
  end
  return 0x0F
end

local function FormColor (syntax, elem)
  if elem.color then
    return ProcessFullColor(elem.color)
  end
  local fgdefault = 0x0F
  local bgdefault = COLNAMES[syntax.bgcolor] or syntax.bgcolor or 0x00
  local fgcolor = band( COLNAMES[elem.fgcolor] or elem.fgcolor or fgdefault, 0x0F )
  local bgcolor = band( COLNAMES[elem.bgcolor] or elem.bgcolor or bgdefault, 0x0F )
  return bor(fgcolor, lshift(bgcolor,4))
end


local function CompileSyntax (Syntax, filename, classname)
  local function s_error (msg, numelement) -- syntax_error
    local s = ([[
%s
file:    %s
class:   %s
element: #%d]]):format(msg, filename, classname, numelement)
    error(s)
  end

  local Out = {}
  local tPatterns = {}

  for i,v in ipairs(Syntax) do
    local T = {}
    Out[i] = T
    if v.pattern==nil and v.pat_open==nil then
      s_error("neither field 'pattern' nor 'pat_open' specified", i)
    end
    if v.pattern then
      if type(v.pattern)~="string" then s_error("field 'pattern': string expected", i) end
      tPatterns[i] = "(".. v.pattern ..")"
    else
      if type(v.pat_open)~="string" then s_error("field 'pat_open': string expected", i) end
      if type(v.pat_close)~="string" then s_error("field 'pat_close': string expected", i) end
      tPatterns[i] = "(".. v.pat_open ..")"
      T.pat_close = v.pat_close
      T.pat_skip = type(v.pat_skip)=="string" and rex.new(v.pat_skip,"x")
      T.pat_continue = type(v.pat_continue)=="string" and rex.new(v.pat_continue,"x")
    end
    local pat = rex.new(v.pattern or v.pat_open) -- can throw error
    T.capstart = i==1 and 1 or (Out[i-1].capend + 1)
    T.capend = T.capstart + pat:capturecount()
    T.color = FormColor(Syntax, v)
    T.color_unfinished = ProcessFullColor(v.color_unfinished)
  end

  Out.pattern = rex.new(table.concat(tPatterns,"|"), "x");
  Out.bracketcolor = tonumber(Syntax.bracketcolor) or 0x1C
  Out.bracketmatch = Syntax.bracketmatch and true
  return Out
end

local function MakeGetString (EditorID, ymin, ymax, ymin_paint)
  local func = editor.GetStringW
  local y = ymin - 1
  return function()
    if y < ymax then
      y = y + 1
      return func(EditorID,y,3), y, y >= ymin_paint
    end
  end
end

local function RedrawSyntax (Syn, ei, GetNextString, Priority, extrapattern, extracolor)
  local current -- current item of Syn
  local pat_close
  local ID = ei.EditorID

  local openbracket, bstack, bpattern, opattern
  if Syn.bracketmatch then
    local char = editor.GetString(ID, nil, 3):sub(ei.CurPos, ei.CurPos)
    openbracket = char=="(" or char=="[" or char=="{"
    local closebracket = char==")" or char=="]" or char=="}"
    bstack = openbracket and 0 or closebracket and {}
    if bstack then
      if char=="(" or char==")" then
        bpattern, opattern = rex.new("([()])"), "(\0"
      elseif char=="[" or char=="]" then
        bpattern, opattern = rex.new("([\\[\\]])"), "[\0"
      else
        bpattern, opattern = rex.new("([{}])"), "{\0"
      end
      editor.AddColor(ID,ei.CurLine,ei.CurPos,ei.CurPos,acFlags,Syn.bracketcolor,Priority+1,Owner)
    end
  end

  for str, y, need_paint in GetNextString do
    if bstack and need_paint then
      if openbracket then
        if y >= ei.CurLine then
          local start = (y == ei.CurLine) and ei.CurPos+1 or 1
          while true do
            local from, to, br = bpattern:findW(str, start)
            if not from then break end
            start = to + 1
            if br == opattern then
              bstack = bstack + 1
            else
              if bstack > 0 then
                bstack = bstack - 1
              else
                editor.AddColor(ID, y, from, to, acFlags, Syn.bracketcolor, Priority+1, Owner)
                bstack = nil
                break
              end
            end
          end
        end
      else -- if closebracket
        if y <= ei.CurLine then
          local start = 1
          while true do
            local from, to, br = bpattern:findW(str, start)
            if not from then
              if y == ei.CurLine then bstack = nil; end
              break
            end
            start = to + 1
            if y == ei.CurLine and from == ei.CurPos then
              if bstack[1] then
                editor.AddColor(ID, bstack[#bstack-1], bstack[#bstack], bstack[#bstack],
                                acFlags, Syn.bracketcolor, Priority+1, Owner)
              end
              bstack = nil
              break
            else
              if br == opattern then
                bstack[#bstack+1] = y
                bstack[#bstack+1] = from
              else
                bstack[#bstack] = nil
                bstack[#bstack] = nil
              end
            end
          end
        end
      end
    end

    if need_paint and extrapattern then
      local start = 1
      while true do
        local from, to = extrapattern:findW(str, start)
        if not from then break end
        start = to>=from and to+1 or from+1
        if to >= from then
          editor.AddColor(ID, y, from, to, acFlags, extracolor, Priority+2, Owner)
        end
      end
    end

    local left = 1
    while true do
      if current == nil then -- outside long string or long comment
        local from, to, capts = Syn.pattern:tfindW(str, left)
        if from == nil then break end
        local color
        for _,v in ipairs(Syn) do
          if capts[v.capstart] then
            color = v.color
            if v.pat_close then
              current = v
              pat_close = rex.new(template(v.pat_close, unpack(capts,v.capstart+1,v.capend)), "x")
            end
            break
          end
        end
        if need_paint and color then
          editor.AddColor(ID, y, from, to, acFlags, color, Priority, Owner)
        end
        left = (to >= from and to or from) + 1

      else -- inside long string or long comment
        if current.pat_skip then
          local color = current.color
          local old_left = left
          local nextline

          local from, to = current.pat_skip:findW(str, left)
          if from then
            left = to + 1
          end

          if current.pat_continue then
            from, to = current.pat_continue:findW(str, left)
            if from == left then
              nextline = true
            else
              from, to = pat_close:findW(str, left)
              if from == nil then
                color = current.color_unfinished or color
                from, to = PatEndLine:findW(str, left)
              end
            end
          end

          if need_paint and old_left <= to then
            editor.AddColor(ID, y, old_left, to, acFlags, color, Priority, Owner)
          end

          if nextline == nil then
            left = to + 1
            current = nil
          else
            break
          end

        else
          local from, to = pat_close:findW(str, left)
          if not from then from, to = PatEndLine:findW(str, left) end
          if need_paint and left <= to then
            editor.AddColor(ID, y, left, to, acFlags, current.color, Priority, Owner)
          end
          if from <= to then
            left = to + 1
            current = nil
          else
            break
          end
        end

      end
    end
  end
end

local function RedrawExtraPattern (ei, Priority, extrapattern, extracolor)
  local ID = ei.EditorID
  local GetNextString = MakeGetString(ID,
    ei.TopScreenLine,
    math.min(ei.TopScreenLine+ei.WindowSizeY-1, ei.TotalLines),
    ei.TopScreenLine)

  while true do
    local str, y, need_paint = GetNextString()
    if not str then break end

    if need_paint then
      local start = 1
      while true do
        local from, to = extrapattern:findW(str, start)
        if not from then break end
        start = to>=from and to+1 or from+1
        if to >= from then
          editor.AddColor(ID, y, from, to, acFlags, extracolor, Priority+2, Owner)
        end
      end
    end
  end
end

local function ShowSettings()
  local Guid = win.Uuid("77D9B9B8-162A-4DEC-BF8F-16079D5F79E7")
  local Width = 73
  local X1, X2 = 5, math.floor(Width/2-1)
  local X3, X4 = X2+1, Width-6
  local Dlg = libDialog.NewDialog()

  Dlg.dbox            = {F.DI_DOUBLEBOX,     3,  1, Width-4, 12, 0,0,0,0, AppTitle}

  Dlg.sboxAll         = {F.DI_SINGLEBOX,    X1,  2,      X2,  7, 0,0,0,0, "All files"}
  Dlg.cbHighAll       = {F.DI_CHECKBOX,   X1+1,  3,       0,  0, 0,0,0,0, "&Highlight"}
  Dlg.cbFastAll       = {F.DI_CHECKBOX,   X1+1,  4,       0,  0, 0,0,0,0, "&Fast rendering"}
  Dlg.labFastLinesAll = {F.DI_TEXT,       X1+5,  5,       0,  0, 0,0,0,0, "&Lines"}
  Dlg.edFastLinesAll  = {F.DI_FIXEDIT,   X2-11,  5,    X2-2,  0, 0,0,"999999",F.DIF_MASKEDIT, ""}
  Dlg.label           = {F.DI_TEXT,       X1+1,  6,       0,  0, 0,0,0,0, "Color &priority"}
  Dlg.edPriorAll      = {F.DI_FIXEDIT,   X2-11,  6,    X2-2,  0, 0,0,"9999999999",F.DIF_MASKEDIT, ""}

  Dlg.sboxCur         = {F.DI_SINGLEBOX,    X3,  2,      X4,  7, 0,0,0,0, "Current file"}
  Dlg.cbHighCur       = {F.DI_CHECKBOX,   X3+1,  3,       0,  0, 0,0,0,0, "H&ighlight"}
  Dlg.cbFastCur       = {F.DI_CHECKBOX,   X3+1,  4,       0,  0, 0,0,0,0, "F&ast rendering"}
  Dlg.labFastLinesCur = {F.DI_TEXT,       X3+5,  5,       0,  0, 0,0,0,0, "Li&nes"}
  Dlg.edFastLinesCur  = {F.DI_FIXEDIT,   X4-11,  5,    X4-2,  0, 0,0,"999999",F.DIF_MASKEDIT, ""}
  Dlg.label           = {F.DI_TEXT,       X3+1,  6,       0,  0, 0,0,0,0, "Color p&riority"}
  Dlg.edPriorCur      = {F.DI_FIXEDIT,   X4-11,  6,    X4-2,  0, 0,0,"9999999999",F.DIF_MASKEDIT, ""}

  Dlg.btBench         = {F.DI_BUTTON,        5,  8,       0,  0, 0, 0,0,F.DIF_BTNNOCLOSE,"&Benchmark"}
  Dlg.edBench         = {F.DI_EDIT,         19,  8, Width-7,  0, 0, 0,0,F.DIF_READONLY, ""}
  Dlg.cbDebug         = {F.DI_CHECKBOX,      5,  9,       0,  0, 0,0,0,0, "&Debug mode"}
  Dlg.sep             = {F.DI_TEXT,         -1, 10,       0,  0, 0, 0,0,F.DIF_SEPARATOR,""}
  Dlg.btOk            = {F.DI_BUTTON,        0, 11,       0,  0, 0, 0,0,{DIF_DEFAULTBUTTON=1,DIF_CENTERGROUP=1},"OK"}
  Dlg.btCancel        = {F.DI_BUTTON,        0, 11,       0,  0, 0, 0,0,F.DIF_CENTERGROUP,"Cancel"}

  Dlg.cbHighAll.Selected = Config.On and 1 or 0
  Dlg.cbFastAll.Selected = Config.bFastMode and 1 or 0
  Dlg.edFastLinesAll.Data = Config.nFastLines
  Dlg.edPriorAll.Data = Config.nColorPriority
  Dlg.cbDebug.Selected = Config.bDebugMode and 1 or 0

  local ei = editor.GetInfo()
  local state = Editors[ei.EditorID]
  if state and state.Class then
    Dlg.cbHighCur.Selected = state.On and 1 or 0
    Dlg.cbFastCur.Selected = state.bFastMode and 1 or 0
    Dlg.edFastLinesCur.Data = state.nFastLines
    Dlg.edPriorCur.Data = state.nColorPriority
  else
    for i=Dlg.sboxCur.id, Dlg.edPriorCur.id do Dlg[i][9] = "DIF_DISABLE" end
  end

  local function CheckEnableFastLines (hDlg)
    if not state then return end
    local enab = Dlg.cbFastAll:GetCheck(hDlg)
    Dlg.labFastLinesAll:Enable(hDlg, enab)
    Dlg.edFastLinesAll:Enable(hDlg, enab)
    enab = Dlg.cbFastCur:GetCheck(hDlg)
    Dlg.labFastLinesCur:Enable(hDlg, enab)
    Dlg.edFastLinesCur:Enable(hDlg, enab)
  end

  local function RereadEditFields (hDlg)
    if not state then return end
    state.nFastLines = NormalizeFastLines(Dlg.edFastLinesCur:GetText(hDlg))
    Dlg.edFastLinesCur:SetText(hDlg, state.nFastLines)
    state.nColorPriority = NormalizeColorPriority(Dlg.edPriorCur:GetText(hDlg))
    Dlg.edPriorCur:SetText(hDlg, state.nColorPriority)
  end

  local function DlgProc (hDlg,Msg,Param1,Param2)
    if Msg == F.DN_INITDIALOG then
      CheckEnableFastLines(hDlg)
    elseif Msg == F.DN_BTNCLICK then
      if Param1 == Dlg.cbFastAll.id then
        CheckEnableFastLines(hDlg)
      elseif Param1 == Dlg.cbHighCur.id then
        if state then
          RereadEditFields(hDlg)
          state.On = not state.On
          editor.Redraw()
        end
      elseif Param1 == Dlg.cbFastCur.id then
        if state then
          CheckEnableFastLines(hDlg)
          state.bFastMode = not state.bFastMode
          RereadEditFields(hDlg)
          editor.Redraw()
        end
      elseif Param1 == Dlg.btBench.id then
        RereadEditFields(hDlg)
        Dlg.edBench:SetText(hDlg, "")
        local t1 = os.clock()
        for k=1,math.huge do
          editor.Redraw()
          local t2 = os.clock()
          if t2-t1 > 1 then
            t1=(t2-t1)*1000/k; break
          end
        end
        Dlg.edBench:SetText(hDlg, ("%f msec"):format(t1))
      end
    end
  end

  if Dlg.btOk.id == far.Dialog (Guid,-1,-1,Width,14,"Settings",Dlg,nil,DlgProc) then
    Config.On = (Dlg.cbHighAll.Selected ~= 0)
    Config.bFastMode = (Dlg.cbFastAll.Selected ~= 0)
    Config.nFastLines = NormalizeFastLines(Dlg.edFastLinesAll.Data)
    Config.nColorPriority = NormalizeColorPriority(Dlg.edPriorAll.Data)
    Config.bDebugMode = (Dlg.cbDebug.Selected ~= 0)
    if state then
      state.nFastLines = NormalizeFastLines(Dlg.edFastLinesCur.Data)
      state.nColorPriority = NormalizeColorPriority(Dlg.edPriorCur.Data)
    end

    far.ReloadDefaultScript = Config.bDebugMode
    Hist_Config:save()
    editor.Redraw()
  end
end

do
  local info = {
    Flags = bor(F.PF_EDITOR, F.PF_DISABLEPANELS),
    PluginMenuGuids = win.Uuid("BE07BD22-B463-4C8E-8BA2-2DA1497C9086"),
    PluginMenuStrings = { AppTitle },
  }
  function export.GetPluginInfo() return info end
end

local function SetClass (EditorID, Class, Activate)
  local state = {}
  Editors[EditorID] = state

  state.Class = Class
  state.On = Activate or Config.On
  state.bFastMode = Class and Class.fastlines and true or Config.bFastMode
  state.nFastLines = Class and Class.fastlines or Config.nFastLines
  state.nColorPriority = Config.nColorPriority
  state.extracolor = Extra.Color or 0xE0
end

local function SetExtraPattern (EditorID, extrapattern)
  local state = Editors[EditorID]
  if state then state.extrapattern = extrapattern end
end

local function GetExtraPattern (EditorID)
  local state = Editors[EditorID]
  return state and state.extrapattern
end

local function EnumMenuItems(items) -- add hot keys
  local n = 1
  for _,v in ipairs(items) do
    if v.text and not v.separator then
      if     n>=1 and n<=9   then v.text = "&"..n..". "..v.text
      elseif n==10           then v.text =  "&0. "..v.text
      elseif n>=11 and n<=36 then
        local s = string.char(string.byte("A")+n-11)
        v.text =  "&"..s..". "..v.text
      else
        break
      end
      n = n + 1
    end
  end
  return items
end

local function MenuSelectSyntax()
  local props = { Title="Select syntax", HelpTopic="SelectSyntax" }
  local items = { {text="Highlight OFF"; checked=true}, {separator=true} }
  local ei = editor.GetInfo()
  local state = Editors[ei.EditorID]

  for k,v in ipairs(Classes) do
    local m = k + 2
    items[m] = { text=v.name; syntax=v }
    if state and state.Class and state.Class.name == v.name then
      props.SelectIndex = m
      items[m].checked = state.On
      items[1].checked = nil
    end
  end

  local item = far.Menu(props, EnumMenuItems(items))
  if item then
    SetClass(ei.EditorID, item.syntax, true)
    editor.Redraw(ei.EditorID)
  end
end

local function HighlightExtra()
  local ei = editor.GetInfo()
  local state = Editors[ei.EditorID]
  local extracolor = state.extracolor

  local sepflags = bor(F.DIF_BOXCOLOR, F.DIF_SEPARATOR)
  local editflags = bor(F.DIF_HISTORY, F.DIF_USELASTHISTORY)
  local Dlg = libDialog.NewDialog()
  local s1 = "&Search for:"
  local x = s1:len()

  Dlg.frame       = {"DI_DOUBLEBOX", 3, 1, 72, 8, 0, 0, 0, 0, "Highlight extra"}
  Dlg.lab         = {"DI_TEXT",      5, 2,  0, 2, 0, 0, 0, 0, s1}
  Dlg.sSearchPat  = {"DI_EDIT",    5+x, 2, 70, 2, 0, "SearchText", 0, editflags, ""}
  Dlg.sep         = {"DI_TEXT",      5, 3,  0, 0, 0, 0, 0, sepflags, ""}
  Dlg.bCaseSens   = {"DI_CHECKBOX",  5, 4,  0, 0, 0, 0, 0, 0, "&Case sensitive"}
  Dlg.bRegExpr    = {"DI_CHECKBOX", 26, 4,  0, 0, 0, 0, 0, 0, "Re&g. expression"}
  Dlg.labColor    = {"DI_TEXT",     54, 4,  0, 0, 0, 0, 0, 0, "Text Text"}
  Dlg.bWholeWords = {"DI_CHECKBOX",  5, 5,  0, 0, 0, 0, 0, 0, "&Whole words"}
  Dlg.bExtended   = {"DI_CHECKBOX", 26, 5,  0, 0, 0, 0, 0, 0, "&Ignore spaces"}
  Dlg.btColor     = {"DI_BUTTON",   54, 5,  0, 0, 0, 0, 0, F.DIF_BTNNOCLOSE, "C&olor"}
  Dlg.sep         = {"DI_TEXT",     -1, 6,  0, 0, 0, 0, 0, sepflags,""}
  Dlg.btOk        = {"DI_BUTTON",    0, 7,  0, 0, 0, 0, 0, {DIF_DEFAULTBUTTON=1,DIF_CENTERGROUP=1},"OK"}
  Dlg.btReset     = {"DI_BUTTON",    0, 7,  0, 0, 0, 0, 0, F.DIF_CENTERGROUP,"&Reset"}
  Dlg.btCancel    = {"DI_BUTTON",    0, 7,  0, 0, 0, 0, 0, F.DIF_CENTERGROUP,"Cancel"}

  local function CheckRegexChange (hDlg)
    local bRegex = Dlg.bRegExpr:GetCheck(hDlg)

    if bRegex then Dlg.bWholeWords:SetCheck(hDlg, false) end
    Dlg.bWholeWords:Enable(hDlg, not bRegex)

    --if not bRegex then Dlg.bExtended:SetCheck(hDlg, false) end
    --Dlg.bExtended:Enable(hDlg, bRegex)
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      CheckRegexChange (hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1 == Dlg.btColor.id then
        local c = far.ColorDialog(extracolor)
        if c then
          extracolor = c
          hDlg:send(F.DM_REDRAW)
        end
      else
        CheckRegexChange (hDlg)
      end
    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Dlg.labColor.id then
        param2[1] = extracolor
        return param2
      end
    elseif msg == F.DN_CLOSE then
      if param1 == Dlg.btReset.id then
        SetExtraPattern(editor.GetInfo().EditorID, nil)
      elseif param1 == Dlg.btOk.id then
        local data = {}
        libDialog.SaveDataDyn(hDlg, Dlg, data)
        local sSearchPat = data.sSearchPat
        local flags, syn = "", nil
        if not data.bCaseSens then flags = flags.."i" end
        if data.bExtended     then flags = flags.."x" end
        if not data.bRegExpr  then syn = "ASIS" end
        if data.bWholeWords then
          syn = nil
          local sNeedEscape = "[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]"
          sSearchPat = "\\b" .. sSearchPat:gsub(sNeedEscape, "\\%1") .. "\\b"
        end
        local ok, r = pcall(rex.new, sSearchPat, flags, syn)
        if ok then
          SetExtraPattern(editor.GetInfo().EditorID, r)
          for k,v in pairs(data) do Extra[k]=v end
          state.extracolor = extracolor
          Extra.Color = extracolor
          Hist_Extra:save()
        else
          ErrMsg(r)
          return 0
        end
      end
    end
  end

  Dlg.bCaseSens.Selected   = Extra.bCaseSens   and 1 or 0
  Dlg.bRegExpr.Selected    = Extra.bRegExpr    and 1 or 0
  Dlg.bWholeWords.Selected = Extra.bWholeWords and 1 or 0
  Dlg.bExtended.Selected   = Extra.bExtended   and 1 or 0

  local Guid = win.Uuid("A6E9A4FF-E9B4-4F16-9404-D5B8A515D16E")
  far.Dialog (Guid,-1,-1,76,10,"HighlightExtra",Dlg,0,DlgProc)
end

function export.Open (From, Guid, Item)
  if From == F.OPEN_EDITOR then
    local item, pos = far.Menu({Title=AppTitle, SelectIndex=MenuPos}, {
      {text="&1. Select syntax";   act=MenuSelectSyntax; },
      {text="&2. Highlight extra"; act=HighlightExtra;   },
      {text="&3. Settings";        act=ShowSettings;     }
    })
    if item then
      MenuPos = pos
      item.act()
    end
  elseif From == F.OPEN_FROMMACRO then
    if far.MacroGetArea() == F.MACROAREA_EDITOR then
      if Item[1] == "own" then
        if Item[2] == "SelectSyntax"       then MenuSelectSyntax()
        elseif Item[2] == "HighlightExtra" then HighlightExtra()
        elseif Item[2] == "Settings"       then ShowSettings()
        end
      end
    end
  end
end

local FirstLineMap = {}
local function OnNewEditor (id, ei)
  if ei then
    local firstline = editor.GetString(id,1,3):lower()
    local name = firstline:match("highlight:%s*([%w_]+)")
    if name and FirstLineMap[name] then
      SetClass(id, FirstLineMap[name], false)
    else
      for _,class in ipairs(Classes) do
        if far.ProcessName("PN_CMPNAMELIST", class.filemask, ei.FileName, "PN_SKIPPATH") then
          SetClass(id, class, false); break
        end
      end
    end
    if not Editors[id] then
      SetClass(id, nil, false)
    end
  end
end

function export.ProcessEditorEvent (id, event, param)
  if event == F.EE_READ then
    if not Editors[id] then
      OnNewEditor(id, editor.GetInfo(id))
    end
  elseif event == F.EE_CLOSE then
    Editors[id] = nil
  elseif event == F.EE_REDRAW then
    local ei = editor.GetInfo(id)
    if not Editors[id] then
      OnNewEditor(id, ei)
    end
    local state = Editors[id]
    if state and ei then
      if state.Class and state.On then
        local GetNextString = MakeGetString(
            ei.EditorID,
            state.bFastMode and math.max(ei.TopScreenLine-state.nFastLines, 1) or 1,
            math.min(ei.TopScreenLine+ei.WindowSizeY-1, ei.TotalLines),
            ei.TopScreenLine)
        RedrawSyntax(state.Class.CS, ei, GetNextString, state.nColorPriority,
            state.extrapattern, state.extracolor)
      elseif state.extrapattern then
        RedrawExtraPattern(ei, state.nColorPriority, state.extrapattern, state.extracolor)
      end
    end
  end
end

local AddClass_filename
local function AddClass (t)
  if type(t)~="table"           then error("function Class() called with a non-table argument",2) end
  if type(t.syntax)~="table"    then error("field 'syntax': a table expected",2) end
  if type(t.name)~="string"     then error("field 'name': a string expected",2) end
  if type(t.filemask)~="string" then error("field 'filemask': a string expected",2) end
  if t.fastlines and type(t.fastlines)~="number"
                                then error("field 'fastlines': a number expected",2) end

  local class = { syntax=t.syntax; name=t.name; filemask=t.filemask }
  if type(t.firstline) == "string" then
    FirstLineMap[t.firstline:lower()] = class
  end
  class.filename = AddClass_filename
  class.CS = CompileSyntax(t.syntax, t.filename, t.name)
  if t.fastlines then
    class.fastlines = math.floor(math.max(0, t.fastlines))
  end
  Classes[#Classes+1] = class
end

do
  far.RecursiveSearch(far.PluginStartupInfo().ModuleDir.."syntaxes", "*.lua",
    function (item, fullpath)
      if not item.FileAttributes:find("d") then
        local f, msg = loadfile(fullpath)
        if f then
          AddClass_filename = fullpath
          local ok, msg = pcall(setfenv(f, {Class=AddClass}))
          if not ok then ErrMsg(msg, nil, "wl") end
        else
          ErrMsg(msg)
        end
      end
    end)

  table.sort(Classes,
    function(a, b) return win.CompareString(a.name, b.name, "u", "cS") < 0 end) -- for menu
end
