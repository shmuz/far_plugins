-- lfs_editengine.lua
-- luacheck: globals _Plugin

local M          = require "lfs_message"
local Common     = require "lfs_common"
local Editors    = require "lfs_editors"

local CustomMessage = require "far2.message"
local CustomMenu = require "far2.custommenu"

local F = far.Flags
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local lenW = win.lenW
local Utf16 = win.Utf8ToUtf16


-- This function is that long because FAR API does not supply needed
-- information directly.
local function GetSelectionInfo (EditorId)
  local GetString = editor.GetString

  local Info = editor.GetInfo(EditorId)
  if Info.BlockType == F.BTYPE_NONE then return end

  local egs = GetString(EditorId, Info.BlockStartLine, 1)
  if not egs then return end

  local out = {
    BlockType = Info.BlockType;
    StartLine = Info.BlockStartLine;
    StartPos = egs.SelStart;
  }
  if Info.BlockType == F.BTYPE_COLUMN then
    out.TabStartPos = editor.RealToTab(EditorId, Info.BlockStartLine, egs.SelStart)
    out.TabEndPos = editor.RealToTab(EditorId, Info.BlockStartLine, egs.SelEnd)
  end

  -- binary search for a non-block line
  local h = 100 -- arbitrary small number
  local from = Info.BlockStartLine
  local to = from + h
  while to <= Info.TotalLines do
    egs = GetString(EditorId, to, 1)
    if not egs then return end
    if egs.SelStart < 1 or egs.SelEnd == 0 then break end
    h = h * 2
    to = from + h
  end
  if to > Info.TotalLines then to = Info.TotalLines end

  -- binary search for the last block line
  while from ~= to do
    local curr = floor((from + to + 1) / 2)
    egs = GetString(EditorId, curr, 1)
    if not egs then return end
    if egs.SelStart < 1 or egs.SelEnd == 0 then
      if curr == to then break end
      to = curr   -- curr was not selected
    else
      from = curr -- curr was selected
    end
  end

  egs = GetString(EditorId, from, 1)
  if not egs then return end

  out.EndLine = from
  out.EndPos = egs.SelEnd

  -- restore current position, since FastGetString() changed it
  editor.SetPosition(EditorId, Info)
  return out
end


-- All arguments must be in UTF-8.
local function GetReplaceChoice (aTitle, s_found, s_rep)
  s_found = s_found:gsub("%z", " ")
  if type(s_rep) == "string" then s_rep = s_rep:gsub("%z", " ") end
  local color = CustomMessage.GetInvertedColor("COL_DIALOGTEXT")
  local msg = s_rep~=true and
    {
      M.MUserChoiceReplace,"\n",
      { text=s_found, color=color },"\n",
      M.MUserChoiceWith,"\n",
      { text=s_rep, color=color },
    } or
    {
      M.MUserChoiceDeleteLine,"\n",
      { text=s_found, color=color },
    }
  local buttons = s_rep~=true and M.MUserChoiceButtons or M.MUserChoiceDeleteButtons
  local guid = win.Uuid("7f7ca8d3-f241-4018-97aa-ad4013188df8")
  local c = CustomMessage.Message(msg, aTitle, buttons, "c", nil, guid)
  return c==1 and "yes" or c==2 and "all" or c==3 and "no" or "cancel"
end


local function EditorSelect (b)
  if b then
    local startPos = b.TabStartPos or b.StartPos
    local endPos = b.TabEndPos or b.EndPos
    editor.Select(nil, b.BlockType, b.StartLine, startPos, endPos-startPos+1, b.EndLine-b.StartLine+1)
  else
    editor.Select(nil, "BTYPE_NONE")
  end
end


-- This function replaces the old 9-line function.
-- The reason for applying a new, much more complicated algorithm is that
-- the old algorithm has unacceptably poor performance on long subjects.
local function find_back (patt, ufind_method, s, init)
  local outFrom, outTo, out = ufind_method(patt, s, 1)
  if outFrom == nil or outTo >= init then return nil end

  local BEST = 1
  local stage = 1
  local MIN, MAX = 2, init
  local start = ceil((MIN+MAX)/2)

  while true do
    local resFrom, resTo, res = ufind_method(patt, s, start)
    if resFrom and resTo >= init then res=nil end
    local ok = false
    ---------------------------------------------------------------------------
    if stage == 1 then -- maximize outTo
      if res then
        if resTo > outTo then
          BEST, out, ok = start, res, true
          outFrom, outTo = resFrom, resTo
        elseif resTo == outTo then
          ok = true
        end
      end
      if MIN >= MAX then
        stage = 2
        MIN, MAX = 2, BEST-1
        start = floor((MIN+MAX)/2)
      elseif ok then
        MIN = start+1
        start = ceil((MIN+MAX)/2)
      else
        MAX = start-1
        start = floor((MIN+MAX)/2)
      end
    ---------------------------------------------------------------------------
    else -- minimize outFrom
      if res and resTo >= outTo then
        if resFrom < outFrom then
          out, ok = res, true
          outFrom, outTo = resFrom, resTo
        elseif resFrom == outFrom then
          ok = true
        end
      end
      if MIN >= MAX then
        break
      elseif ok then
        MAX = start-1
        start = floor((MIN+MAX)/2)
      else
        MIN = start+1
        start = ceil((MIN+MAX)/2)
      end
    end
    ---------------------------------------------------------------------------
  end
  return outFrom, outTo, out
end


