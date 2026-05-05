-- luacheck: globals _Plugin

local F   = far.Flags

local ColorPriority = 100
local ColorFlags = bit64.bor(F.ECF_TABMARKCURRENT, F.ECF_AUTODELETE)
local ColorOwner = export.GetGlobalInfo().Guid
local Editors do
  Editors = _Plugin.Editors or {}
  _Plugin.Editors = Editors
end

local function ToggleHighlight()
  local info = editor.GetInfo()
  if info then
    local state = Editors[info.EditorID]
    if state then
      state.active = not state.active
      editor.Redraw()
    end
  end
end

local function ActivateHighlight (On)
  local info = editor.GetInfo()
  if info then
    local state = Editors[info.EditorID]
    if state then
      state.active = (On and true)
      editor.Redraw()
    end
  end
end

local function SetHighlightPattern (pattern, is_grep, line_numbers, bSkip)
  local info = editor.GetInfo()
  if info then
    local state = Editors[info.EditorID]
    if state then
      state.pattern = pattern
      if is_grep then state.is_grep = true; end -- can be only set
      state.line_numbers = line_numbers and true
      state.bSkip = bSkip
    end
  end
end

local function IsHighlightGrep()
  local info = editor.GetInfo()
  local state = info and Editors[info.EditorID]
  return state and state.is_grep
end

local function MakeGetString (Info)
  local ID = Info.EditorID
  local ymin = Info.TopScreenLine - 1
  local ymax = math.min(Info.TopScreenLine + Info.WindowSizeY - 1, Info.TotalLines)

  return function()
    if ymin < ymax then
      ymin = ymin + 1
      return editor.GetStringW(ID, ymin), ymin
    end
  end
end

---------------------------------------------------------------------------------------------------
-- @param EI: editor info table
-- @param Pattern: pattern object for finding matches in regular editor text
-- @param Priority: color priority (number) for added colors
-- @param ProcessLineNumbers: (used with Grep) locate line numbers at the beginning of lines
--                            and highlight them separately from regular editor text
---------------------------------------------------------------------------------------------------
local function RedrawHighlightPattern (EI, Pattern, Priority, ProcessLineNumbers, bSkip)
  local config = _Plugin.HField("config")
  local Color = config.EditorHighlightColor
  local ID = EI.EditorID
  local ufind = Pattern.ufindW or Pattern.ufind

  local prefixPattern = regex.new("^(\\d+([:\\-]))") -- (grep) 123: matched_line; 123- context_line
  local filenamePattern = regex.new("^\\[\\d+\\]")   -- (grep) [123] c:\dir1\dir2\filename
  local wideSC = win.Utf8ToUtf16(":")

  for str, y in MakeGetString(EI) do
    local filename_line -- reliable detection is possible only when ProcessLineNumbers is true
    local offset, text = 0, str.StringText
    if ProcessLineNumbers then
      local prefix, char = prefixPattern:matchW(text)
      if prefix then
        offset = win.lenW(prefix)
        text = win.subW(text, offset+1)
        local prColor = char==wideSC and config.GrepLineNumMatchColor or config.GrepLineNumContextColor
        editor.AddColor(ID, y, 1, offset, ColorFlags, prColor, Priority, ColorOwner)
      else
        filename_line = filenamePattern:matchW(text)
      end
    end

    if not filename_line then
      text = Pattern.ufindW and text or win.Utf16ToUtf8(text)
      local start = 1
      local RealLeftPos = editor.TabToReal(ID, y, EI.LeftPos)
      local maxstart = math.min(str.StringLength+1, RealLeftPos+EI.WindowSizeX-1) - offset

      while start <= maxstart do
        local from, to, collect = ufind(Pattern, text, start)
        if not from then break end
        start = to>=from and to+1 or from+1
        if not (bSkip and collect[1]) then
          if to >= from and to+offset >= RealLeftPos then
            editor.AddColor(ID, y, offset+from, offset+to, ColorFlags, Color, Priority, ColorOwner)
          end
        end
      end
    end
  end
end

local function ProcessEditorEvent (id, event, param)
  if event == F.EE_READ then
    Editors[id] = Editors[id] or {}
    Editors[id].sLastOp = "search"
  elseif event == F.EE_CLOSE then
    Editors[id] = nil
  elseif event == F.EE_REDRAW then
    local state = Editors[id] or {}
    Editors[id] = state
    if state.active and state.pattern then
      local ei = editor.GetInfo(id)
      if ei then
        RedrawHighlightPattern(ei, state.pattern, ColorPriority, state.line_numbers, state.bSkip)
      end
    end
  end
end

return {
  ActivateHighlight = ActivateHighlight,
  GetState = function(Id) return Editors[Id] end,
  IsHighlightGrep = IsHighlightGrep,
  ProcessEditorEvent = ProcessEditorEvent,
  SetHighlightPattern = SetHighlightPattern,
  ToggleHighlight = ToggleHighlight,
}
