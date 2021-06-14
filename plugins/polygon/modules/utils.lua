local mod = {}

local M = require "modules.string_rc"

-- Show error message
function mod.ErrMsg (msg, title, flags)
  far.Message(msg, title or M.title_short, nil, flags or "wl")
end

-- Resize a string
function mod.Resize (str, n, char)
  local ln = str:len()
  if n <  ln then return str:sub(1, n) end
  if n == ln then return str end
  return str .. (char or "\0"):rep(n-ln)
end

-- Normalize a string. Use for schema, table and column names.
function mod.Norm (str)
  return "'" .. string.gsub(str, "'", "''") .. "'"
end

function mod.get_temp_file_name(ext)
  return far.MkTemp() .. (ext and "."..ext or "")
end

function mod.lang(msg, trep)
  assert(type(msg)=="string" and type(trep)=="table")
  msg = msg:gsub("{(%d+)}", function(c) return trep[tonumber(c)] end)
  return msg
end

return mod
