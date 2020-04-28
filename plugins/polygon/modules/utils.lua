local mod = {}

local M = require "modules.string_rc"

-- Show error message
function mod.ErrMsg (msg, title, flags)
  far.Message(msg, title or M.ps_title_short, nil, flags or "wl")
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
  return "'" .. str:gsub("'","''") .. "'"
end

return mod
