--[[
 Custom menu.
 Started: 2010-03-25 by Shmuel Zeigerman
--]]

local F = far.Flags
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil
local band, bor, bxor, bnot = bit64.band, bit64.bor, bit64.bxor, bit64.bnot

-- Some color indexes; taken from far.Colors;
local COL_MENUTEXT, COL_MENUSELECTEDTEXT, COL_MENUHIGHLIGHT,
  COL_MENUSELECTEDHIGHLIGHT, COL_MENUBOX, COL_MENUTITLE = 0,1,2,3,4,5

local function GetColor (index)
  return far.AdvControl("ACTL_GETCOLOR", index)
end

local function SendRedrawMessage (hDlg)
  hDlg:send("DM_REDRAW", 0, 0)
end

local function FlagsToInt (input)
  local tp, ret = type(input), 0
  if tp == "table" then
    for k,v in pairs(input) do
      if F[k] and v then ret = bor(ret, F[k]) end
    end
  elseif tp == "string" then ret = F[input] or 0
  elseif tp == "number" then ret = input
  end
  return ret
end

local function limit (v, lo, hi)
  if lo>hi then lo,hi=hi,lo end
  return v<lo and lo or v>hi and hi or v
end

local function btest (bitset, bitname)
  return band(bitset, F[bitname]) ~= 0
end

local List = {}
local ListMeta = { __index=List }

-- new custom list
local function NewList (props, items, bkeys, startId)
  assert (type(props) == "table")
  assert (type(items) == "table")
  assert (not bkeys or type(bkeys)=="table")
  local self = setmetatable ({}, ListMeta)
  local P = props

  -- Constants
  self.bkeys     = bkeys
  self.flags     = FlagsToInt(P.flags)
  self.items     = items
  self.startId   = startId or 1
  self.title     = P.title or ""
  self.idata = {}; for i,v in ipairs(items) do  self.idata[v] = { index=i } end

  -- Variables
  self.bottom    = P.bottom or ""
  self.drawitems = items
  self.fulltitle = self.title
  self.sel       = P.sel or 1
  -- fields initialized to nil:
  --   w, h, upper, clickX, clickY

  -- Custom list properties and their defaults
  if P.resizeScreen then
    local sb = win.GetConsoleScreenBufferInfo()
    self.wmax = max(4, sb.WindowRight - sb.WindowLeft + 1 - 8)
    self.hmax = max(1, sb.WindowBottom - sb.WindowTop + 1 - 8)
  else
    self.wmax = max(4, P.wmax or 74)
    self.hmax = max(1, P.hmax or 19)
  end

  self.autocenter= P.autocenter
  self.col_highlight         = P.col_highlight or GetColor(COL_MENUHIGHLIGHT)
  self.col_selectedhighlight = P.col_selectedhighlight or GetColor(COL_MENUSELECTEDHIGHLIGHT)
  self.col_selectedtext      = P.col_selectedtext or GetColor(COL_MENUSELECTEDTEXT)
  self.col_text              = P.col_text or GetColor(COL_MENUTEXT)
  self.ellipsis  = (P.ellipsis or 1) % 4
  self.filterlines = P.filterlines
  self.margin    = P.margin or "  "
  self.pattern   = P.pattern or ""
  self.resizeH   = P.resizeH
  self.resizeScreen = P.resizeScreen
  self.resizeW   = P.resizeW
  self.rmargin   = 1 -- right margin length
  self.searchmethod = P.searchmethod or "regex"
  self.searchstart = P.searchstart or 1
  self.selalign  = P.selalign or "center" -- top/center/bottom/
  self.selignore = P.selignore
  self.xlat      = P.xlat

  self:SetSize()
  self:SetUpperItem()
  return self
end

function List:CreateDialogItems (x, y)
  self.x, self.y = x, y
  return { "DI_USERCONTROL", x, y, x+self.w+1, y+self.h+1, 0,0,0,0, "" }
end

