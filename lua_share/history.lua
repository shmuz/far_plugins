--[=[
  Functions:
    *  h = history.new (filename)
       *  description:  create a new history object
       *  parameters:   a file name
       *  returns:      an object

  Methods:
    *  h:field (name)
       *  description:  get or create a field
       *  parameters:   name (sequence of fields delimitered with dots)
       *  returns:      a table
       *  example:      hist:field("mydialog.namelist").width = 120

    *  h:setfield (name, value)
       *  description:  set a field
       *  parameters:   name (sequence of fields delimitered with dots)
       *  returns:      value
       *  example:      hist:setfield("mydialog.namelist", {})

    *  h:save()
       *  description:  save history object in file
       *  parameters:   none
       *  returns:      none
--]=]

local Package = {}
local serial  = require "serial"

local history = {}
local meta = { __index = history }

local function GetOrCreateField (tb, name)
  for v in name:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  return tb
end

local function SetField (tb, name, val)
  local part1, part2 = name:match("^(.-)([^.]*)$")
  for v in part1:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  tb[part2] = val
  return val
end

local function load (filename)
  local f = loadfile (filename)
  if f then
    local env = {}
    setfenv (f, env)()
    return env
  end
end

function history:save()
  serial.SaveInFile (self.FileName, "Data", self.Data)
end

function history:field (fieldname)
  return GetOrCreateField (self.Data, fieldname)
end

function history:setfield (name, val)
  return SetField (self.Data, name, val)
end

function Package.new (filename)
  assert(type(filename) == "string")
  local self = load (filename) or { Data = {} }
  if type(self.Data) ~= "table" then self.Data = {} end
  self.FileName = filename
  return setmetatable(self, meta)
end

return Package
