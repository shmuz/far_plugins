-- This module is created from source code of LuaMacro plugin.
-- Reason: make this functionality available to _any_ LuaFAR plugin.
-- The module's exported functions (serialize, deserialize, mdelete, mload, msave)
-- are described in macroapi_manual.<lang>.chm.

local F = far.Flags

local function checkarg (arg, argnum, reftype)
  if type(arg) ~= reftype then
    error(("arg. #%d: %s expected, got %s"):format(argnum, reftype, type(arg)), 3)
  end
end

local function basicSerialize (o)
  local tp = type(o)
  if tp == "nil" or tp == "boolean" then
    return tostring(o)
  elseif tp == "number" then
    if o == math.modf(o) then return tostring(o) end
    return string.format("(%.17f * 2^%d)", math.frexp(o)) -- preserve accuracy
  elseif tp == "string" then
    return string.format("%q", o)
  end
end

local function int64Serialize (o)
  if bit64.type(o) then
    return "bit64.new(\"" .. tostring(o) .. "\")"
  end
end

local function AddToIndex (idx, t)
  local n = idx[t]
  if not n then
    n = #idx + 1
    idx[n], idx[t] = t, n
    for k,v in pairs(t) do
      if type(k)=="table" then AddToIndex(idx, k) end
      if type(v)=="table" then AddToIndex(idx, v) end
    end
    if debug.getmetatable(t) then AddToIndex(idx,debug.getmetatable(t)) end
  end
end

local function tableSerialize (tbl)
  if type(tbl) == "table" then
    local idx = {}
    AddToIndex(idx, tbl)
    local lines = { "local idx={}; for i=1,"..#idx.." do idx[i]={} end" }
    for i,t in ipairs(idx) do
      local found
      lines[#lines+1] = "do local t=idx["..i.."]"
      for k,v in pairs(t) do
        local k2 = basicSerialize(k) or type(k)=="table" and "idx["..idx[k].."]"
        if k2 then
          local v2 = basicSerialize(v) or int64Serialize(v) or type(v)=="table" and "idx["..idx[v].."]"
          if v2 then
            found = true
            lines[#lines+1] = "  t["..k2.."] = "..v2
          end
        end
      end
      if found then lines[#lines+1]="end" else lines[#lines]=nil end
    end
    for i,t in ipairs(idx) do
      local mt = debug.getmetatable(t)
      if mt then
        lines[#lines+1] = "setmetatable(idx["..i.."], idx["..idx[mt].."])"
      end
    end
    lines[#lines+1] = "return idx[1]\n"
    return table.concat(lines, "\n")
  end
  return nil
end

local function serialize (o)
  local s = basicSerialize(o) or int64Serialize(o)
  return s and "return "..s or tableSerialize(o)
end

local function deserialize (str)
  checkarg(str, 1, "string")
  local chunk, err = loadstring(str)
  if chunk==nil then return nil,err end

  setfenv(chunk, { bit64={new=bit64.new}; setmetatable=setmetatable; })
  local ok, result = pcall(chunk)
  if not ok then return nil,result end

  return result,nil
end

local function mdelete (key, name, location)
  checkarg(key, 1, "string")
  checkarg(name, 2, "string")
  local ret = false
  local obj = far.CreateSettings(nil, location=="local" and "PSL_LOCAL" or "PSL_ROAMING")
  if obj then
    local subkey = obj:OpenSubkey(0, key)
    ret = (subkey or false) and obj:Delete(subkey, name~="*" and name or nil)
    obj:Free()
  end
  return ret
end

local function msave (key, name, value, location)
  checkarg(key, 1, "string")
  checkarg(name, 2, "string")
  local ret = false
  local str = serialize(value)
  if str then
    local obj = far.CreateSettings(nil, location=="local" and "PSL_LOCAL" or "PSL_ROAMING")
    if obj then
      local subkey = obj:CreateSubkey(0, key)
      ret = (subkey or false) and obj:Set(subkey, name, F.FST_DATA, str)
      obj:Free()
    end
  end
  return ret
end

local function mload (key, name, location)
  checkarg(key, 1, "string")
  checkarg(name, 2, "string")
  local val, err
  local obj = far.CreateSettings(nil, location=="local" and "PSL_LOCAL" or "PSL_ROAMING")
  if obj then
    local subkey = obj:OpenSubkey(0, key)
    if subkey then
      local chunk = obj:Get(subkey, name, F.FST_DATA)
      if chunk then
        val, err = deserialize(chunk)
      else
        err = "method Get() failed"
      end
    else
      err = "method OpenSubkey() failed"
    end
    obj:Free()
  else
    err = "far.CreateSettings() failed"
  end
  return val, err
end

return {
  deserialize = deserialize;
  mdelete = mdelete;
  mload = mload;
  msave = msave;
  serialize = serialize;
}