--- ScrollToPosition -----------------------------------------------------------
-- @param row         (number of) line to show in the screen center (nil means using current line)
-- @param pos         cursor position in the current line
-- @param from        start position of selection
-- @param to          end position of selection
-- @param scroll      extra number of lines to scroll; "none"=no scroll; "lazy"=only if necessary;
--------------------------------------------------------------------------------
local function ScrollToPosition (row, pos, from, to, scroll)
  local Info = editor.GetInfo()
  local LeftPos = 1
  -- left-most (or right-most) char is not visible
  if to > Info.WindowSizeX then
    local SelLen = to - from + 1
    if SelLen >= Info.WindowSizeX then
      LeftPos = from
    else
      LeftPos = from - floor( 3*(Info.WindowSizeX - SelLen) / 4 )
      if LeftPos < 1 then LeftPos = 1 end
    end
  end

  row = row or Info.CurLine
  local TopScreenLine = nil
  if (scroll == "+lazy") or (scroll == "-lazy") then
    if row < Info.TopScreenLine or row >= Info.TopScreenLine + Info.WindowSizeY then
      scroll = floor(Info.WindowSizeY * (scroll=="+lazy" and 0.25 or 0.75))
      TopScreenLine = max(1, row - scroll)
    end
  elseif scroll ~= "none" then
    scroll = (scroll or 0) + floor(Info.WindowSizeY / 2)
    TopScreenLine = max(1, row - scroll)
  end

  editor.SetPosition(nil, {
    CurLine = row,
    TopScreenLine = TopScreenLine,
    LeftPos = LeftPos,
    CurPos = pos,
  })
end


local function SelectItemInEditor (item)
  local offset = item.seloffset - item.offset
  local fr, to = item.fr + offset, item.to + offset
  ScrollToPosition(item.lineno, to, fr, to, -10)
  editor.Select(nil, "BTYPE_STREAM", item.lineno, fr, to<=fr and 1 or to-fr+1, 1)
  editor.Redraw()
end


local Timing = {}
local TimingMeta = {__index=Timing}
local function NewTiming()
  local curr = os.clock()
  local self = {
    lastclock   = curr,
    tStart      = curr,
    last_update = 0,
    nOp         = 0,
    nOpMax      = 5,
  }
  return setmetatable(self, TimingMeta)
end

function Timing:SetLastClock() self.lastclock = os.clock() end
function Timing:SetStartTime(offset) self.tStart = os.clock() - (offset or 0) end
function Timing:GetElapsedTime() return os.clock() - self.tStart end

function Timing:Step (dlgTitle, fUpdateInfo, arg1, arg2)
  self.nOp = self.nOp + 1
  if self.nOp < self.nOpMax then return end -- don't use "==" here (int vs floating point)
  -------------------------------------------------
  self.nOp = 0
  local currclock = os.clock()
  local tm = currclock - self.lastclock
  if tm == 0 then tm = 0.01 end
  self.nOpMax = self.nOpMax * 0.5 / tm
  if self.nOpMax > 100 then self.nOpMax = 100 end
  self.lastclock = currclock
  -------------------------------------------------
  if currclock - self.last_update >= 0.5 then
    if fUpdateInfo then fUpdateInfo(arg1, arg2) end
    if win.ExtractKey()=="ESCAPE" and 1==far.Message(M.MUsrBrkPrompt, dlgTitle, M.MBtnYesNo, "w") then
      return true
    end
    self.last_update = currclock
    self.tStart = self.tStart + os.clock() - currclock
  end
end


local function ShowAll_ChangeState (hDlg, item, force_dock)
  SelectItemInEditor(item)

  local EI = editor.GetInfo()
  local rect = hDlg:send("DM_GETDLGRECT")
  local scrline = item.lineno - EI.TopScreenLine + 1
  if force_dock or (scrline >= rect.Top and scrline <= rect.Bottom) then
    local X = force_dock and (EI.WindowSizeX - (rect.Right - rect.Left + 1)) or rect.Left
    local Y = scrline <= EI.WindowSizeY/2 and EI.WindowSizeY - (rect.Bottom - rect.Top) or 1
    hDlg:send("DM_MOVEDIALOG", 1, {X=X, Y=Y})
  end

  -- This additional editor.Redraw() is a workaround due to a bug in FAR
  -- that makes selection invisible in modal editors.
  editor.Redraw()
end


