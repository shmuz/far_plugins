-- started: 2010-05-30
-- author: Shmuel Zeigerman

--[[---------------------------------------------------------------------------
Purpose:
  Makes  creation and  maintenance of  LuaFAR plugins'  language files
  easy. Only one file ("template file") needs to be  maintained, while
  the  "language  files"  and  the  "Lua  module  file"  are generated
  automatically. The order of message blocks in the template file does
  not matter.
-------------------------------------------------------------------------------
Input:
  @aFiles
    Array of description tables (a table per language).
    Each description table must contain fields 'filename' and 'line1'.

    The ['module'] field
      Name of Lua module file to be generated. This file will be
      require()'d by every file that needs to use this message system.

  @aOutDir
    Directory where the output .LNG files should be placed.
    It may be nil, then the current directory will be used.

  @...
    Arbitrary  number  of  "template"  file names  (at least  one file
    must be specified) .

    Each template file  contains "message  blocks" delimited  by empty
    lines. A  message block  consists of  an "identifier"  line (first
    non-comment line; unquoted) following by one or more "value" lines
    (line  per  language;  quoted).  The   order  of   languages  must
    correspond to that in `aDescriptions' argument. No empty lines are
    permitted within a  message block.  Comment lines  (beginning with
    //)   are   permitted;   they   are   ignored   by   the   parser.

    "Value"  line  next  to  "identifier"  line is  considered default
    value. If any of the  following values  equals to  "upd:" (without
    quotes)   then   the   default   value  is   substituted  instead.
-------------------------------------------------------------------------------
Files written:
  A) Lua module file.
  B) Language  files  (file per  language). These  files begin  with a
     UTF-8 BOM.
-------------------------------------------------------------------------------
Returns:
  Nothing. (If something goes wrong, errors are raised).
-------------------------------------------------------------------------------
--]]

local function joinpath(s1, s2)
  s1 = string.gsub(s1.."\\"..s2, "\\+", "\\")
  return s1
end


local function get_quoted(s)
  if s:sub(1,1) ~= '"' then
    error("no opening quote in line: " .. s)
  end
  local len, q = 1, nil
  for c in s:sub(2):gmatch("\\?.") do
    len = len + c:len()
    if c == '"' then q=c break end
  end
  if not q then
    error("no closing quote in line: " .. s)
  end
  return s:sub(1, len)
end


local function MakeLang (aFiles, aOutDir, ...)
  assert (type(aFiles) == "table")
  assert (type(aFiles.module) == "string")

  aOutDir = aOutDir or "."
  assert (type(aOutDir) == "string")

  local aTemplates = {...}
  assert(aTemplates[1], "no templates specified")

  local bom_utf8 = "\239\187\191"
  local t_out = {}
  for k=1, 1 + #aFiles do t_out[k] = {} end

  for _, fname in ipairs(aTemplates) do
    local fp = assert(io.open(fname))
    local sMessages = fp:read("*a")
    fp:close()
    if string.sub(sMessages, 1, 3) == bom_utf8 then
      sMessages = string.sub(sMessages, 4)
    end

    local n = 0
    local dflt
    for line in (sMessages.."\n\n"):gmatch("([^\r\n]*)\r?\n") do
      if not line:match("^%s*//") then -- comment lines are always skipped
        if line:match("%S") then
          n = n + 1
          if n > #t_out then
            error("extra line in block: " .. line)
          elseif n == 1 then
            local ident = line:match("^([%a_][%w_]*)%s*$")
            if ident then
              table.insert(t_out[n], ident)
            else
              error("bad message name: `" .. line .. "'")
            end
          elseif n == 2 then
            dflt = get_quoted(line)
            table.insert(t_out[n], dflt)
          else
            table.insert(t_out[n],
                         line:match("^upd:") and "// need translation:\n"..dflt or get_quoted(line))
          end
        else -- empty line: serves as a delimiter between blocks
          if n > 0 then
            if n < #t_out then
              local t = t_out[1]
              error("too few lines in block `" .. t[#t] .. "'")
            end
            n = 0
          end
        end
      end
    end
  end
  ----------------------------------------------------------------------------
  -- check for duplicates
  local map = {}
  for _,name in ipairs(t_out[1]) do
    if map[name] then error("duplicate name: " .. name) end
    map[name] = true
  end
  ----------------------------------------------------------------------------
  local fp = assert(io.open(aFiles.module, "w"))
  fp:write("-- This file is auto-generated. Don't edit.\n\n")
  fp:write("local indexes = {\n")
  for k,name in ipairs(t_out[1]) do
    fp:write("  ", name, " = ", k-1, ",\n")
  end
  fp:write([[
}
local GetMsg = far.GetMsg
return setmetatable( {},
  { __index = function(t,s) return GetMsg(indexes[s]) end } )
]])
  fp:close()
  ----------------------------------------------------------------------------
  for k,v in ipairs(aFiles) do
    fp = assert(io.open(joinpath(aOutDir, v.filename), "w"))
    fp:write(bom_utf8, v.line1, "\n\n")
    fp:write(table.concat(t_out[k+1], "\n"), "\n")
    fp:close()
  end
end

return MakeLang
