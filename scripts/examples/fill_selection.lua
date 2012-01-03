-- started: 2011-02-17

local function Fill (Id, sym)
  local Sel = editor.GetSelection(Id)
  if not Sel then return end
  sym = sym:sub(1, 1)
  editor.UndoRedo(Id, "EUR_BEGIN")
  for L=Sel.StartLine, Sel.EndLine do
    local S, s = editor.GetString(Id, L, 1)
    if S.SelEnd < 0 then
      s = S.StringText:sub(1, S.SelStart) .. sym:rep(S.StringLength - S.SelStart)
    else
      s = S.StringText:sub(1, S.SelStart) ..
          (" "):rep(S.SelStart - S.StringLength) ..
          sym:rep(S.SelEnd - S.SelStart) ..
          S.StringText:sub(S.SelEnd + 1)
    end
    editor.SetString(Id, nil, s, S.StringEOL)
  end
  editor.UndoRedo(Id, "EUR_END")
  editor.Redraw(Id)
end

local r = far.InputBox(nil, "Fill selection", "Enter 1 character", nil, nil, 1, nil, 0)
if r then Fill(nil, r) end

