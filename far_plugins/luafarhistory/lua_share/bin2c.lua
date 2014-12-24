-- Goal: make a C-array out of an arbitrary Lua string
-- Started by Shmuel Zeigerman, 2008-08-22

local function bin2c (subj, name, len, func, obj)
  name = name or "array"
  len = len or 18
  assert(type(name) == "string")
  assert(type(len) == "number")
  local tout
  if not func then
    tout = {}
    func, obj = table.insert, tout
  end
  local count = 0
  func(obj, "char ")
  func(obj, name)
  func(obj, "[] = {\n")
  for c in subj:gmatch(".") do
    if count == 0 then func(obj, "  ") end
    local v = c:byte()
    if v < 100 then func(obj, " ") end
    func(obj, v)
    func(obj, ",")
    count = count + 1
    if count == len then count = 0; func(obj, "\n"); end
  end
  if count ~= 0 then func(obj, "\n") end
  func(obj, "};\n")
  return tout and table.concat(tout) or obj
end

return bin2c
