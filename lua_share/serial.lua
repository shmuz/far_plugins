-- file beginning

local Package = {}
local tostring, type = tostring, type
local strformat = string.format
local frexp, modf = math.frexp, math.modf


local function basicSerialize (o)
  local tp = type(o)
  if tp == "boolean" then
    return tostring(o)
  elseif tp == "number" then
    if o == modf(o) then return tostring(o) end
    return strformat("(%.17f * 2^%d)", frexp(o)) -- preserve accuracy
  else -- assume it is a string
    return strformat("%q", o)
  end
end


local basic = { ["number"]=true, ["string"]=true, ["boolean"]=true }


local function save (name, value, saved, f_write)
  if basic[type(value)] then
    f_write(name, " = ", basicSerialize(value), "\n")
    return
  end

  if type(value) ~= "table" then
    return
  end

  saved = saved or {}  -- initial value
  if saved[value] then   -- value already saved?
    f_write(name, " = ", saved[value], "\n") -- use its previous name
    return
  end

  -- Assigning (nested) tables to local variables (t or u), for speeding up;
  --   *  improves loadstring performance by approx. 30-40%;
  --   *  makes saved file/string smaller;
  local tname = (name == "t") and "u" or "t" -- prevent collision of name and tname

  -- Precompute some strings used in the recursive function `save_table'
  -- (worsens readability but improves performance)
  local str1 = "do local " ..tname.. " = {}; "
  local str2 = " = " ..tname.. "\n"
  local str3 = tname .. "[%s] = %s\n"

  -- Call this function only if the table has not been already saved.
  -- Upvalues: saved, f_write, str1, str2, str3
  local function save_table (name, tbl, indent)
    saved[tbl] = name  -- save name for next time
    f_write(indent, str1, name, str2)
    indent = indent .. "  "
    for k,v in pairs(tbl) do    -- save its fields
      if basic[type(k)] then
        if basic[type(v)] then
          f_write(indent, strformat(str3, basicSerialize(k), basicSerialize(v)))
        elseif type(v) == "table" then
          local fieldname = strformat("%s[%s]", name, basicSerialize(k))
          if saved[v] then   -- table already saved?
            f_write(indent, fieldname, " = ", saved[v], "\n") -- use its previous name
          else
            if next(v) then
              save_table(fieldname, v, indent) -- recursion
            else
              saved[v] = fieldname
              fieldname = strformat("%s[%s]", tname, basicSerialize(k))
              f_write(indent, fieldname, " = {}\n")
            end
          end
        end
      end
    end
    indent = indent:sub(1, -3)
    f_write(indent .. "end\n");
  end
  save_table (name, value, "")
end


local function save_in_file (filename, name, value)
  local fh = assert (io.open (filename, "w"))
  save (name, value, {}, function (...) fh:write (...) end)
  fh:close()
end


Package.Save = save
Package.SaveInFile = save_in_file
return Package

