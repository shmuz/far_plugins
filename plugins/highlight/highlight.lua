-- Started: 2014-10-06
-- Author: Shmuel Zeigerman

-- luacheck: globals Editors

local Sett = require "far2.settings"
local sd   = require "far2.simpledialog"

local function ErrMsg (msg, title, flags)
  far.Message(msg, title or "[Highlight] Error", nil, (flags or "").."w")
end

-- Global variables
Editors = Editors or {}

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

-- Constants
local AppTitle, Owner
local PatEndLine
local F = far.Flags
local band, bor, bxor, lshift = bit64.band, bit64.bor, bit64.bxor, bit64.lshift
local rex = regex
local acFlags = bor(F.ECF_TABMARKCURRENT or 0, F.ECF_AUTODELETE) -- luacheck: ignore
local SETTINGS_KEY, SETTINGS_NAME = "shmuz", "plugin_highlight"

local Classes = {}
local Hist, Config, Extra

local function LoadConfig()
  Hist = Sett.mload(SETTINGS_KEY, SETTINGS_NAME) or {}
  Config = Sett.field(Hist, "Config")
  Config.nColorPriority = NormalizeColorPriority(Config.nColorPriority)
  Config.nFastLines = NormalizeFastLines(Config.nFastLines)
  if Config.bFastMode==nil then Config.bFastMode=true end -- default=true
  if Config.On==nil then Config.On=true end -- default=true
  Extra = Sett.field(Hist, "ExtraData")
  Sett.field(Hist, "Names")
  far.ReloadDefaultScript = Config.bDebugMode
end

local function SaveConfig()
  Sett.msave(SETTINGS_KEY, SETTINGS_NAME, Hist)
end

-- NOT USED: IS IT REALLY NEEDED?
local function toreal(id, y, pos) return editor.TabToReal(id, y, pos) end -- luacheck: ignore

local function escape_literal(s)
  return (s:gsub("([\\^$.|?*+()[{%]#} \t])", "\\%1"))
end

