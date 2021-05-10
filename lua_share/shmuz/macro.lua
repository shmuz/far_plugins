-- simple macro processor
-- started: 2012-02-16

local prefix = "#{"
local suffix = "}"
local pattern = prefix .. "([%a_][%w_]*)" .. suffix

local function get_predefined (_, c)
  if c == "DATE" then
    local t = os.date("*t")
    return ("%d-%02d-%02d"):format(t.year, t.month, t.day)
  elseif c == "TIME" then
    local t = os.date("*t")
    return ("%02d:%02d:%02d"):format(t.hour, t.min, t.sec)
  else
    error(c .. " is undefined")
  end
end

local meta = { __index = get_predefined }

local function preprocess (mapfile, srcfile, trgfile)
  assert(trgfile, "three arguments required")
  local map = setmetatable({}, meta)
  if _VERSION == "Lua 5.1" then
    setfenv(assert(loadfile(mapfile)), map)()
  else
    assert(loadfile(mapfile, "t", map))()
  end
  local fp = assert(io.open(srcfile, "rb"))
  local str = fp:read("*all")
  fp:close()
  str = string.gsub(str, pattern, map)
  fp = assert(io.open(trgfile, "wb"))
  fp:write(str)
  fp:close()
end

return preprocess
