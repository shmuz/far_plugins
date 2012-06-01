local F=far.Flags

local function MergeLines (delim)
  local info=editor.GetInfo()
  if info.BlockType~=F.BTYPE_STREAM then return end

  editor.UndoRedo(Id, F.EUR_BEGIN)
  local t={}
  local lineno=info.BlockStartLine
  editor.SetPosition(nil, lineno)
  while true do
    local line=editor.GetString()
    if line.SelStart<0 or line.SelEnd>=0 then break end
    t[#t+1]=line.StringText
    editor.DeleteString()
  end
  if #t > 0 then
    editor.SetPosition(nil, nil, 0)
    editor.InsertString()
    editor.SetString(nil, lineno, table.concat(t, delim))
    editor.Select (nil, F.BTYPE_STREAM, lineno, 0, 0, 2)
    editor.Redraw()
  end
  editor.UndoRedo(Id, F.EUR_END)
end

local arg=...
local delim = type(arg)=="table" and arg[1] or nil
MergeLines(delim)
