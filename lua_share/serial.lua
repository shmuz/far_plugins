-- file beginning

local tostring, type = tostring, type
local format = string.format
local frexp, modf = math.frexp, math.modf


local function basicSerialize (value)
  local tp = type(value)
  if tp == "boolean" then
    return value and "true" or "false"
  elseif tp == "number" then
    if value == modf(value) then return format("%.0f", value) end
    return format("(%.17f * 2^%d)", frexp(value))
  elseif tp == "string" then
    return format("%q", value)
  end
  return nil, tp
end


local function Save (name, value, saved, f_write)
  local sVal, tp = basicSerialize(value)
  if sVal then
    f_write(name, " = ", sVal, "\n")
    return
  end

  if tp ~= "table" then return end

  saved = saved or {}  -- initial value

  -- Assigning (nested) tables to local variables (t or u), for speeding up;
  --   *  improves loadstring performance by approx. 30-40%;
  --   *  makes saved file/string smaller;
  local tname = (name == "t") and "u" or "t" -- prevent collision of name and tname

  -- Upvalues: saved, f_write, tname
  local function save_table (name, tbl, indent)
    if saved[tbl] then   -- table already saved?
      f_write(indent, name, " = ", saved[tbl], "\n") -- use its previous name
      return
    end
    saved[tbl] = name  -- save name for next time
    f_write(indent, "do local ", tname, " = {}; ", name, " = ", tname, "\n")
    local indent2 = indent .. "  "
    for k,v in pairs(tbl) do    -- save its fields
      local sKey = basicSerialize(k)
      if sKey then
        local sVal, tp = basicSerialize(v)
        if sVal then
          f_write(indent2, tname, "[", sKey, "] = ", sVal, "\n")
        elseif tp == "table" then
          local fieldname = name .. "[" .. sKey .. "]"
          save_table(fieldname, v, indent2)
        end
      end
    end
    f_write(indent .. "end\n");
  end
  save_table (name, value, "")
end


local function SaveToFile (filename, name, value)
  local fh = assert (io.open (filename, "w"))
  Save (name, value, {}, function (...) fh:write (...) end)
  fh:close()
end


local function SaveToString (name, value)
  local arr, n = {}, 0
  Save(name, value, nil,
    function(...)
      for i=1, select("#", ...) do
        n = n + 1; arr[n] = select(i, ...)
      end
    end)
  return table.concat(arr)
end


return {
  Save = Save,
  SaveToFile = SaveToFile,
  SaveToString = SaveToString,
}