local function ShowCollectedLines (items, title, bForward, tBlockInfo)
  if #items == 0 then return end

  local Info = editor.GetInfo()

  local timing = NewTiming()
  local maxno = #tostring(items.maxline)
  local fmt = ("%%%dd%s %%s"):format(maxno, ("").char(9474))
  for _, item in ipairs(items) do
    if timing:Step(M.MTitleSearch) then
      return
    end
    local s = item.text:gsub("%z", " ") -- replace null bytes with spaces
    local n = maxno + 2
    item.offset, item.fr, item.to = n, item.fr+n, item.to+n
    item.text = fmt:format(item.lineno, s)
  end
  local bottom = #items..M.MMatchesFound.." [F6,F7,F8,Ctrl-C]"

  local list = CustomMenu.NewList({
      hmax = floor(Info.WindowSizeY * 0.5) - 4,
      wmax = floor(Info.WindowSizeX * 0.7) - 6,
      autocenter = false,
      --resizeScreen = true, -- make it the default for CustomMenu?
      col_highlight = 0x6F,
      col_selectedhighlight = 0x4F,
      ellipsis = bForward and 3 or 0, -- position ellipsis at either line end or beginning
      searchstart = maxno + 3, -- required for correct work of ellipsis
    }, items)

  function list:onlistchange (hDlg, key, item)
    ShowAll_ChangeState(hDlg, item, false)
  end

  -- local rep_html = {["<"]="&lt;"; [">"]="&gt;"; ["&"]="&amp;"; ["\""]="&quot;"}
  -- local function html(s) return (s:gsub("[<>&\"]", rep_html)) end

  local newsearch = false
  function list:keyfunction (hDlg, key, item)
    if regex.match(key, "^R?Ctrl(?:Up|Down|Home|End|Num[1278])$") then
      editor.ProcessInput(nil, far.NameToInputRecord(key))
      hDlg:send("DM_REDRAW")
      return "done"
    elseif key=="CtrlNum0" or key=="RCtrlNum0" then
      self:onlistchange(hDlg, key, item)
      return "done"
    elseif key=="F8" then
      newsearch = true
      return "break"
    -- elseif key=="F2" then
    --   local fname = Info.FileName:match(".+\\").."tmp.tmp.html"
    --   local fp = io.open(fname, "w")
    --   if fp then
    --     fp:write("\239\187\191") -- UTF-8 BOM
    --     fp:write("<pre><code>\n")
    --     fp:write("*** ", html(Info.FileName), " ***\n")
    --     fp:write("*** ", html(title), " ***\n")
    --     for i,v in ipairs(items) do
    --       local s1, s2, s3 = v.text:sub(1,v.fr-1), v.text:sub(v.fr,v.to), v.text:sub(v.to+1)
    --       fp:write(html(s1).."<b>"..html(s2).."</b>"..html(s3), "\n")
    --     end
    --     fp:write("</code></pre>\n")
    --     fp:close()
    --     win.ShellExecute(nil, "open", fname)
    --   end
    end
  end

  local OnInitDialog_original = list.OnInitDialog
  list.OnInitDialog = function (self, hDlg)
    OnInitDialog_original(self, hDlg)
    ShowAll_ChangeState(hDlg, self.items[1], true)
  end

  local item = CustomMenu.Menu(
    {
      DialogId  = win.Uuid("D0596479-B9AB-4C0E-A28B-D009C000C63C"),
      Title     = title,                  -- honored by CustomMenu
      Bottom    = bottom,                 -- honored by CustomMenu
      Flags     = F.FMENU_SHOWAMPERSAND + F.FMENU_WRAPMODE,
      HelpTopic = "EditorShowAll",
      X = Info.WindowSizeX - list.wmax - 6,
      Y = Info.WindowSizeY - list.hmax - 3,
    },
    list)
  if item and not newsearch then
    SelectItemInEditor(item)
  else
    editor.SetPosition(nil, Info)
    EditorSelect(tBlockInfo) -- if tBlockInfo is false then selection is reset;
    editor.Redraw()
  end
  return newsearch
end

local function GetInvariantTable (tRegex)
  local is_wide = tRegex.ufindW and true
  return {
    EditorGetString = is_wide and editor.GetStringW  or editor.GetString,
    EditorSetString = is_wide and editor.SetStringW  or editor.SetString,
    empty           = is_wide and win.Utf8ToUtf16""  or "",
    find            = is_wide and regex.findW        or regex.find,
    gmatch          = is_wide and regex.gmatchW      or regex.gmatch,
    len             = is_wide and win.lenW or ("").len,
    sub             = is_wide and win.subW or ("").sub,
    U8              = is_wide and win.Utf16ToUtf8    or function(s) return s end,
  }
end

local function update_info (nFound, y)
  editor.SetTitle(nil, M.MCurrentlyFound .. nFound)
end

local function NeedWrapTheSearch (bForward, timing)
  local elapsed = timing:GetElapsedTime()
  local res = far.Message(bForward and M.MWrapAtBeginning or M.MWrapAtEnd, M.MMenuTitle, ";YesNo")
  timing:SetStartTime(elapsed)
  return res == 1
end

