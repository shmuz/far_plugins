-- simple macro processor
-- started: 2012-02-16

local prefix, suffix = "#{", "}"
local pattern = prefix .. "[%a_][%w_]*" .. suffix
local meta = { __index = function(t,c) error(c .. " is undefined") end }

local function preprocess (mapfile, file1, file2)
  assert(file2, "three arguments required")
  local map = {}
  setfenv(assert(loadfile(mapfile)), map)()
  local t_rep = setmetatable({}, meta)
  for key, val in pairs(map) do t_rep[prefix..key..suffix] = val end
  local fp = assert(io.open(file1, "rb"))
  local str = fp:read("*all")
  fp:close()
  str = string.gsub(str, pattern, t_rep)
  fp = assert(io.open(file2, "wb"))
  fp:write(str)
  fp:close()
end

return preprocess
