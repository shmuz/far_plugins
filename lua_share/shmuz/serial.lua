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


local function save_table (name, tbl, indent, saved, f_write, opaq, tname)
  if saved[tbl] then   -- table already saved?
    f_write(opaq, indent, name, " = ", saved[tbl], "\n") -- use its previous name
    return
  end
  saved[tbl] = name  -- save name for next time
  f_write(opaq, indent, "do local ", tname, " = {}; ", name, " = ", tname, "\n")
  local indent2 = indent .. "  "
  for k,v in pairs(tbl) do    -- save its fields
    local sKey = basicSerialize(k)
    if sKey then
      local sVal, tp = basicSerialize(v)
      if sVal then
        f_write(opaq, indent2, tname, "[", sKey, "] = ", sVal, "\n")
      elseif tp == "table" then
        local fieldname = name .. "[" .. sKey .. "]"
        save_table(fieldname, v, indent2, saved, f_write, opaq, tname)
      end
    end
  end
  f_write(opaq, indent .. "end\n");
end


local function Save (name, value, saved, f_write, opaq)
  local sVal, tp = basicSerialize(value)
  if sVal then
    f_write(opaq, name, " = ", sVal, "\n")
    return
  end

  if tp ~= "table" then return end

  saved = saved or {}  -- initial value

  -- Assigning (nested) tables to local variables (t or u), for speeding up;
  --   *  improves loadstring performance by approx. 30-40%;
  --   *  makes saved file/string smaller;
  local tname = (name == "t") and "u" or "t" -- prevent collision of name and tname
  save_table (name, value, "", saved, f_write, opaq, tname)
end


local function SaveToFile (filename, name, value)
  local fh = assert (io.open (filename, "w"))
  Save (name, value, {}, function (fh, ...) fh:write (...) end, fh)
  fh:close()
end


local function SaveToString (name, value)
  local arr = {}
  Save(name, value, nil,
    function (arr, ...)
      for i=1, select("#", ...) do
        arr[#arr+1] = select(i, ...)
      end
    end, arr)
  return table.concat(arr)
end


return {
  Save = Save,
  SaveToFile = SaveToFile,
  SaveToString = SaveToString,
}