function List:SetSize()
  if self.resizeW then
    local wd = 0
    for _,v in ipairs(self.drawitems) do
      local len = v.text:len() + (v.separator and 1 or 0)
      wd = max(wd, len)
    end
    self.w = max(self.margin:len() + wd + self.rmargin, self.fulltitle:len()+2,
                 self.bottom:len() + 2)
    self.w = min(self.w, self.wmax)
  else
    self.w = self.wmax
  end
  self.h = self.resizeH and min (#self.drawitems, self.hmax) or self.hmax
end

function List:OnResizeConsole (hDlg, consoleSize)
  if self.resizeScreen then
    self.wmax, self.hmax = max(4, consoleSize.X - 8), max(1, consoleSize.Y - 6)
    self:SetSize()
    self:SetUpperItem()
    hDlg:send("DM_RESIZEDIALOG", 0, {X=self.w + 6, Y=self.h + 4})
  end
end

-- calculate index of the upper element shown
function List:SetUpperItem ()
  local item = self.drawitems[self.sel]
  if not item or item.separator then
    self.sel, self.upper = 1, 1
  elseif self.selalign == "top" then
    if self.selignore then self.sel = 1 end
    self.upper = min(self.sel, max(1, #self.drawitems-self.h+1))
  elseif self.selalign == "bottom" then
    if self.selignore then self.sel = #self.drawitems end
    self.upper = max(1, self.sel - self.h + 1)
  else -- "center"
    if self.selignore then self.sel = ceil(#self.drawitems / 2) end
    self.upper = self.sel - floor(self.h / 2)
    if self.upper < 1 then self.upper = 1
    else self.upper = max(1, min(self.upper, #self.drawitems-self.h+1))
    end
  end
end

function List:OnInitDialog (hDlg)
  if self.filterlines then
    self:ChangePattern(hDlg, self.pattern)
  else
    self:PrepareToDisplay(hDlg)
  end
end

function List:OnDrawDlgItem (x, y)
  self:Draw (x+self.x, y+self.y)
end

function List:OnGotFocus ()
  self.focused = true
end

function List:OnKillFocus ()
  self.focused = false
end

function List:OnDialogClose ()
  if self.timer then
    self.timer:Close()
    self.timer = nil
  end
end

do
  local ch = unicode.utf8.char
  local sng = {c1=9484,c2=9488,c3=9492,c4=9496,hor=9472,ver=9474,sep1=9500,sep2=9508}
  local dbl = {c1=9556,c2=9559,c3=9562,c4=9565,hor=9552,ver=9553,sep1=9567,sep2=9570}
  for k,v in pairs(sng) do
    sng[k], dbl[k] = ch(v), ch(dbl[k])
  end
  local up, dn = ch(9650), ch(9660)
  local scr1, scr2 = ch(9617), ch(9619)

  function List:DrawBox (x, y)
    local T = self.focused and dbl or sng
    local color = self.col_text
    if self.mousestate ~= "drag_slider" then
      local len_ratio = #self.drawitems==0 and 0 or self.h/#self.drawitems
      local range = self.h - 2
      self.slider_len = max(floor(range * len_ratio + 0.5), 1)
      local hidden = #self.drawitems - self.h
      local offs_ratio = hidden==0 and 0 or (range-self.slider_len) / hidden
      self.slider_start = floor((self.upper-1) * offs_ratio + 0.5) -- 0-based
    end

    local function Horisontal (cleft, cright, text, y)
      local mlen = text=="" and 0 or 1
      far.Text(x, y, color, cleft) -- left corner
      local tlen = text:len()
      local len = max(ceil((self.w - 2*mlen - tlen)/2-0.5), 0)
      far.Text(x+1, y, color, T.hor:rep(len))
      far.Text(x+1+len+mlen, y, color, text:sub(1, self.w-1))
      local offs = len + tlen + 2*mlen
      far.Text(x+1+offs, y, color, T.hor:rep(self.w - offs))
      far.Text(x+self.w+1, y, color, cright) -- right corner
    end

    Horisontal(T.c1, T.c2, self.fulltitle, y)
    for k=1,self.h do
      local item = self.drawitems[self.upper+k-1]
      local sep = item and item.separator
      far.Text(x, y+k, color, sep and T.sep1 or T.ver)
      local c
      if self.h < 3 or self.h >= #self.drawitems then c = sep and T.sep2 or T.ver
      elseif k == 1 then c = up
      elseif k == self.h then c = dn
      else
        local k = k-2
        c = k >= self.slider_start and k < self.slider_start+self.slider_len and scr2 or scr1
      end
      far.Text(x+self.w+1, y+k, color, c)
    end
    Horisontal(T.c3, T.c4, self.bottom, y+self.h+1)
  end
end

function List:Draw (x, y)
  self:DrawBox(x, y)
  x, y = x+1, y+1-self.upper
  local mlen = self.margin:len()
  local char = unicode.utf8.char
  local check, hor = char(8730), char(9472)
  for i=self.upper, self.upper+self.h-1 do
    local v = self.drawitems[i]
    if not v then break end
    local vdata = self.idata[v]
    local text = v.text or ""
    if v.separator then
      local color = self.col_text
      if text ~= "" then text = " " .. text:sub(1, self.w-4) .. " " end
      local tlen = text:len()
      local len1 = floor((self.w - tlen) / 2)
      far.Text(x, y+i, color, hor:rep(len1))
      far.Text(x+len1, y+i, color, text)
      far.Text(x+len1+tlen, y+i, color, hor:rep(self.w-len1-tlen))
    else
      local color = i==self.sel and self.col_selectedtext or self.col_text
      local color2 = i==self.sel and self.col_selectedhighlight or self.col_highlight
      local tlen = text:len()
      local maxlen = self.w - mlen - self.rmargin
      local text2, fr, to = text, vdata.fr, vdata.to
      if tlen > maxlen then
        maxlen = maxlen - 3
        local ss = self.searchstart - 1
        local br1 = ss + floor((maxlen - ss) * self.ellipsis/3 + 0.5)
        local br2 = tlen - (maxlen - br1) + 1
        local offs = br2 - 1 - br1 - 3
        text2 = text:sub(1, br1) .. "..." .. v.text:sub(br2)
        if fr >= br2-1 then fr = fr - offs
        elseif fr > br1+1 then fr = br1 + 2
        end
        if to >= br2-1 then to = to - offs
        elseif to > br1+1 then to = br1 + 2
        end
      end
      far.Text(x, y+i, color, self.margin)
      if v.checked then far.Text(x, y+i, color, check) end
      if fr and to >= fr then
        far.Text(x+mlen,      y+i, color,  text2:sub(1, fr-1))
        far.Text(x+mlen+fr-1, y+i, color2, text2:sub(fr, to))
        far.Text(x+mlen+to,   y+i, color,  text2:sub(to+1))
      else
        far.Text(x+mlen,      y+i, color,  text2)
      end
      if i == self.sel then
        local start = mlen + text2:len()
        far.Text(x+start, y+i, color, (" "):rep(self.w - start))
      end
    end
  end
end

function List:MouseEvent (hDlg, Ev, x, y)
  local X, Y = Ev.MousePositionX, Ev.MousePositionY
  local MOVED = (Ev.EventFlags == F.MOUSE_MOVED)

  -- A workaround: sometimes there frequently come parasite MOUSE_MOVED events
  --               having the same PositionX and PositionY ...
  if MOVED then
    if not self.MouseX then self.MouseX, self.MouseY = X, Y; return end
    if X==self.MouseX and Y==self.MouseY then return end
    self.MouseX, self.MouseY = X, Y
  end

  local LEFT = btest(Ev.ButtonState, "FROM_LEFT_1ST_BUTTON_PRESSED")
  x, y = x+self.x, y+self.y -- screen coordinates of component's top-left corner

  local function MakeScrollFunction (method)
    method(self, false)
    SendRedrawMessage(hDlg)
    local first = true
    return function(tmr)
      if first then
        first, tmr.Interval = false, 30
      end
      if not ( (method==self.KeyPageUp or method==self.KeyPageDown) and
               (Y >= y + 2 + self.slider_start) and
               (Y  < y + 2 + self.slider_start + self.slider_len) ) then
        method(self, false)
        SendRedrawMessage(hDlg)
      end
    end
  end

  if self.timer then
    if LEFT then return 1 end
    self.timer:Close()
    self.timer = nil
  end
  local inside = Y>y and Y<=y+self.h and X>x and X<=x+self.w
  ------------------------------------------------------------------------------
  if not self.mousestate then
    if LEFT then
      if not MOVED and
          ( (Y==y or Y==y+self.h+1) and (X >= x) and (X <= x+self.w+1)  or
            (X==x or X==x+self.w+1) and (Y >= y) and (Y <= y+self.h+1) )
      then
        -- click on border
        if #self.drawitems>self.h and X==x+self.w+1 and Y>y and Y<=y+self.h then
          -- click on scrollbar
          if Y == y + 1 then                           -- click on "up" arrow
            self.timer = far.Timer(300, MakeScrollFunction(self.KeyUp))
          elseif Y == y + self.h then                  -- click on "down" arrow
            self.timer = far.Timer(300, MakeScrollFunction(self.KeyDown))
          elseif Y < y + 2 + self.slider_start then    -- click above the slider
            self.timer = far.Timer(300, MakeScrollFunction(self.KeyPageUp))
          elseif Y >= y + 2 + self.slider_start + self.slider_len then -- click below the slider
            self.timer = far.Timer(300, MakeScrollFunction(self.KeyPageDown))
          else                                         -- click on slider
            -- start dragging slider
            self.clickY = Y
            self.mousestate = "drag_slider"
          end
        else
          -- start dragging dialog
          self.clickX, self.clickY = X, Y
          self.mousestate = "drag_dialog"
        end
        return 0
      end
    end

    if inside then
      if LEFT then
        self.mousestate = "inside"
      end
      if MOVED then
        local index = self.upper + (Y - y) - 1
        local item = self.drawitems[index]
        if item and not item.separator then self.sel = index end
        SendRedrawMessage(hDlg)
      end
    end
  ------------------------------------------------------------------------------
  elseif self.mousestate == "drag_dialog" then
    if LEFT then
      if MOVED then
        if self.clickX then
          hDlg:send("DM_MOVEDIALOG", 0,
            { X = X - self.clickX, Y = Y - self.clickY })
          self.clickX, self.clickY = X, Y
        end
      end
      return 0
    else
      self.mousestate = nil
    end
  ------------------------------------------------------------------------------
  elseif self.mousestate == "drag_slider" then
    if LEFT then
      if MOVED and (Y ~= self.clickY) then
        local n = (self.h - 2) - self.slider_len
        self.slider_start = limit(self.slider_start + (Y - self.clickY), 0, n)
        self.upper = floor(1 + self.slider_start * (#self.drawitems - self.h) / n)
        self.sel = self.upper + self.slider_start
        self.clickY = Y
        SendRedrawMessage(hDlg)
      end
      return 0
    else
      self.mousestate = nil
    end
  ------------------------------------------------------------------------------
  elseif self.mousestate == "inside" then
    if LEFT then
      if inside then
        if MOVED then
          local index = self.upper + (Y - y) - 1
          local item = self.drawitems[index]
          if item and not item.separator then self.sel = index end
          SendRedrawMessage(hDlg)
        end
      end
    else
      self.mousestate = nil
      if inside then
        local index = self.upper + (Y - y) - 1
        local item = self.drawitems[index]
        if item and not item.separator then
          self.sel = index
          return 1, item, item and self.idata[item].index
        end
      end
    end
  ------------------------------------------------------------------------------
  else
    self.mousestate = nil
  end
  return 1
end

local function ProcessSearchMethod (method, pattern)
  local sNeedEscape = "[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]"
  ----------------------------------------------------------
  if method == "dos" then
    pattern = pattern:gsub("%*+", "*"):gsub(sNeedEscape, "\\%1")
                     :gsub("\\[?*]", {["\\?"]=".", ["\\*"]=".*?"})
  elseif method == "plain" then
    pattern = pattern:gsub(sNeedEscape, "\\%1")
  elseif method == "lua" then
    local map = { l="%a", u="%a", L="%A", U="%A" }
    return function(s, p, init)
      p = p:gsub("(%%?)(.)", function(a,b) return a=="" and b:lower() or map[b] end)
      local fr, to = s:lower():find(p, #(s:sub(1, init-1)) + 1)
      if not fr then return nil end
      return string.sub(s,1,fr-1):len()+1, string.sub(s,1,to):len()
    end
  elseif method ~= "regex" then
    error("invalid search method")
  end
  ----------------------------------------------------------
  local ok, cregex = pcall(regex.new, pattern, "i")
  if ok then
    return function (text, pattern, start)
      return cregex:find(text, start)
    end
  end
end

function List:UpdateSizePos (hDlg)
  self:SetSize()

  local dim
  if self.resizeW or self.resizeH then
    dim = hDlg:send("DM_RESIZEDIALOG",
      0, { X=self.w+6, Y=self.h+4 })
    self.w = min (dim.X-6, self.w)
    self.h = min (dim.Y-4, self.h)
  end
  self:SetUpperItem()

  if self.autocenter then
    hDlg:send("DM_MOVEDIALOG", 1, { X=-1, Y=-1 })
  end
  if self.resizeW or self.resizeH then
    hDlg:send("DM_SETITEMPOSITION", self.startId,
      { Left=2, Top=1, Right=dim.X-3, Bottom=dim.Y-2 })
  end
end

function List:ChangePattern (hDlg, pattern)
  if pattern then self.pattern = pattern end
  local oldsel = self.drawitems[self.sel]
  self.drawitems = {}

  local find, find2
  local pat2 = self.xlat and far.XLat(pattern)
  if type(self.searchmethod)=="function" then
    find, find2 = self.searchmethod, self.searchmethod
  else
    find = ProcessSearchMethod(self.searchmethod, pattern)
    find2 = pat2 and ProcessSearchMethod(self.searchmethod, pat2)
  end

  if find or find2 then
    for i,v in ipairs(self.items) do
      local fr, to
      if find then
        fr, to = find(v.text, pattern, self.searchstart)
      end
      if fr==nil and find2 then
        fr, to = find2(v.text, pat2, self.searchstart)
      end
      local vdata = self.idata[v]
      vdata.fr, vdata.to = fr, to
      if fr then
        self.drawitems[#self.drawitems+1] = v
        if oldsel == v then
          self.sel = #self.drawitems
        end
      else
        if oldsel == v then self.sel = 1 end
      end
    end
  end
  self.fulltitle = (self.pattern == "") and self.title or
    self.title.." ["..self.pattern.."]" -- .. (pat2 and "["..pat2.."]" or "")
  self.bottom = ("%d of %d items [%s%s]"):format(#self.drawitems, #self.items,
    self.searchmethod, self.xlat and ",xlat" or "")
  self:UpdateSizePos(hDlg)
end

function List:PrepareToDisplay (hDlg)
  self.drawitems = {}
  for i,v in ipairs(self.items) do
    local vdata = self.idata[v]
    vdata.fr, vdata.to = v.fr, v.to
    self.drawitems[#self.drawitems+1] = v
  end
  self.fulltitle = self.title
  self:UpdateSizePos(hDlg)
end

local ConvertTable = {
  Space=" ", BackSlash="\\", Divide="/", Multiply="*", Subtract="-", Add="+",
}

function List:KeyDown (wrap)
  local oldsel = self.sel
  for i = self.sel+1, #self.drawitems do
    local v = self.drawitems[i]
    if not v.separator then
      self.sel = i
      self.upper = max(self.upper, self.sel - self.h + 1)
      break
    end
  end
  if wrap and self.sel==oldsel and btest(self.flags, "FMENU_WRAPMODE") then
    for i=1, self.sel-1 do
      local v = self.drawitems[i]
      if not v.separator then
        self.sel = i
        self.upper = max(1, self.sel - self.h + 1)
        break
      end
    end
  end
end

function List:KeyUp (wrap)
  local oldsel = self.sel
  for i = self.sel-1, 1, -1 do
    local v = self.drawitems[i]
    if not v.separator then
      self.sel = i
      self.upper = min(self.upper, self.sel)
      break
    end
  end
  if wrap and self.sel==oldsel and btest(self.flags, "FMENU_WRAPMODE") then
    for i = #self.drawitems, self.sel+1, -1 do
      local v = self.drawitems[i]
      if not v.separator then
        self.sel = i
        self.upper = max(1, self.sel - self.h + 1)
        break
      end
    end
  end
end

function List:KeyPageDown()
  local oldsel = self.sel
  for i = self.sel+self.h, #self.drawitems do
    local v = self.drawitems[i]
    if not v.separator then
      self.sel = i
      self.upper = self.upper + self.sel - oldsel
      self.upper = max(1, min(self.upper, #self.drawitems - self.h + 1))
      break
    end
  end
  if self.sel == oldsel then
    for i = self.sel+self.h-1, self.sel+1, -1 do
      local v = self.drawitems[i]
      if v and not v.separator then
        self.sel = i
        self.upper = max(self.upper, self.sel - self.h + 1)
        break
      end
    end
  end
end

function List:KeyPageUp()
  local oldsel = self.sel
  for i = self.sel-self.h, 1, -1 do
    local v = self.drawitems[i]
    if not v.separator then
      self.sel = i
      self.upper = max(1, self.upper + self.sel - oldsel)
      break
    end
  end
  if self.sel == oldsel then
    for i = self.sel-self.h+1, self.sel-1 do
      local v = self.drawitems[i]
      if v and not v.separator then
        self.sel = i
        self.upper = max(1, self.upper - self.h)
        break
      end
    end
  end
end

function List:KeyHome()
  self.upper = 1
  for i,v in ipairs(self.drawitems) do
    if not v.separator then
      self.sel = i
      self.upper = max(1, self.sel - self.h + 1)
      break
    end
  end
end

function List:KeyEnd()
  self.upper = max(1, #self.drawitems - self.h + 1)
  for i = #self.drawitems, 1, -1 do
    local v = self.drawitems[i]
    if not v.separator then
      self.sel = i
      break
    end
  end
end

function List:DeleteCurrentItem (hDlg)
  local Item = self.drawitems[self.sel]
  local index = Item and self.idata[Item].index
  if index then
    local items, idata = self.items, self.idata
    for k=index+1,#items do
      local t = idata[items[k]]
      t.index = t.index - 1
    end
    table.remove(items, index)
    idata[Item] = nil

    local old_sel, old_upper = self.sel, self.upper
    local old_frame = min(#self.drawitems, self.h)
    self:ChangePattern(hDlg, self.pattern)

    local num = #self.drawitems
    if num > 1 then
      local frame = min(num, self.h)
      if frame == old_frame then
        if old_upper + old_frame - 1 < num + 1 then
          self.upper, self.sel = old_upper, old_sel
        else
          self.upper, self.sel = old_upper-1, old_sel
          if self.sel > num then self.sel = num end
        end
      else
        if old_sel < num + 1 then self.sel = old_sel
        else self.sel = old_sel - 1
        end
      end
    end
  end
end

-- Delete all currently displayed items
function List:DeleteFilteredItems (hDlg, bConfirm)
  if self.drawitems[1] then
    if not bConfirm or far.Message(("Are you sure to delete %d items?"):format(#self.drawitems),
                                    "Delete items", ";YesNo", "w") == 1 then
      local items, idata = self.items, self.idata
      for _,v in ipairs(self.drawitems) do
        items[idata[v].index] = false
        idata[v] = nil
      end
      local shift = 0
      for i,v in ipairs(items) do
        if v == false then
          shift = shift + 1
        elseif shift > 0 then
          items[i-shift] = v
          idata[v].index = i-shift
        end
      end
      for i=#items,#items-shift+1,-1 do items[i] = nil end
      self:ChangePattern(hDlg, self.pattern)
    end
  end
end

function List:CopyItemToClipboard()
  local Item = self.drawitems[self.sel]
  if Item then far.CopyToClipboard(Item.text:sub(self.searchstart)) end
end

function List:CopyFilteredItemsToClipboard()
  local t = {}
  for k,v in ipairs(self.drawitems) do t[k]=v.text end
  t[#t+1] = ""
  far.CopyToClipboard(table.concat(t, "\n"))
end

function List:ToggleSearchMethod (hDlg)
  if     self.searchmethod == "dos"   then self.searchmethod = "lua"
  elseif self.searchmethod == "lua"   then self.searchmethod = "regex"
  elseif self.searchmethod == "regex" then self.searchmethod = "plain"
  else self.searchmethod = "dos"
  end
  self:ChangePattern(hDlg, self.pattern)
end

function List:Key (hDlg, key)
  local Item = self.drawitems[self.sel]
  if self.keyfunction then
    local ret = self:keyfunction(hDlg, key, Item)
    if ret == "break" then return { BreakKey=key }, Item and self.idata[Item].index end
    if ret == "done" then return "done" end
  end

  if key == "Home" or key == "Num7" then
    self:KeyHome()
  elseif key == "End" or key == "Num1" then
    self:KeyEnd()
  elseif key == "Down" or key == "Right" or key == "Num2" or key == "Num6" then
    self:KeyDown(true)
  elseif key == "Up" or key == "Left" or key == "Num8" or key == "Num4" then
    self:KeyUp(true)
  elseif key == "PgDn" or key == "Num3" then
    self:KeyPageDown()
  elseif key == "PgUp" or key == "Num9" then
    self:KeyPageUp()

  elseif key == "Enter" or key == "NumEnter" then
    return Item, Item and self.idata[Item].index

  elseif key == "CtrlC" or key == "CtrlIns" or key == "CtrlNum0" or
         key == "RCtrlC" or key == "RCtrlIns" or key == "RCtrlNum0" then
    self:CopyItemToClipboard()

  elseif key == "CtrlShiftIns" or key == "RCtrlShiftIns" or
         key == "CtrlShiftNum0" or key == "RCtrlShiftNum0" then
    self:CopyFilteredItemsToClipboard()

  elseif key == "Ins" or key == "Num0" then
    if Item then Item.checked = not Item.checked or nil end

  elseif key == "F6" then
    self.ellipsis = (self.ellipsis + 1) % 4

  elseif key == "F7" then
    if Item then far.Message(Item.text:sub(self.searchstart), "Full Item Text", ";Ok") end

  elseif self.filterlines then

    if (key == "Del" or key == "NumDel") and self.pattern ~= "" then
      self:ChangePattern(hDlg, "")

    elseif key == "BS" and self.pattern ~= "" then
      self:ChangePattern(hDlg, self.pattern:sub(1,-2))

    elseif key == "F5" then
      self:ToggleSearchMethod(hDlg)

    elseif key == "ShiftDel" or key == "ShiftNumDel" then
      self:DeleteCurrentItem(hDlg)

    elseif key=="CtrlDel" or key=="RCtrlDel" or key=="CtrlNumDel" or key=="RCtrlNumDel" then
      self:DeleteFilteredItems(hDlg, true)

    elseif key:match("^R?CtrlR?AltX$") then
      local result = far.XLat(self.pattern, nil, nil, "XLAT_SWITCHKEYBLAYOUT")
      if result then self:ChangePattern(hDlg, result) end

    elseif key:len() == 1 then
      self:ChangePattern(hDlg, self.pattern..key)

    elseif ConvertTable[key] then
      self:ChangePattern(hDlg, self.pattern..ConvertTable[key])

    end
  end
  
  if self.onlistchange then
    local CurItem = self.drawitems[self.sel]
    if CurItem ~= Item then self:onlistchange(hDlg, key, CurItem) end
  end
end

local function Menu (props, list)
  assert(type(props) == "table")
  assert(type(list) == "table")

  list.title  = props.Title or list.title
  list.bottom = props.Bottom or list.bottom
  list.sel    = props.SelectIndex or list.sel
  list.flags  = FlagsToInt(props.Flags)

  list.autocenter = (list.autocenter ~= false)
  list.resizeW    = (list.resizeW ~= false)
  list.resizeH    = (list.resizeH ~= false)
  local UId = 1
  list.startId = UId

  local ret_item, ret_pos
  local Rect
  local D = { list:CreateDialogItems (2, 1) }
  ------------------------------------------------------------------------------
  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      hDlg:send("DM_SETMOUSEEVENTNOTIFY", 1, 0)
      list:OnInitDialog (hDlg)

    elseif msg == F.DN_GETVALUE then
      if param1 == 1 then
        local tp = param2.GetType
        if tp == 7 then                             -- get CurPos
          return { ValType=F.FMVT_INTEGER, Value=list.sel }
        elseif tp == 0 or tp == 10 then             -- get item text
          local item = list.drawitems[list.sel]
          return item and { ValType=F.FMVT_STRING, Value=item.text or "" }
        elseif tp == 11 then                        -- get ItemCount
          return { ValType=F.FMVT_INTEGER, Value=#list.drawitems }
        end
      end

    elseif msg == F.DN_DRAWDIALOG then
      Rect = hDlg:send("DM_GETDLGRECT", 0, 0)

    elseif msg == F.DN_CTLCOLORDIALOG then
      return list.col_text

    elseif msg == F.DN_CTLCOLORDLGITEM then
--       if param1 == IdDbox then return 0x003F003F end

    elseif msg == F.DN_DRAWDLGITEM then
      if param1 == UId then
        list:OnDrawDlgItem (Rect.Left, Rect.Top)
      end

    elseif msg == F.DN_CONTROLINPUT or msg == F.DN_INPUT then
      if param2.EventType == F.KEY_EVENT then
        if param1 == UId then
          local key = far.InputRecordToName(param2)
          -- far.Show(
          --   "far.InputRecordToName(param2): "..tostring(key),
          --   param2.EventType,
          --   param2.KeyDown,
          --   param2.RepeatCount,
          --   param2.VirtualKeyCode,
          --   param2.VirtualScanCode,
          --   param2.UnicodeChar,
          --   param2.ControlKeyState
          -- )
          if not key then return end
          ret_item, ret_pos = list:Key(hDlg, key)
          if ret_item == "done" then
            return true
          elseif ret_item then
            if key~="Enter" and key~="NumEnter" then -- prevent DN_CLOSE from coming twice
              hDlg:send("DM_CLOSE")
            end
          else
            SendRedrawMessage(hDlg)
          end
        end
      elseif param2.EventType == F.MOUSE_EVENT then
        local ret
        ret, ret_item, ret_pos = list:MouseEvent(hDlg, param2, Rect.Left, Rect.Top)
        if ret_item then hDlg:send("DM_CLOSE") end
        return ret
      end

    elseif msg == F.DN_GOTFOCUS then
      list:OnGotFocus()

    elseif msg == F.DN_KILLFOCUS then
      list:OnKillFocus()

    elseif msg == F.DN_RESIZECONSOLE then
      list:OnResizeConsole(hDlg, param2)
      return 1

    elseif msg == F.DN_CLOSE then
      local canclose = true
      if param1 == UId and type(list.CanClose) == "function" and ret_item and ret_pos then
        canclose = list:CanClose(list.items[ret_pos], ret_item.BreakKey)
      end
      if canclose then
        list:OnDialogClose(); return 1
      end
      return 0

    end
  end
  ----------------------------------------------------------------------------
  local id = props.DialogId or ("\0"):rep(16)
  local X1, Y1, X2, Y2 = -1, -1, list.w+6, list.h+4
  if props.X and props.Y then
    X1, Y1 = props.X, props.Y
    X2, Y2 = X1+X2-1, Y1+Y2-1
  end
  local ret = far.Dialog(id, X1, Y1, X2, Y2, props.HelpTopic, D, 0, DlgProc)
  if ret == UId then
    return ret_item, ret_pos
  end
  return nil
end

return {
  NewList = NewList,
  Menu = Menu
}
