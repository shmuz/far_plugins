local M = require "modules.string_rc"

-- Show error message
local function ErrMsg (msg, title, flags)
  far.Message(msg, title or M.title_short, nil, flags or "wl")
end

-- Resize a string
local function Resize (str, n, char)
  local ln = str:len()
  if n <  ln then return str:sub(1, n) end
  if n == ln then return str end
  return str .. (char or "\0"):rep(n-ln)
end

-- Normalize a string. Use for schema, table and column names.
local function Norm (str)
  return "'" .. string.gsub(str, "'", "''") .. "'"
end

local function get_temp_file_name(ext)
  return far.MkTemp() .. (ext and "."..ext or "")
end

local function lang(msg, trep)
  assert(type(msg)=="string" and type(trep)=="table")
  msg = msg:gsub("{(%d+)}", function(c) return trep[tonumber(c)] end)
  return msg
end

local function get_rowid(PanelItem)
  local fname = PanelItem and PanelItem.FileName
  return fname and fname~=".." and PanelItem.Owner
end

local StrBuffer = {}
local StrBuffer_MT = {__index=StrBuffer}
function StrBuffer:Add(s)         self[#self+1] = s; return self; end
function StrBuffer:Concat(delim)  return table.concat(self, delim) end
local function StringBuffer()     return setmetatable({}, StrBuffer_MT) end

return {
  ErrMsg       = ErrMsg;
  get_rowid    = get_rowid;
  get_temp_file_name = get_temp_file_name;
  lang         = lang;
  Norm         = Norm;
  Resize       = Resize;
  StringBuffer = StringBuffer;
}
