-- started: 2012-03-24
-- Move text back and forth inside the vertical selection.

local F = far.Flags
local pat_startspace = regex.new("^\\s")
local pat_endspace = regex.new("\\s$")
local pat_nospace = regex.new("\\S")
local SPACE = " \0"

-- Note: works in UTF-16 for greater speed
local function Shift (Id, forward)
  local sub, len = win.subW, win.lenW
  local EI = editor.GetInfo(Id)
  if EI.BlockType ~= F.BTYPE_COLUMN then return end
  editor.UndoRedo(Id, "EUR_BEGIN")
  for numline=EI.BlockStartLine, EI.TotalLines do
    local SI = editor.GetStringW(Id, numline, 1)
    if SI.SelStart < 1 or SI.SelEnd == 0 then break end
    -- local tabStart = editor.RealToTab(Id, numline, SI.SelStart)
    -- local tabLength = editor.RealToTab(Id, numline, SI.StringLength)
    -- local tabEnd = editor.RealToTab(Id, numline, SI.SelEnd)
    local text = SI.StringText
    local sel = sub(text, SI.SelStart, SI.SelEnd)
    if pat_nospace:findW(sel) then
      if forward then
        if SI.SelEnd <= SI.StringLength then
          sel = pat_endspace:findW(sel) and SPACE..sub(sel,1,-2)
        else
          sel = SPACE..sel
        end
      else
        sel = pat_startspace:findW(sel) and sub(sel, 2)
        if sel and SI.SelEnd < SI.StringLength then sel = sel..SPACE end
      end
      if sel then
        text = sub(text, 1, SI.SelStart-1) .. sel .. sub(text, SI.SelEnd + 1)
        editor.SetStringW(Id, numline, text, SI.StringEOL)
      end
    end
  end
  editor.UndoRedo(Id, "EUR_END")
  editor.SetPosition(Id, EI)
  editor.Redraw(Id)
end

local forward = ...
Shift(nil, forward)
