-- started: 2011-10-30

-- Message box implementation (as opposed to Far's `Message' function binding).

-- TODO
-- 1. Multiple button lines (the initial reason for writing this module). ==> Done 2011-10-31.
-- 2. (Optional, flag-driven) line wrapping (word-wise).                  ==> Done 2011-11-01.
-- 3. (Optional, flag-driven) colorizing individual text lines.           ==> Done 2011-11-02.
-- 4. Document this module.                                               ==> Done 2011-11-03.
-- 5. Implement drawing separator lines (single and double).              ==> Done 2011-11-03.
-- 6. Buttons argument can contain '\n' to force a new button line.       ==> Done 2011-11-05.
-- 7. Lifted restriction of "every new element is placed on a new line".  ==> Done 2011-11-07.


local F = far.Flags
local bnot, band, bor, lshift, rshift =
  bit64.bnot, bit64.band, bit64.bor, bit64.lshift, bit64.rshift
local min, max = math.min, math.max
local subW, Utf8, Utf16 = win.subW, win.Utf16ToUtf8, win.Utf8ToUtf16

-- Dialog API constants
local IDX_X1, IDX_Y1, IDX_X2, IDX_Y2, IDX_FLAGS, IDX_DATA = 2,3,4,5,9,10

local function Label (x1, y1, text, color)
  return {"DI_TEXT", x1,y1,0,y1, 0,0,0,F.DIF_SHOWAMPERSAND, text, color=color}
end

local function Separator (y1, kind, text, color)
  local flags = bor(F.DIF_SHOWAMPERSAND, kind==2 and F.DIF_SEPARATOR2 or F.DIF_SEPARATOR)
  return {"DI_TEXT", 0,y1,0,y1, 0,0,0,flags, text or "", color=color}
end