local function DoSearch (
    sOperation,       -- [in]     "search", "count", "showall", "searchword"
    bFirstSearch,     -- [in]     whether this is first or repeated search
    bScriptCall,      -- [in]     whether this call is from a script
    tRepeat,          -- [in/out] data saved from previous operation / for next repeat operation
    tRegex,           -- [in]     contains methods: ufindW, gsubW and/or ufind, gsub
    bScopeIsBlock,    -- [in]     boolean
    bOriginIsScope,   -- [in]     boolean
    bWrapAround,      -- [in]     wrap search around the scope
    bSearchBack,      -- [in]     search in reverse direction
    fFilter,          -- [in]     either function or nil
    sSearchPat        -- [in]     search pattern (for display purpose only)
  )

  local timing = NewTiming()
  bWrapAround = (not bScopeIsBlock) and (not bOriginIsScope) and bWrapAround

  local is_wide = tRegex.ufindW and true
  local TT = GetInvariantTable(tRegex)
  local ufind_method = tRegex.ufindW or Editors.WrapTfindMethod(tRegex.ufind)
  -----------------------------------------------------------------------------
  local sTitle = M.MTitleSearch
  local bForward = not bSearchBack
  local bAllowEmpty = bFirstSearch
  local tItems = (sOperation=="showall") and {maxline=1}

  local sChoice = bFirstSearch and "all" or "initial"
  local nFound, nLine = 0, 0
  local tInfo, tStartPos = editor.GetInfo(), editor.GetInfo()

  local tBlockInfo = bScopeIsBlock and assert(GetSelectionInfo() or nil, "no selection")

  local fLineInScope
  if tBlockInfo then
    fLineInScope = bForward
      and function(y) return y <= tBlockInfo.EndLine end
      or function(y) return y >= tBlockInfo.StartLine end
  else
    fLineInScope = bForward
      and function(y) return y <= tInfo.TotalLines end
      or function(y) return y >= 1 end
  end

  -- sLine must be set/modified only via set_sLine, in order to cache its length.
  -- This gives a very noticeable performance gain on long lines.
  local sLine, sLineEol, sLineLen, sLineU8
  local function set_sLine (s, eol)
    sLine, sLineEol, sLineLen, sLineU8 = s, eol, TT.len(s), nil
  end
  local get_sLineU8 = is_wide and
    function() sLineU8 = sLineU8 or win.Utf16ToUtf8(sLine); return sLineU8; end or
    function() return sLine; end

  local x, y, egs, part1, part3

  local function SetStartBlockParam (y)
    egs = TT.EditorGetString(nil, y, 0)
    part1 = TT.sub(egs.StringText, 1, egs.SelStart-1)
    if egs.SelEnd == -1 then
      set_sLine(TT.sub(egs.StringText, egs.SelStart))
      part3 = TT.empty
    else
      set_sLine(TT.sub(egs.StringText, egs.SelStart, egs.SelEnd))
      part3 = TT.sub(egs.StringText, egs.SelEnd+1)
    end
  end

  if bFirstSearch and bOriginIsScope then
    if tBlockInfo then
      y = bForward and tBlockInfo.StartLine or tBlockInfo.EndLine
      SetStartBlockParam(y)
      x = bForward and 1 or sLineLen+1
    else
      y = bForward and 1 or tInfo.TotalLines
      set_sLine(TT.EditorGetString(nil, y, 3))
      x = bForward and 1 or sLineLen+1
      part1, part3 = TT.empty, TT.empty
    end
  else -- "cursor"
    if tBlockInfo then
      if tInfo.CurLine < tBlockInfo.StartLine or tInfo.CurLine > tBlockInfo.EndLine then
        y = bForward and tBlockInfo.StartLine or tBlockInfo.EndLine
        SetStartBlockParam(y)
        x = bForward and 1 or sLineLen+1
      else
        y = tInfo.CurLine
        SetStartBlockParam(y)
        x = tInfo.CurPos <= egs.SelStart and 1
            or min(egs.SelEnd==-1 and sLineLen+1 or egs.SelEnd+1,
                   tInfo.CurPos - egs.SelStart + 1, sLineLen+1)
      end
    else
      y = tInfo.CurLine
      set_sLine(TT.EditorGetString(nil, y, 3))

      if sOperation == "searchword" then
        x = min(bForward and tInfo.CurPos+1 or tInfo.CurPos, sLineLen+1)
      elseif not bScriptCall and
         tRepeat.bSearchBack ~= bSearchBack and
         tRepeat.FileName == tInfo.FileName and
         tRepeat.y == tInfo.CurLine and
         tRepeat.x == tInfo.CurPos
      then
        x = bSearchBack and tRepeat.from or tRepeat.to+1
      else
        x = min(tInfo.CurPos, sLineLen+1)
      end

      part1, part3 = TT.empty, TT.empty
    end
  end
  tRepeat.bSearchBack = bSearchBack
  tRepeat.FileName = tInfo.FileName
  -----------------------------------------------------------------------------
  local function update_y()
    y = bForward and y+1 or y-1
    if fLineInScope(y) then
      if tBlockInfo then
        SetStartBlockParam(y)
      else
        set_sLine(TT.EditorGetString(nil, y, 3))
      end
      x = bForward and 1 or sLineLen+1
      bAllowEmpty = true
    end
  end
  -----------------------------------------------------------------------------
  local function ShowFound (x, fr, to, scroll)
    local p1 = lenW(is_wide and part1 or Utf16(part1))
    if not is_wide then
      x  = lenW(Utf16(TT.sub(sLine,1,x-1))) + 1
      fr = lenW(Utf16(TT.sub(sLine,1,fr-1))) + 1
      to = lenW(Utf16(TT.sub(sLine,1,to)))
    end
    ScrollToPosition (y, p1+x, fr, to, scroll)
    if _Plugin.History:field("config").bSelectFound then
      editor.Select(nil, "BTYPE_STREAM", y, p1+fr, to<=fr and 1 or to-fr+1, 1)
    end
    editor.Redraw()
    tStartPos = editor.GetInfo()
  end
  -------------------------------------------------------------------

  timing:SetLastClock()
  --===========================================================================
  -- ITERATE ON LINES
  --===========================================================================
  local bFinish, bLastLine
  local PosFromEnd = sLineLen - tInfo.CurPos
  for pass = 1, bWrapAround and 2 or 1 do
    if bFinish or sChoice == "broken" then
      break
    end
    if pass == 2 then
      if type(bWrapAround)=="number" then
        update_info(nFound)
        if not NeedWrapTheSearch(bForward, timing) then
          break
        end
      end
      if bForward then
        fLineInScope = function(y) bLastLine=(y==tInfo.CurLine); return y <= tInfo.CurLine; end
        y = 0
      else
        fLineInScope = function(y) bLastLine=(y==tInfo.CurLine); return y >= tInfo.CurLine; end
        y = tInfo.TotalLines + 1
      end
      update_y()
    end
    while fLineInScope(y) and not (bFinish or sChoice == "broken") do
      nLine = nLine + 1
      if not (fFilter and fFilter(get_sLineU8(), nLine)) then
        -------------------------------------------------------------------------
        -- iterate on current line
        -------------------------------------------------------------------------
        while bForward and x <= sLineLen+1 or not bForward and x >= 1 do
          if timing:Step(sTitle, update_info, nFound, y) then
            sChoice = "broken"; break
          end
          -----------------------------------------------------------------------
          local collect, fr, to
          if bForward then fr, to, collect = ufind_method(tRegex, sLine, x)
          else fr, to, collect = find_back(tRegex, ufind_method, sLine, x)
          end
          if not fr then
            if bLastLine then bFinish=true; end
            break
          end

          if bLastLine then
            if bForward then
              if fr >= tInfo.CurPos then bFinish=true; break end
            else
              if to < (sLineLen - PosFromEnd) then bFinish=true; break end
            end
          end

          if fr==x and to+1==x and not bAllowEmpty then
            collect = nil
            if bForward then
              if x <= sLineLen then
                x = x + 1
                fr, to, collect = ufind_method(tRegex, sLine, x)
              end
            else
              if x > 1 then
                x = x - 1
                fr, to, collect = find_back(tRegex, ufind_method, sLine, x)
              end
            end
            if not collect then break end
          end

          nFound = nFound + 1
          bAllowEmpty = false
          x = bForward and to+1 or fr

          tRepeat.x, tRepeat.y = x, y
          tRepeat.from, tRepeat.to = fr, to
          -----------------------------------------------------------------------
          if sOperation=="search" or sOperation=="searchword" then
            local X = sOperation=="searchword" and bForward and x>1 and x-1 or x
            ShowFound(X, fr, to, bForward and "+lazy" or "-lazy")
            return 1, 0, sChoice, timing:GetElapsedTime()
          -----------------------------------------------------------------------
          elseif sOperation=="showall" then
            local seloffset = tBlockInfo and egs.SelStart>0 and egs.SelStart-1 or 0
            table.insert(tItems, {lineno=y, text=get_sLineU8(), fr=fr, to=to, seloffset=seloffset})
            if tItems.maxline < y then tItems.maxline = y; end
          -----------------------------------------------------------------------
          end -- elseif sOperation=="showall" then
        end -- Current Line loop
      end -- Line Filter check
      update_y()
    end -- Iteration on lines
  end -- for pass = 1, bWrapAround and 2 or 1 do
  --===========================================================================
  editor.SetPosition(nil, tStartPos)
  if tBlockInfo then
    EditorSelect(tBlockInfo)
  end
  local elapsedTime = timing:GetElapsedTime()
  if nFound > 0 then
    editor.Redraw()
    update_info(nFound, nil)
    if sOperation=="showall" then
      local newsearch = ShowCollectedLines(
          tItems,
          ("%s [%s]"):format(M.MSearchResults, sSearchPat),
          bForward,
          tBlockInfo)
      if newsearch then sChoice = "newsearch" end
    end
  end
  return nFound, 0, sChoice, elapsedTime
