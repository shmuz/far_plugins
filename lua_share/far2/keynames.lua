-- Original author: Aidar Rakhmatullin

-- Key names

--[[
local log = require "context.samples.logging"
local logShow = log.Show
--]]

local F = far.Flags

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
  SHIFT     = 0x10, -- Shift
  CONTROL   = 0x11, -- Ctrl
  MENU      = 0x12, -- Alt
  LWIN      = 0x5B,
  RWIN      = 0x5C,
  APPS      = 0x5D,
  LSHIFT    = 0xA0,
  RSHIFT    = 0xA1,
  LCONTROL  = 0xA2,
  RCONTROL  = 0xA3,
  LMENU     = 0xA4,
  RMENU     = 0xA5,
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
local band = bit64.band

-- Check flag in mod.
local function ismod (mod, flag)
  return band(mod, flag) ~= 0
end

----------------------------------------
local tconcat = table.concat

local function KeyStateToName (KeyState)
  local t = {}

  if ismod(KeyState, VKey_State.RIGHT_CTRL_PRESSED) then t[#t+1] = "RCtrl" end
  if ismod(KeyState, VKey_State.LEFT_CTRL_PRESSED)  then t[#t+1] = "Ctrl"  end
  if ismod(KeyState, VKey_State.RIGHT_ALT_PRESSED)  then t[#t+1] = "RAlt"  end
  if ismod(KeyState, VKey_State.LEFT_ALT_PRESSED)   then t[#t+1] = "Alt"   end
  if ismod(KeyState, VKey_State.SHIFT_PRESSED)      then t[#t+1] = "Shift" end

  return tconcat(t)
end -- KeyStateToName

local schar = string.char

local function InputRecordToName (Rec, isSeparate)
  -- Keyboard only.
  if Rec.EventType ~= F.KEY_EVENT then
    return far.InputRecordToName(Rec)
  end

  --logShow{ "VirKey", Rec }

  local VKey, SKey = Rec.VirtualKeyCode
  local VMod, SMod = Rec.ControlKeyState, ""

  if VKey >= 0x30 and VKey <= 0x39 or
     VKey >= 0x41 and VKey <= 0x5A then
    SKey = schar(VKey)
  elseif VKey_Mods[VKey] then
    SKey = ""
  elseif not SKey then
    SKey = VKey_Keys[VKey] or ""
    SKey = VKey_Names[SKey] or SKey
  end

  if ismod(VMod, VKey_State.ENHANCED_KEY) then
    SKey = SKey_Enhanced[SKey] or SKey
  end

  if VMod ~= 0 then
    SMod = KeyStateToName(VMod) or ""
  end

  local KeyName = SMod..SKey
  if isSeparate then
    local c, a, s, key = regex.match(KeyName, "(R?Ctrl)?(R?Alt)?(Shift)?(.*)")
    return c, a, s, key ~= "" and key or false
  else
    return KeyName
  end
end -- InputRecordToName

return {
  InputRecordToName = InputRecordToName,
}