local function WrapText (aText, MAXLEN, MAXLEN1, MAX_ITEMS)
  local items = {}
  local lastSpace, lastDelim = nil, nil -- nil stands for "invalid"
  local start, pos, maxlen = 1, 1, (MAXLEN1 or MAXLEN)
  local wText = Utf16(aText)
  local sub = function (from,to) return Utf8(subW(wText,from,to)) end -- much much faster than aText:sub(from,to)

  while not MAX_ITEMS or (#items < MAX_ITEMS) do
    local char = sub(pos, pos)
    if char == "" then -- end of the entire message
      items[#items+1] = sub(start)
      break
    elseif char == '\n' or char == '\r' then  -- end of the line
      items[#items+1] = sub(start, pos-1)
      start = pos + 1
      if char=='\r' and sub(start,start)=='\n' then start = start+1 end
      maxlen, pos, lastSpace, lastDelim = MAXLEN, start, nil, nil
    elseif pos-start < maxlen then            -- characters inside the line
      if char==' ' or char=='\t' then lastSpace = pos
      elseif char:find('[^%w_]') then lastDelim = pos
      end
      pos = pos + 1
    else                                      -- 1-st character beyond the line
      pos = lastSpace or lastDelim or pos-1
      items[#items+1] = sub(start, pos)
      start = pos + 1
      maxlen, pos, lastSpace, lastDelim = MAXLEN, start, nil, nil
    end
  end
  return items
end

--[[
@aText      : Text elements to display inside the dialog frame.
              Either a string or a table, depending on flag 'c'.
              Sequences '\n', '\r\n' and '\r' are treated as line separators.
@aTitle     : Title string; optional.
@aButtons   : Buttons string; ';' and '\n' serve as button separators; optional.
              Buttons automatically wrap on multiple lines if don't fit on one
              line. Separator '\n' forces new line for the next button.
@aFlags     : Concatenation of 0 or more character flags; optional.
              'l' - left-align text lines (default: center lines on the dialog).
              'w' - use "warning" color set for the dialog and its elements.
              'R' - don't wrap long text lines (default: wrap).
              'c' - "color"-mode, that changes treating the aText argument. With
                 this flag set, aText should be an array of individual elements,
                 each of which is either a string or a table.
                 A table elements may have the following fields:
                    "text" (string)
                    "color" (number; optional)
                    "separator" (1 = single line, 2 = double line; optional)
                 Each element's begins at the position next to the previous
                 element's end. Separators are always put on separate lines.
@aHelpTopic : Help topic string; optional.
@aId        : Dialog Id; binary GUID string; optional.

@returns    : negative number when dialog was canceled, button number otherwise
              (0 is the first button).
--]]

local function Message (aText, aTitle, aButtons, aFlags, aHelpTopic, aId)
  local bColorMode = aFlags and aFlags:find("c")
  if bColorMode then
    assert(type(aText)=="table", "argument #1 must be table when flag 'c' is specified")
  end
  if not bColorMode then aText = { tostring(aText) } end
  aTitle = aTitle or "Message"
  aButtons = aButtons or "OK"
  aId = aId or win.Uuid("bee50a78-be62-418d-95f0-a84982ac268e")
  local bWarning = aFlags and aFlags:find("w")
  local bCentered = not (aFlags and aFlags:find("l"))
  local bWrapLines = not (aFlags and aFlags:find("R"))

  local sb = win.GetConsoleScreenBufferInfo()
  local MAXWIDTH = max(8, sb.WindowRight - sb.WindowLeft - 3)
  local MAXHEIGHT = max(7, sb.WindowBottom - sb.WindowTop - 1)

  local D = {{"DI_DOUBLEBOX",  3,1,0,0,  0,0,0,0,  aTitle},}
  local currline, numchars = 2, 0
  local maxlines = MAXHEIGHT-4
  local maxchars = MAXWIDTH-9
  local STARTX = 5
  local x = STARTX

  -- lines
  local function AddElement (target, text, color, separator)
    if separator then
      text = (text or ""):sub(1, maxchars):gsub("[\r\n].*", "")
      local w = text:len()
      if numchars < w then numchars = w end
      if x ~= STARTX then currline = currline + 1 end
      target[#target+1] = Separator(currline, separator, text, color)
      x, currline = STARTX, currline + 1
    elseif bWrapLines then
      local items = WrapText (text, maxchars, maxchars+STARTX-x, maxlines)
      local w = 0
      for i,v in ipairs(items) do
        if i == 2 then x = STARTX end
        w = v:len()
        if v ~= "" then
          if numchars < w+x-STARTX then numchars = w+x-STARTX end
          target[#target+1] = Label(x, currline+i-1, v, color)
        end
      end
      currline = currline + #items - 1
      x = x + w
    else
      for line, eol in text:gmatch("([^\r\n]*)(\r?\n?)") do
        if currline-1 > maxlines then break end
        if line ~= "" then
          local w = line:len()
          if w+x-STARTX > maxchars then w = maxchars-x+STARTX end
          if numchars < w+x-STARTX then numchars = w+x-STARTX end
          target[#target+1] = Label(x, currline, line:sub(1,w), color)
          x = x + w
        end
        if eol ~= "" then x, currline = STARTX, currline + 1 end
      end
    end
  end

  local tb_labels = {}
  for _, elem in ipairs(aText) do
    if type(elem) == "table" then
      local text = elem.text==nil and "" or tostring(elem.text)
      AddElement(tb_labels, text, elem.color, elem.separator)
    else
      AddElement(tb_labels, tostring(elem), nil, nil)
    end
  end

  -- buttons
  local tb_buttons = {}
  local btnlen, maxbtnlen, btnlines, numbuttons = 0, 0, 0, 0

  local function putfirstbutton (btn)
    btnlines = btnlines + 1
    btnlen = min(btn:gsub("&",""):len() + 4, maxchars)
    maxbtnlen = max(maxbtnlen, btnlen)
    if btnlen == maxchars then btnlen = 0 end
  end

  for btn, delim in aButtons:gmatch("([^;\n]+)([;\n]?)") do
    if btnlines >= maxlines then break end
    numbuttons = numbuttons + 1
    if btnlen == 0 then -- new line
      putfirstbutton (btn)
    else
      btnlen = btnlen + btn:gsub("&",""):len() + 5
      if btnlen == maxchars then
        maxbtnlen = maxchars
        btnlen = 0
      elseif btnlen > maxchars then
        putfirstbutton (btn)
      else
        maxbtnlen = max(maxbtnlen, btnlen)
        if delim == "\n" then btnlen = 0 end
      end
    end
    tb_buttons[numbuttons] = {"DI_BUTTON",  0,btnlines,0,0,  0,0,0,F.DIF_CENTERGROUP, btn}
  end

  local nseparator = btnlines==0 and 0 or 1
  local numlines = currline - 1
  local n = numlines + btnlines + nseparator
  if n > maxlines then numlines = maxlines - btnlines - nseparator end

  for _,v in ipairs(tb_labels) do
    if v[IDX_Y1] > numlines + 1 then break end
    D[#D+1] = v
  end

  if numbuttons > 0 then
    D[#D+1] = Separator(numlines + 2)
    numchars = max(numchars, maxbtnlen)
    for k=1,numbuttons do
      local btn = tb_buttons[k]
      btn[IDX_Y1] = btn[IDX_Y1] + numlines + 2
      D[#D+1] = btn
    end
    local btn1 = D[#D-numbuttons+1]
    btn1[IDX_FLAGS] = bor(btn1[IDX_FLAGS], F.DIF_DEFAULTBUTTON)
  end

  numchars = min(MAXWIDTH-10, max(numchars, aTitle:len()+2))
  D[1][IDX_Y2] = numlines + btnlines + nseparator + 2
  D[1][IDX_X2] = numchars + 6

  if bCentered then
    local idx1, y1
    for k=1,#tb_labels+1 do -- upper limit is incremented by purpose
      local label = tb_labels[k]
      if idx1 then
        if not label or label[IDX_Y1] > y1 then
          local w = tb_labels[k-1][IDX_X1] - tb_labels[idx1][IDX_X1] - 1 + tb_labels[k-1][IDX_DATA]:len()
          local delta = math.floor((numchars-w)/2)
          for m=idx1,k-1 do tb_labels[m][IDX_X1] = tb_labels[m][IDX_X1] + delta end
          if label then idx1, y1 = k, label[IDX_Y1] end
        end
      else
        if label then idx1, y1 = 1, label[IDX_Y1] end
      end
    end
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_CTLCOLORDLGITEM then
      if param1 >= 1 and param1 <= #tb_labels then
        local color = D[param1 + 1].color
        if color then
          for _,v in ipairs(param2) do
            v.ForegroundColor, v.BackgroundColor = band(color,0xF), rshift(color,4)
          end
          return param2
        end
      end
    end
  end

  local dflags = bWarning and F.FDLG_WARNING or 0
  local ret = far.Dialog(aId, -1, -1, D[1][IDX_X2]+4, D[1][IDX_Y2]+2, aHelpTopic, D, dflags, DlgProc)
  return ret < 0 and ret or (ret - (#D - numbuttons))
end

local function GetMaxChars()
  local sb = win.GetConsoleScreenBufferInfo()
  local MAXWIDTH = max(8, sb.WindowRight - sb.WindowLeft - 3)
  return MAXWIDTH - 9
end

--[[
Display a two-column table.
@items: an array of rows (tables); row[1],row[2] = left and right column texts.
        A row can also be a single or double separator line if row.separator is
        1 or 2; a separator can have optional field row.text.
--]]
local function TableBox (items, title, buttons, flags, helptopic, id)
  local LEN = 0
  local out = {}
  for _,v in ipairs(items) do
    if not v.separator then
      local n = v[1]:len()
      if LEN < n then LEN = n end
    end
  end
  local nl = false
  for i,v in ipairs(items) do
    if v.separator then
      out[#out+1], nl = v, false
    else
      if nl then out[#out+1] = "\n" end
      out[#out+1] = v[1]
      out[#out+1] = (" "):rep(LEN+2-v[1]:len())
      out[#out+1] = tostring(v[2])
      nl = true
    end
  end
  flags = (flags or "") .. "lc"
  return Message(out, title, buttons, flags, helptopic, id)
end

local function GetInvertedColor (element)
  local color = far.AdvControl("ACTL_GETCOLOR", far.Colors[element])
  local fc, bc = color.ForegroundColor, color.BackgroundColor
  fc = band(bnot(fc), 0xF)
  bc = band(bnot(bc), 0xF)
  return bor(fc, lshift(bc, 4))
end

return {
  GetInvertedColor = GetInvertedColor,
  GetMaxChars = GetMaxChars,
  Message = Message,
  TableBox = TableBox,
}