local function template(str, ...)
  local rep = {...}
  str = str:gsub("%%(.)",
    function(c)
      local n = tonumber(c)
      return n and rep[n] and escape_literal(win.Utf16ToUtf8(rep[n])) or c
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
  local tp = type(color)
  if tp == "number" then
    return color
  elseif tp == "string" then
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

local SYNT_ERROR = [[
%s
file:    %s
class:   %s
element: #%d]]

local function CompileSyntax (Syntax, filename, classname)
  local function s_error (msg, numelement) -- syntax_error
    local s = SYNT_ERROR:format(msg, filename, classname, numelement)
    error(s)
  end

  local Out = {}
  local tPatterns = {}

  for i,v in ipairs(Syntax) do
    local T = {}
    Out[i] = T
    if v.pattern then
      if type(v.pattern)~="string" then s_error("field 'pattern': string expected", i) end
      tPatterns[i] = "(".. v.pattern ..")"
    elseif v.pat_open then
      if type(v.pat_open)~="string" then s_error("field 'pat_open': string expected", i) end
      if type(v.pat_close)~="string" then s_error("field 'pat_close': string expected", i) end
      tPatterns[i] = "(".. v.pat_open ..")"
      T.pat_close = v.pat_close
      T.pat_skip = type(v.pat_skip)=="string" and rex.new(v.pat_skip,"x")
      T.pat_continue = type(v.pat_continue)=="string" and rex.new(v.pat_continue,"x")
    else
      s_error("neither field 'pattern' nor 'pat_open' specified", i)
    end
    local pat = rex.new(v.pattern or v.pat_open) -- can throw error
    T.capstart = i==1 and 1 or (Out[i-1].capend + 1)
    T.capend = T.capstart + pat:bracketscount() - 1
    T.color = FormColor(Syntax, v)
    T.color_unfinished = ProcessFullColor(v.color_unfinished)
  end

  Out.pattern = rex.new(table.concat(tPatterns,"|"), "x");
  Out.bracketcolor = tonumber(Syntax.bracketcolor) or 0x1C
  Out.bracketmatch = Syntax.bracketmatch and true
  Out.defaultcolor = Syntax.defaultcolor or 0x1B -- "aqua on darkblue"
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

  local openbracket, bstack, bpattern, opattern, posbracket
  if Syn.bracketmatch then
    -- Try 2 positions: current and previous to current.
    -- The current position is checked first.
    local curstr = editor.GetString(ID, nil, 3)
    for k=0, ei.CurPos==1 and 0 or 1 do
      posbracket = ei.CurPos-k
      local char = curstr:sub(posbracket, posbracket)
      openbracket = char=="(" or char=="[" or char=="{"
      local closebracket = char==")" or char=="]" or char=="}"
      if openbracket or closebracket then
        bstack = openbracket and 0 or {}
        if char=="(" or char==")" then
          bpattern, opattern = rex.new("([()])"), "(\0"
        elseif char=="[" or char=="]" then
          bpattern, opattern = rex.new("([\\[\\]])"), "[\0"
        else
          bpattern, opattern = rex.new("([{}])"), "{\0"
        end
        editor.AddColor(ID, ei.CurLine, posbracket, posbracket, acFlags,
                        Syn.bracketcolor, Priority+1, Owner)
        break
      end
    end
  end

  for str, y, need_paint in GetNextString do
    editor.AddColor(ID, y, ei.LeftPos, ei.LeftPos+ei.WindowSizeX, acFlags, Syn.defaultcolor, 0, Owner)
    if bstack and need_paint then
      if openbracket then
        if y >= ei.CurLine then
          local start = (y == ei.CurLine) and posbracket+1 or 1
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
            local N = #bstack
            if y == ei.CurLine and from == posbracket then
              if N ~= 0 then
                editor.AddColor(ID, bstack[N-1], bstack[N], bstack[N],
                                acFlags, Syn.bracketcolor, Priority+1, Owner)
              end
              bstack = nil
              break
            else
              if br == opattern then
                bstack[N+1] = y
                bstack[N+2] = from
              elseif N ~= 0 then
                bstack[N]   = nil
                bstack[N-1] = nil
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
  local Width = 73
  local X1, X2 = 5, math.floor(Width/2-1)
  local X3, X4 = X2+1, Width-6

  local Items = {
    guid = "77D9B9B8-162A-4DEC-BF8F-16079D5F79E7";
    help = "Settings";
    width = Width;
    {tp="dbox"; text=AppTitle; },

    {tp="sbox";    x1=X1; x2=X2; text="All files"; y1=2; y2=7; },
    {tp="chbox";   x1=X1+1; text="&Highlight"; y1=3;  name="cbHighAll"; },
    {tp="chbox";   x1=X1+1; text="&Fast rendering";   name="cbFastAll"; },
    {tp="text";    x1=X1+5, text="&Lines"; x2=X2-13;  name="labFastLinesAll"; },
    {tp="fixedit"; x1=X2-11, x2=X2-2; ystep=0; mask="999999"; name="edFastLinesAll"; },
    {tp="text";    x1=X1+1; text="Color &priority"; x2=X2-13;                        },
    {tp="fixedit"; x1=X2-11, x2=X2-2; ystep=0; mask="9999999999"; name="edPriorAll"; },

    {tp="sbox";    x1=X3; x2=X4; text="Current file"; name="sboxCur"; y1=2; y2=7; },
    {tp="chbox";   x1=X3+1; text="H&ighlight"; y1=3;  name="cbHighCur";       },
    {tp="chbox";   x1=X3+1; text="F&ast rendering";   name="cbFastCur";       },
    {tp="text";    x1=X3+5, text="Li&nes"; x2=X4-13;  name="labFastLinesCur"; },
    {tp="fixedit"; x1=X4-11, x2=X4-2; ystep=0; mask="999999"; name="edFastLinesCur"; },
    {tp="text";    x1=X3+1; text="Color p&riority"; x2=X4-13;                        },
    {tp="fixedit"; x1=X4-11, x2=X4-2; ystep=0; mask="9999999999"; name="edPriorCur"; },

    {tp="butt";    ystep=2; text="&Benchmark";        name="btBench"; btnnoclose=1; },
    {tp="edit";    ystep=0; x1=19; x2=Width-7;        name="edBench"; readonly=1;   },
    {tp="chbox";   text="&Debug mode";                name="cbDebug"; },
    {tp="sep" },
    {tp="butt";    default=1; centergroup=1; text="OK";    },
    {tp="butt";    cancel=1; centergroup=1; text="Cancel"; },
  }
  local dlg = sd.New(Items)
  local Pos,Elem = dlg:Indexes()

  Elem.cbHighAll.val = Config.On
  Elem.cbFastAll.val = Config.bFastMode
  Elem.edFastLinesAll.val = Config.nFastLines
  Elem.edPriorAll.val = Config.nColorPriority
  Elem.cbDebug.val = Config.bDebugMode

  local ei = editor.GetInfo()
  local state = Editors[ei.EditorID]
  if state and state.Class then
    Elem.cbHighCur.val = state.On
    Elem.cbFastCur.val = state.bFastMode
    Elem.edFastLinesCur.val = state.nFastLines
    Elem.edPriorCur.val = state.nColorPriority
  else
    for i=Pos.sboxCur, Pos.edPriorCur do Items[i].disable=1 end
  end

  local function CheckEnableFastLines (hDlg)
    if not state then return end
    local enab = hDlg:GetCheck(Pos.cbFastAll) == 1
    hDlg:Enable(Pos.labFastLinesAll, enab)
    hDlg:Enable(Pos.edFastLinesAll, enab)
    enab = hDlg:GetCheck(Pos.cbFastCur) == 1
    hDlg:Enable(Pos.labFastLinesCur, enab)
    hDlg:Enable(Pos.edFastLinesCur, enab)
  end

  local function RereadEditFields (hDlg)
    if not state then return end
    state.nFastLines = NormalizeFastLines(hDlg:GetText(Pos.edFastLinesCur))
    hDlg:SetText(Pos.edFastLinesCur, state.nFastLines)
    state.nColorPriority = NormalizeColorPriority(hDlg:GetText(Pos.edPriorCur))
    hDlg:SetText(Pos.edPriorCur, state.nColorPriority)
  end

  function Items.proc (hDlg,Msg,Param1,Param2)
    if Msg == F.DN_INITDIALOG then
      CheckEnableFastLines(hDlg)
    elseif Msg == F.DN_BTNCLICK then
      if Param1 == Pos.cbFastAll then
        CheckEnableFastLines(hDlg)
      elseif Param1 == Pos.cbHighCur then
        if state then
          RereadEditFields(hDlg)
          state.On = not state.On
          editor.Redraw()
        end
      elseif Param1 == Pos.cbFastCur then
        if state then
          CheckEnableFastLines(hDlg)
          state.bFastMode = not state.bFastMode
          RereadEditFields(hDlg)
          editor.Redraw()
        end
      elseif Param1 == Pos.btBench then
        RereadEditFields(hDlg)
        hDlg:SetText(Pos.edBench, "")
        local t1 = os.clock()
        for k=1,math.huge do
          editor.Redraw()
          local t2 = os.clock()
          if t2-t1 > 1 then
            t1=(t2-t1)*1000/k; break
          end
        end
        hDlg:SetText(Pos.edBench, ("%f msec"):format(t1))
      end
    end
  end

  local out = dlg:Run()
  if out then
    Config.On = out.cbHighAll
    Config.bFastMode = out.cbFastAll
    Config.nFastLines = NormalizeFastLines(out.edFastLinesAll)
    Config.nColorPriority = NormalizeColorPriority(out.edPriorAll)
    Config.bDebugMode = out.cbDebug
    if state then
      state.nFastLines = NormalizeFastLines(out.edFastLinesCur)
      state.nColorPriority = NormalizeColorPriority(out.edPriorCur)
    end

    far.ReloadDefaultScript = Config.bDebugMode
    SaveConfig()
    editor.Redraw()
  end
end

function export.GetPluginInfo()
  local guid = win.Uuid("BE07BD22-B463-4C8E-8BA2-2DA1497C9086")
  return {
    Flags = bor(F.PF_EDITOR, F.PF_DISABLEPANELS);
    PluginMenuGuids = guid;
    PluginMenuStrings = { AppTitle };
    PluginConfigGuids = guid;
    PluginConfigStrings = { AppTitle };
  }
end

local function SelectEnabledTypes()
  local keys = "Enter MsLClick"
  local props = {Title="Enable/disable types"; Bottom=keys}
  local items = {}
  for k,v in pairs(Hist.Names) do
    local t = {text=k; checked=v;}
    table.insert(items, t)
  end
  table.sort(items, function(a,b) return a.text < b.text end)
  while true do
    local item, pos = far.Menu(props, items)
    if not item then break end
    if pos >= 1 then
      local it = items[pos]
      it.checked = not it.checked
      Hist.Names[it.text] = it.checked
      props.SelectIndex = pos
    end
  end
  return props.SelectIndex ~= nil
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
  local s1 = "&Search for:"
  local x = s1:len()

  local Items = {
    guid = "A6E9A4FF-E9B4-4F16-9404-D5B8A515D16E";
    help = "HighlightExtra";
    width = 76;
    {tp="dbox"; text="Highlight extra"; },
    {tp="text"; text=s1; },
    {tp="edit"; x1=5+x, x2=70; ystep=0; hist="SearchText"; name="sSearchPat"; uselasthistory=1; },
    {tp="sep"; },

    {tp="chbox"; x1=5;  text="&Case sensitive";   name="bCaseSens";          },
    {tp="chbox"; x1=26; text="Re&g. expression";  name="bRegExpr"; ystep=0;  },
    {tp="text";  x1=54, text="Text Text"; x2=62;  name="labColor"; ystep=0;  },

    {tp="chbox"; x1=5;  text="&Whole words";      name="bWholeWords";        },
    {tp="chbox"; x1=26; text="&Ignore spaces";    name="bExtended"; ystep=0; },
    {tp="butt";  x1=54, text="C&olor";            name="btColor";   ystep=0; btnnoclose=1; },
    {tp="sep"; },

    {tp="butt"; centergroup=1; default=1; text="OK";     name="btOk";        },
    {tp="butt"; centergroup=1;            text="&Reset"; name="btReset";     },
    {tp="butt"; centergroup=1; cancel=1;  text="Cancel";                     },
  }
  local dlg = sd.New(Items)
  local Pos,Elem = dlg:Indexes()

  local function CheckRegexChange (hDlg)
    local bRegex = hDlg:GetCheck(Pos.bRegExpr) == 1

    if bRegex then hDlg:SetCheck(Pos.bWholeWords, false) end
    hDlg:Enable(Pos.bWholeWords, not bRegex)

    if not bRegex then hDlg:SetCheck(Pos.bExtended, false) end
    hDlg:Enable(Pos.bExtended, bRegex)
  end

  local function closeaction(hDlg, param1, data)
    if param1 == Pos.btReset then
      SetExtraPattern(ei.EditorID, nil)
    elseif param1 == Pos.btOk then
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
        SetExtraPattern(ei.EditorID, r)
        for k,v in pairs(data) do Extra[k]=v end
        state.extracolor = extracolor
        Extra.Color = extracolor
        SaveConfig()
      else
        ErrMsg(r)
        return 0
      end
    end
  end

  function Items.proc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      CheckRegexChange (hDlg)
    elseif msg == F.DN_BTNCLICK then
      if param1 == Pos.btColor then
        local color = far.ColorDialog(extracolor)
        if color then
          extracolor = color
          hDlg:Redraw()
        end
      else
        CheckRegexChange(hDlg)
      end
    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Pos.labColor then
        param2[1] = extracolor
        return param2
      end
    elseif msg == F.DN_CLOSE then
      return closeaction(hDlg, param1, param2)
    end
  end

  Elem.bCaseSens.val   = Extra.bCaseSens
  Elem.bRegExpr.val    = Extra.bRegExpr
  Elem.bWholeWords.val = Extra.bWholeWords
  Elem.bExtended.val   = Extra.bExtended

  dlg:Run()
end

function export.Open (From, Guid, Item)
  if From == F.OPEN_EDITOR then
    local item = far.Menu({Title=AppTitle}, {
      {text="&1. Select syntax";   act=MenuSelectSyntax; },
      {text="&2. Highlight extra"; act=HighlightExtra;   },
      {text="&3. Settings";        act=ShowSettings;     },
    })
    if item then
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
    local name = firstline:match('highlight:%s*"([^"]+)"')
              or firstline:match('highlight:%s*(%S+)')
    if name and FirstLineMap[name] then
      SetClass(id, FirstLineMap[name], false)
    else
      for _,class in ipairs(Classes) do
        local FileName = ei.FileName or "Not-a-file"
        if far.ProcessName("PN_CMPNAMELIST", class.filemask, FileName, "PN_SKIPPATH") then
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

local function AddClass (def)
  local class = { syntax=def.syntax; name=def.name; filemask=def.filemask }
  if type(def.firstline) == "string" then
    FirstLineMap[def.firstline:lower()] = class
  end
  class.filename = def.fullpath
  class.CS = CompileSyntax(def.syntax, def.fullpath, def.name)
  if def.fastlines then
    class.fastlines = math.floor(math.max(0, def.fastlines))
  end
  Classes[#Classes+1] = class
end

local function LoadSyntaxFiles()
  Classes = {}
  local defs, guard, curNames = {}, {}, {}

  local function OnFile(item, fullpath)
    if not item.FileAttributes:find("d") then
      local f, msg = loadfile(fullpath)
      if f then
        local function AddDef(def)
          if type(def)=="table" and type(def.name)=="string" and not guard[def.name]
              and type(def.syntax)=="table" and type(def.filemask)=="string"
              and (not def.fastlines or type(def.fastlines)=="number")
          then
            if Hist.Names[def.name] ~= false then -- nil is treated as true
              curNames[def.name] = true
              guard[def.name] = true
              def.fullpath = fullpath
              table.insert(defs, def)
            else
              curNames[def.name] = false
            end
          else
            ErrMsg("Incorrect Class definition in\n" .. item.FileName)
          end
        end
        local ok, msg2 = pcall(setfenv(f, {Class = AddDef}))
        if not ok then ErrMsg(msg2, nil, "wl") end
      else
        ErrMsg(msg)
      end
    end
  end

  local dir = win.GetEnv("FARPROFILE").."\\Plugins\\Highlight\\syntaxes"
  far.RecursiveSearch(dir, "*.lua", OnFile)
  if not defs[1] then
    dir = far.PluginStartupInfo().ModuleDir.."syntaxes"
    far.RecursiveSearch(dir, "*.lua", OnFile)
  end
  Hist.Names = curNames

  for _, def in ipairs(defs) do
    local ok, msg = pcall(AddClass, def)
    if not ok then ErrMsg(msg, nil, "wl") end
  end

  table.sort(Classes,
    function(a, b) return win.CompareString(a.name, b.name, "u", "cS") < 0 end) -- for menu
end

function export.Configure()
  if SelectEnabledTypes() then
    SaveConfig()
    LoadSyntaxFiles()
  end
end

local function InitUpvalues()
  local gInfo = export.GetGlobalInfo()
  AppTitle, Owner = gInfo.Title, gInfo.Guid
  PatEndLine = rex.new("$")
end

local function main()
  InitUpvalues()
  LoadConfig()
  LoadSyntaxFiles()
end

main()
