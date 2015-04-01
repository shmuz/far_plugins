-- Key names
-- Original author: Aidar Rakhmatullin

local F = far.Flags
local band = bit64.band
local FARMACRO_KEY_EVENT = 0x8001 -- removed from Far in build 4321 (2015-03-21);
                                  -- left here for compatibility with older versions;
-- ControlKeyState.
local VKey_State = {
  RIGHT_ALT_PRESSED  = 0x0001,
  LEFT_ALT_PRESSED   = 0x0002,
  RIGHT_CTRL_PRESSED = 0x0004,
  LEFT_CTRL_PRESSED  = 0x0008,
  SHIFT_PRESSED = 0x0010,
  NUMLOCK_ON    = 0x0020,
  SCROLLLOCK_ON = 0x0040,
  CAPSLOCK_ON   = 0x0080,
  ENHANCED_KEY  = 0x0100,
} --- VKey_State

local VKey_Keys = win.GetVirtualKeys()

local VKey_Mods = {
  [0x10] = "SHIFT",   -- Shift
  [0x11] = "CONTROL", -- Ctrl
  [0x12] = "MENU",    -- Alt
  [0x5B] = "LWIN",
  [0x5C] = "RWIN",
  [0x5D] = "APPS",
  [0xA0] = "LSHIFT",
  [0xA1] = "RSHIFT",
  [0xA2] = "LCONTROL",
  [0xA3] = "RCONTROL",
  [0xA4] = "LMENU",
  [0xA5] = "RMENU",
} --- VKey_Mods

-- VK_ key names
local VKey_Names = {
  CANCEL    = "Break",
  BACK      = "BS",
  TAB       = "Tab",

  --CLEAR     = "Clear", -- Enhanced
  CLEAR     = "Num5", -- Non-enhanced
  RETURN    = "Enter",

  PAUSE     = "Pause",
  CAPITAL   = "CapsLock",

  ESCAPE    = "Esc",
  SPACE     = "Space",

  PRIOR     = "PgUp",
  NEXT      = "PgDn",
  END       = "End",
  HOME      = "Home",
  LEFT      = "Left",
  UP        = "Up",
  RIGHT     = "Right",
  DOWN      = "Down",

  SNAPSHOT  = "PrintScreen",
  INSERT    = "Ins",
  --DELETE    = "Del", -- Enhanced
  DELETE    = "Decimal", -- Non-enhanced

  LWIN      = "LWin",
  RWIN      = "RWin",
  APPS      = "Apps",
  SLEEP     = "Sleep",

  NUMPAD0   = "Num0",
  NUMPAD1   = "Num1",
  NUMPAD2   = "Num2",
  NUMPAD3   = "Num3",
  NUMPAD4   = "Num4",
  NUMPAD5   = "Num5",
  NUMPAD6   = "Num6",
  NUMPAD7   = "Num7",
  NUMPAD8   = "Num8",
  NUMPAD9   = "Num9",

  MULTIPLY  = "Multiply",
  ADD       = "Add",
  SEPARATOR = "Separator",
  SUBTRACT  = "Subtract",
  DECIMAL   = "Decimal",
  DIVIDE    = "Divide",

  -- F1 -- F24 -- no change

  NUMLOCK   = "NumLock",
  SCROLL    = "ScrollLock",

  BROWSER_BACK      = "BrowserBack",
  BROWSER_FORWARD   = "BrowserForward",
  BROWSER_REFRESH   = "BrowserRefresh",
  BROWSER_STOP      = "BrowserStop",
  BROWSER_SEARCH    = "BrowserSearch",
  BROWSER_FAVORITES = "BrowserFavorites",
  BROWSER_HOME      = "BrowserHome",
  VOLUME_MUTE       = "VolumeMute",
  VOLUME_DOWN       = "VolumeDown",
  VOLUME_UP         = "VolumeUp",
  MEDIA_NEXT_TRACK  = "MediaNextTrack",
  MEDIA_PREV_TRACK  = "MediaPrevTrack",
  MEDIA_STOP        = "MediaStop",
  MEDIA_PLAY_PAUSE  = "MediaPlayPause",
  LAUNCH_MAIL       = "LaunchMail",
  LAUNCH_MEDIA_SELECT = "LaunchMediaSelect",
  LAUNCH_APP1       = "LaunchApp1",
  LAUNCH_APP2       = "LaunchApp2",

  OEM_1         = ";",      -- ";:"
  OEM_PLUS      = "=",      -- "+="
  OEM_COMMA     = ",",      -- ",<"
  OEM_MINUS     = "-",      -- "-_"
  OEM_PERIOD    = ".",      -- ".>"
  OEM_2         = "/",      -- "/?"
  OEM_3         = "`",      -- "`~"
  OEM_4         = "[",      -- "[{"
  OEM_5         = "\\",     -- "\\|"
  OEM_6         = "]",      -- "]}"
  OEM_7         = "'",     -- "'"..'"'
  --OEM_8         = "",       -- ""

  [" "]         = "Space",
} --- VKey_Names

-- Enhanced keys:
local SKey_Enhanced = {
  Num5    = "Clear",
  Decimal = "Del",
  Enter   = "NumEnter",
} --- SKey_Enhanced

---------------------------------------- local

-- Check flag in mod.
local function ismod (mod, flag)
  return band(mod, flag) ~= 0
end

----------------------------------------
local function KeyStateToTable (KeyState)
  local t = {"","",""}

  if ismod(KeyState, VKey_State.RIGHT_CTRL_PRESSED)    then t[1] = "RCtrl"
  elseif ismod(KeyState, VKey_State.LEFT_CTRL_PRESSED) then t[1] = "Ctrl"
  end
  if ismod(KeyState, VKey_State.RIGHT_ALT_PRESSED)     then t[2] = "RAlt"
  elseif ismod(KeyState, VKey_State.LEFT_ALT_PRESSED)  then t[2] = "Alt"
  end
  if ismod(KeyState, VKey_State.SHIFT_PRESSED)         then t[3] = "Shift" end

  return t
end -- KeyStateToTable

local function InputRecordToName (Rec, isSeparate)
  -- Keyboard only.
  if Rec.EventType ~= F.KEY_EVENT and Rec.EventType ~= FARMACRO_KEY_EVENT then
    return far.InputRecordToName(Rec, isSeparate)
  end

  local VKey, SKey = Rec.VirtualKeyCode, ""
  local VMod = Rec.ControlKeyState

  if (VKey >= 0x30 and VKey <= 0x39) or (VKey >= 0x41 and VKey <= 0x5A) then
    SKey = string.char(VKey)
  elseif not VKey_Mods[VKey] then
    SKey = VKey_Keys[VKey] or ""
    SKey = VKey_Names[SKey] or SKey
  end

  if ismod(VMod, VKey_State.ENHANCED_KEY) then
    SKey = SKey_Enhanced[SKey] or SKey
  end

  local TMod = KeyStateToTable(VMod)
  TMod[4] = SKey
  if isSeparate then
    for k=1,4 do
      if TMod[k]=="" then TMod[k]=false end
    end
    return unpack(TMod)
  else
    return table.concat(TMod)
  end
end -- InputRecordToName

return {
  InputRecordToName = InputRecordToName,
}