end

local function DoReplace (
    bFirstSearch,     -- [in]     whether this is first or repeated search
    bScriptCall,      -- [in]     whether this call is from a script
    tRepeat,          -- [in/out] data saved from previous operation / for next repeat operation
    tRegex,           -- [in]     contains methods: ufindW, gsubW and/or ufind, gsub
    bScopeIsBlock,    -- [in]     boolean
    bOriginIsScope,   -- [in]     boolean
    bWrapAround,      -- [in]     wrap search around the scope
    bSearchBack,      -- [in]     search in reverse direction
    fFilter,          -- [in]     either function or nil
    sSearchPat,       -- [in]     search pattern (for display purpose only)
    xReplacePat,      -- [in]     either of: string, function, compiled replace expression
    bConfirmReplace,  -- [in]     confirm replace
    bDelEmptyLine,    -- [in]     delete empty line (if it is empty after the replace operation)
    bDelNonMatchLine, -- [in]     delete line where no match was found
    fReplaceChoice    -- [in]     either function or nil
  )

  local timing = NewTiming()
  bWrapAround = (not bScopeIsBlock) and (not bOriginIsScope) and bWrapAround

  bDelNonMatchLine = bDelNonMatchLine and bFirstSearch
  local is_wide = tRegex.ufindW and true
  local TT = GetInvariantTable(tRegex)
  local ufind_method = tRegex.ufindW or Editors.WrapTfindMethod(tRegex.ufind)
  local EditorSetCurString = function(text, eol)
    if not TT.EditorSetString(nil, nil, text, eol) then error("EditorSetString failed") end
  end
  -----------------------------------------------------------------------------
  local sTitle = M.MTitleReplace
  local bForward = not bSearchBack
  local bAllowEmpty = bFirstSearch
  fReplaceChoice = fReplaceChoice or GetReplaceChoice
  local fReplace = Common.GetReplaceFunction(xReplacePat, is_wide)

  local sChoice = bFirstSearch and not bConfirmReplace and "all" or "initial"
  local nFound, nReps, nLine = 0, 0, 0
  local tInfo, tStartPos = editor.GetInfo(), editor.GetInfo()
  local acc, acc_started
  local Need_EUR_END

  local tBlockInfo = bScopeIsBlock and assert(GetSelectionInfo() or nil, "no selection")

  local fLineInScope
  if tBlockInfo then
    fLineInScope = bForward
      and function(y) return y <= tBlockInfo.EndLine end
      or function(y) return y >= tBlockInfo.StartLine end
  else
    fLineInScope = bForward
      and function(y) return y <= tInfo.TotalLines end
      or function(y) return y >= 1 end
  end

  -- sLine must be set/modified only via set_sLine, in order to cache its length.
  -- This gives a very noticeable performance gain on long lines.
  local sLine, sLineEol, sLineLen
  local function set_sLine (s, eol)
    sLine, sLineEol, sLineLen = s, eol, TT.len(s)
  end

  local x, y, egs, part1, part3, x1, x2, y1, y2

  local function SetStartBlockParam (y)
    egs = TT.EditorGetString(nil, y, 0)
    part1 = TT.sub(egs.StringText, 1, egs.SelStart-1)
    if egs.SelEnd == -1 then
      set_sLine(TT.sub(egs.StringText, egs.SelStart))
      part3 = TT.empty
    else
      set_sLine(TT.sub(egs.StringText, egs.SelStart, egs.SelEnd))
      part3 = TT.sub(egs.StringText, egs.SelEnd+1)
    end
  end

  if bFirstSearch and bOriginIsScope then
    if tBlockInfo then
      y = bForward and tBlockInfo.StartLine or tBlockInfo.EndLine
      SetStartBlockParam(y)
      x = bForward and 1 or sLineLen+1
    else
      y = bForward and 1 or tInfo.TotalLines
      set_sLine(TT.EditorGetString(nil, y, 3))
      x = bForward and 1 or sLineLen+1
      part1, part3 = TT.empty, TT.empty
    end
  else -- "cursor"
    if tBlockInfo then
      if tInfo.CurLine < tBlockInfo.StartLine or tInfo.CurLine > tBlockInfo.EndLine then
        y = bForward and tBlockInfo.StartLine or tBlockInfo.EndLine
        SetStartBlockParam(y)
        x = bForward and 1 or sLineLen+1
      else
        y = tInfo.CurLine
        SetStartBlockParam(y)
        x = tInfo.CurPos <= egs.SelStart and 1
            or min(egs.SelEnd==-1 and sLineLen+1 or egs.SelEnd+1,
                   tInfo.CurPos - egs.SelStart + 1, sLineLen+1)
      end
    else
      y = tInfo.CurLine
      set_sLine(TT.EditorGetString(nil, y, 3))

      if not bScriptCall and
         tRepeat.bSearchBack ~= bSearchBack and
         tRepeat.FileName == tInfo.FileName and
         tRepeat.y == tInfo.CurLine and
         tRepeat.x == tInfo.CurPos
      then
        x = bSearchBack and tRepeat.from or tRepeat.to+1
      else
        x = min(tInfo.CurPos, sLineLen+1)
      end

      part1, part3 = TT.empty, TT.empty
    end
  end
  tRepeat.bSearchBack = bSearchBack
  tRepeat.FileName = tInfo.FileName
  -----------------------------------------------------------------------------
  local function update_y (lineWasDeleted)
    y = bForward and y+(lineWasDeleted and 0 or 1) or y-1
    if fLineInScope(y) then
      if tBlockInfo then
        SetStartBlockParam(y)
      else
        set_sLine(TT.EditorGetString(nil, y, 3))
      end
      x = bForward and 1 or sLineLen+1
      bAllowEmpty = true
    end
  end
  -----------------------------------------------------------------------------
  local function ShowFound (x, fr, to, scroll)
    local p1 = lenW(is_wide and part1 or Utf16(part1))
    if not is_wide then
      x  = lenW(Utf16(TT.sub(sLine,1,x-1))) + 1
      fr = lenW(Utf16(TT.sub(sLine,1,fr-1))) + 1
      to = lenW(Utf16(TT.sub(sLine,1,to)))
    end
    ScrollToPosition (y, p1+x, fr, to, scroll)
    editor.Select(nil, "BTYPE_STREAM", y, p1+fr, to<=fr and 1 or to-fr+1, 1)
    editor.Redraw()
    tStartPos = editor.GetInfo()
  end
  -------------------------------------------------------------------
  local function Replace (fr, to, sRep)
    local sLastRep
    local bTraceSelection = tBlockInfo
        and (tBlockInfo.BlockType == F.BTYPE_STREAM)
        and (tBlockInfo.EndLine == y) and (tBlockInfo.EndPos ~= -1)
    local nAddedLines, nDeletedLines = 0, 0
    local before, after = TT.sub(sLine, 1, fr-1), TT.sub(sLine, to+1)
    -----------------------------------------------------------------
    editor.SetPosition(nil,y)
    for txt, nl in TT.gmatch(sRep, "([^\r\n]*)(\r?\n?)") do
        if nAddedLines == 0 then
            local sStartLine = before..txt
            if nl == TT.empty then
                set_sLine(sStartLine..after, sLineEol)
                local line = part1..sLine..part3
                if line==TT.empty and bDelEmptyLine then
                    editor.DeleteString()
                    nDeletedLines = nDeletedLines + 1
                else
                    EditorSetCurString(line, sLineEol)
                    x = bForward and TT.len(sStartLine)+1 or fr
                    x1, x2, y1, y2 = fr, fr-1+TT.len(txt), y, y
                end
                sLastRep = txt
                break
            else
                local line = part1..sStartLine
                if line==TT.empty and bDelEmptyLine then
                    EditorSetCurString(TT.empty, nl)
                    nDeletedLines = nDeletedLines + 1
                    x1, y1 = 1, y
                else
                    EditorSetCurString(line, nl)
                    editor.SetPosition(nil, nil, TT.len(line)+1)
                    editor.InsertString()
                    if not bForward then set_sLine(sStartLine) end
                    x1, y1 = fr, y
                end
                nAddedLines = 1
            end
        else
            if nl == TT.empty then
                local sLine1 = txt..after
                if bForward then
                    set_sLine(sLine1)
                    x = TT.len(txt)+1
                end
                EditorSetCurString(sLine1..part3)--, stringEOL)
                sLastRep = txt
                x2, y2 = TT.len(txt)-1, y + nAddedLines - nDeletedLines
                break
            else
                EditorSetCurString(txt, nl)
                editor.SetPosition(nil, nil, TT.len(txt)+1)
                editor.InsertString()
                nAddedLines = nAddedLines + 1
            end
        end
    end

    if y < tInfo.CurLine then
      tInfo.CurLine = tInfo.CurLine + nAddedLines - nDeletedLines
    end

    if bForward then
        y = y + nAddedLines
    else
        x = fr
    end

    if tBlockInfo then
        tBlockInfo.EndLine = tBlockInfo.EndLine + nAddedLines - nDeletedLines
        if bTraceSelection and nDeletedLines>0 then
          tBlockInfo.EndPos = -1
        end
    else
        tInfo.TotalLines = tInfo.TotalLines + nAddedLines - nDeletedLines
    end

    if sChoice == "yes" then editor.Redraw() end
    tStartPos = editor.GetInfo() -- save position (time consuming)

    return (nDeletedLines > 0)
  end
  -------------------------------------------------------------------
  local function DeleteLine()
    acc, acc_started = nil, nil

    local bTraceSelection = tBlockInfo
      and (tBlockInfo.BlockType == F.BTYPE_STREAM)
      and (tBlockInfo.EndLine == y) and (tBlockInfo.EndPos ~= -1)

    editor.SetPosition(nil,y)
    editor.DeleteString()

    if not bForward then
      x = 1
      editor.SetPosition(nil, y, x)
    end

    if tBlockInfo then
      tBlockInfo.EndLine = tBlockInfo.EndLine - 1
      if bTraceSelection then
        tBlockInfo.EndPos = -1
      end
    else
      tInfo.TotalLines = tInfo.TotalLines - 1
      if y < tInfo.CurLine then tInfo.CurLine = tInfo.CurLine - 1; end
    end

    if sChoice == "yes" then editor.Redraw() end
    tStartPos = editor.GetInfo() -- save position (time consuming)

    return true
  end
  -------------------------------------------------------------------

  local function ProcessReplaceQuery (fr, to, sRepFinal)
    local EI = editor.GetInfo()
    local s_found = TT.U8(TT.sub(sLine, fr, to))
    local s_rep = sRepFinal==true or TT.U8(sRepFinal)

    local dlgHeight
    if s_rep == true then
      dlgHeight = 8
    else
      local _,n = regex.gsub(s_rep, "\r\n|\r|\n", "")
      dlgHeight = min(10 + n, EI.WindowSizeY)
    end

    local scroll = floor( -(EI.WindowSizeY+dlgHeight)/4 + 0.5 )
    if y - scroll > EI.TotalLines - EI.WindowSizeY/2 then
      scroll = -scroll
    end
    ShowFound(x, fr, to, scroll)
    update_info(nFound, y)

    sChoice = fReplaceChoice(sTitle, s_found, s_rep)
    if sChoice == "all" then
      timing:SetLastClock()
      timing:SetStartTime()
      do editor.UndoRedo(nil,"EUR_BEGIN"); Need_EUR_END = true; end
      if tBlockInfo then EditorSelect(tBlockInfo) end
    elseif sChoice == "yes" then
      timing:SetStartTime()
    end
  end
  -------------------------------------------------------------------

  timing:SetLastClock()
  if sChoice=="all" then
    editor.UndoRedo(nil,"EUR_BEGIN")
    Need_EUR_END = true
  end
  --===========================================================================
  -- ITERATE ON LINES
  --===========================================================================
  local bFinish, bLastLine
  local PosFromEnd = sLineLen - tInfo.CurPos
  for pass = 1, bWrapAround and 2 or 1 do
    if bFinish or sChoice=="cancel" or sChoice=="broken" then
      break
    end
    if pass == 2 then
      if type(bWrapAround)=="number" then
        update_info(nFound)
        if not NeedWrapTheSearch(bForward, timing) then
          break
        end
      end
      if bForward then
        fLineInScope = function(y) bLastLine=(y==tInfo.CurLine); return y <= tInfo.CurLine; end
        y = 0
      else
        fLineInScope = function(y) bLastLine=(y==tInfo.CurLine); return y >= tInfo.CurLine; end
        y = tInfo.TotalLines + 1
      end
      update_y()
    end
    while fLineInScope(y) and not (bFinish or sChoice=="cancel" or sChoice=="broken") do
      nLine = nLine + 1
      local bLineDeleted
      if not (fFilter and fFilter(TT.U8(sLine), nLine)) then
        -------------------------------------------------------------------------
        -- iterate on current line
        -------------------------------------------------------------------------
        local bLineHasMatch
        while bForward and x <= sLineLen+1 or not bForward and x >= 1 do
          if timing:Step(sTitle, update_info, nFound, y) then
            sChoice = "broken"; break
          end
          -----------------------------------------------------------------------
          local collect, fr, to
          if bForward then fr, to, collect = ufind_method(tRegex, sLine, x)
          else fr, to, collect = find_back(tRegex, ufind_method, sLine, x)
          end

          if not fr then
            if bDelNonMatchLine and (not bLineHasMatch) then
              if sChoice ~= "all" then
                ProcessReplaceQuery(1, sLineLen, true)
              end
              if sChoice=="yes" or sChoice=="all" then
                bLineDeleted = DeleteLine()
                nReps = nReps + 1
              end
            end
            if pass==2 and y==tInfo.CurLine then bFinish=true; end
            break
          end

          if bLastLine then
            if bForward then
              if fr >= tInfo.CurPos then bFinish=true; break end
            else
              if to < (sLineLen - PosFromEnd) then bFinish=true; break end
            end
          end

          bLineHasMatch = true
          if fr==x and to+1==x and not bAllowEmpty then
            collect = nil
            if bForward then
              if x <= sLineLen then
                x = x + 1
                fr, to, collect = ufind_method(tRegex, sLine, x)
              end
            else
              if x > 1 then
                x = x - 1
                fr, to, collect = find_back(tRegex, ufind_method, sLine, x)
              end
            end
            if not collect then break end
          end

          nFound = nFound + 1
          bAllowEmpty = false
          x = bForward and to+1 or fr

          tRepeat.x, tRepeat.y = x, y
          tRepeat.from, tRepeat.to = fr, to
          -----------------------------------------------------------------------
          collect[0] = TT.sub(sLine, fr, to)
          local sRepFinal, ret2 = fReplace(collect, nFound, nReps, y)
          if ret2 and sChoice == "all" then bFinish = true end
          if sRepFinal then
            if sChoice ~= "all" then
              ProcessReplaceQuery(fr, to, sRepFinal)
            end
            if sChoice == "all" then
              if sRepFinal == true then
                bLineDeleted = DeleteLine()
                nReps = nReps + 1
                break
              end
              if acc_started then
                if bForward then
                  acc[#acc+1] = TT.sub(sLine,acc.to+1,fr-1)
                  acc[#acc+1] = sRepFinal
                  acc.to = to
                else
                  acc[#acc+1] = TT.sub(sLine,to+1,acc.from-1)
                  acc[#acc+1] = sRepFinal
                  acc.from = fr
                end
              else
                if bForward then
                  acc = { part1, TT.sub(sLine,1,fr-1), sRepFinal, to=to }
                else
                  acc = { part3, TT.sub(sLine,to+1), sRepFinal, from=fr }
                end
                acc_started = true
              end
              nReps = nReps + 1
            elseif sChoice == "yes" then
              if sRepFinal == true then
                bLineDeleted = DeleteLine()
              else
                bLineDeleted = Replace(fr, to, sRepFinal)
              end
              timing:SetStartTime()
              nReps = nReps + 1
              if tBlockInfo then EditorSelect(tBlockInfo) end
              if bLineDeleted then break end
              ShowFound(x, fr, to, "none")--THIS SETS CORRECT CURSOR POSITION AFTER FINAL REPLACE IS DONE
              if tBlockInfo then EditorSelect(tBlockInfo) end -- need this because ShowFound() resets selection
            -----------------------------------------------------------------
            elseif sChoice == "no" then
              timing:SetStartTime()
              if tBlockInfo then EditorSelect(tBlockInfo) end
            -----------------------------------------------------------------
            elseif sChoice == "cancel" then
              break
            -----------------------------------------------------------------
            end
          end -- if sRepFinal
          if bFinish then break end
          -----------------------------------------------------------------------
        end -- Current Line loop

        if acc_started then
          acc_started = nil

          if bForward then
            acc[#acc+1] = TT.sub(sLine, acc.to+1)
            acc[#acc+1] = part3
          else
            acc[#acc+1] = TT.sub(sLine, 1, acc.from-1)
            acc[#acc+1] = part1

            local N = #acc
            for i=1, N/2 do
              local j = N - i + 1
              acc[i], acc[j] = acc[j], acc[i]
            end
          end

          part1, part3 = TT.empty, TT.empty
          bLineDeleted = Replace(1, sLineLen, table.concat(acc))
        end
      end -- Line Filter check
      update_y(bLineDeleted)
    end -- Iteration on lines
  end -- for pass = 1, bWrapAround and 2 or 1 do
  --===========================================================================
  editor.SetPosition(nil, tStartPos)
  if nReps==0 and tBlockInfo then -- it works incorrectly anyway
    EditorSelect(tBlockInfo)
  else
    local bSelectFound = _Plugin.History:field("config").bSelectFound
    if sChoice=="yes" then
      if bSelectFound and x2 then
        if not is_wide then
          -- Convert byte-wise offsets to character-wise ones
          local str1 = editor.GetString(nil, y1, 2)
          local str2 = (y2 == y1) and str1 or editor.GetString(nil, y2, 2)
          x1, x2 = TT.sub(str1,1,x1):len(), TT.sub(str2,1,x2):len()
        end
        editor.Select(nil, "BTYPE_STREAM", y1, x1, x2-x1+1, y2-y1+1)
      else
        editor.Select(nil, "BTYPE_NONE")
      end

    elseif acc then
      local indexLS = bForward and #acc-2 or 3
      local lastSubst = acc[indexLS]
      local fr, to = TT.find(lastSubst, "[\r\n][^\r\n]*$")
      if fr then -- the last substitution was multi-line
        editor.Select(nil, "BTYPE_NONE")
        editor.SetPosition(nil, nil, bForward and to-fr+1 or TT.len(acc[1])+TT.len(acc[2]))
      else -- the last substitution was single-line
        if lastSubst ~= TT.empty then
          -- Convert byte-wise offsets to character-wise ones if needed
          local len = is_wide and lenW or ("").len
          local width = len(lastSubst)
          local x1 = 1
          for i=1,indexLS-1 do x1 = x1 + len(acc[i]) end
          if bSelectFound then
            editor.Select(nil, "BTYPE_STREAM", y1, x1, width, 1)
          else
            editor.Select(nil, "BTYPE_NONE")
          end
          editor.SetPosition(nil, nil, bForward and x1+width or x1)
        else
          editor.Select(nil, "BTYPE_NONE")
        end
      end

    else
      editor.Select(nil, "BTYPE_NONE")
    end
  end
  local elapsedTime = timing:GetElapsedTime()
  if nFound > 0 then
    editor.Redraw()
    update_info(nFound, nil)
  end
  if Need_EUR_END then editor.UndoRedo(nil,"EUR_END") end
  return nFound, nReps, sChoice, elapsedTime
end

local function DoAction (
    sOperation,       -- "search", "replace", "count", "showall", "searchword"
    ...)
  if sOperation == "replace" then
    return DoReplace(...)
  else
    return DoSearch(sOperation, ...)
  end
end

return {
  DoAction = DoAction,
}
