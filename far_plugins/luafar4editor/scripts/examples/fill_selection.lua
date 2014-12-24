-- started: 2011-02-17

local F = far.Flags

local function Fill (Id, sym)
  local EI = editor.GetInfo(Id)
  if EI.BlockType == F.BTYPE_NONE then return end
  sym = sym:sub(1, 1)
  editor.UndoRedo(Id, "EUR_BEGIN")
  for numline=EI.BlockStartLine, EI.TotalLines do
    local SI, text = editor.GetString(Id, numline, 1)
    if SI.SelStart < 1 or SI.SelEnd == 0 then break end
    local tabStart = editor.RealToTab(Id, numline, SI.SelStart)
    local tabLength = editor.RealToTab(Id, numline, SI.StringLength)+1
    if SI.SelEnd < 0 then
      text = SI.StringText:sub(1, SI.SelStart-1) .. sym:rep(tabLength - tabStart)
    else
      local tabEnd = editor.RealToTab(Id, numline, SI.SelEnd)
      text = SI.StringText:sub(1, SI.SelStart-1) ..
             (" "):rep(tabStart - tabLength) ..
             sym:rep(tabEnd - tabStart + 1) ..
             SI.StringText:sub(SI.SelEnd + 1)
    end
    editor.SetString(Id, numline, text, SI.StringEOL)
  end
  editor.UndoRedo(Id, "EUR_END")
  editor.SetPosition(Id, EI)
  editor.Redraw(Id)
end

local r = far.InputBox(nil, "Fill selection", "Enter 1 character", nil, nil, 1, nil, 0)
if r then Fill(nil, r) end

