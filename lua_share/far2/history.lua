--[=[
  Library functions:
    *  hobj = history.newfile (filename)
       *  description:   create a new history object from file
       *  @param filename: file name
       *  @return:       history object

    *  hobj = history.newsettings (subkey, name)
       *  description:   create a new history object from Far database
       *  @param subkey: subkey name of the plugin root key; nil for the root
       *  @param name:   name of the value
       *  @return:       history object

  Methods of history object:
    *  value = hobj:field (name)
       *  description:   get or create a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @return:       either value of existing field or a new table
       *  example:       hist:field("mydialog.namelist").width = 120

    *  value = hobj:getfield (name)
       *  description:   get a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @return:       value of a field
       *  example:       local namelist = hist:field("mydialog.namelist")

    *  value = hobj:setfield (name, value)
       *  description:   set a field
       *  @param name:   name (sequence of fields delimitered with dots)
       *  @param value:  value to set the field
       *  @return:       value
       *  example:       hist:setfield("mydialog.namelist.width", 120)

    *  hobj:save()
       *  description:   save history object

    *  str = hobj:serialize()
       *  description:   serialize history object
       *  @return:       serialized history object
--]=]

local serial  = require "serial"

local history = {}
local meta = { __index = history }

function history:serialize()
  return serial.SaveToString("Data", self.Data)
end

function history:field (fieldname)
  local tb = self.Data
  for v in fieldname:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  return tb
end

function history:getfield (fieldname)
  local tb = self.Data
  for v in fieldname:gmatch("[^.]+") do
    tb = tb[v]
  end
  return tb
end

function history:setfield (name, val)
  local tb = self.Data
  local part1, part2 = name:match("^(.-)([^.]*)$")
  for v in part1:gmatch("[^.]+") do
    tb[v] = tb[v] or {}
    tb = tb[v]
  end
  tb[part2] = val
  return val
end

local function new (chunk)
  local self
  if chunk then
    self = {}
    setfenv(chunk, self)()
    if type(self.Data) ~= "table" then self = nil end
  end
  self = self or { Data={} }
  return setmetatable(self, meta)
end

local function newfile (FileName)
  assert(type(FileName) == "string")
  local self = new(loadfile(FileName))
  self.FileName = FileName
  return self
end

local function GetSubkey (sett, strSubkey)
  local iSubkey = 0
  for name in strSubkey:gmatch("[^.]+") do
    iSubkey = sett:CreateSubkey(iSubkey, name)
    if iSubkey == nil then return nil end
  end
  return iSubkey
end

local function newsettings (strSubkey, strName)
  far.FreeSettings()
  local sett = far.CreateSettings()
  if sett then
    local iSubkey = strSubkey and GetSubkey(sett, strSubkey) or 0
    local data = sett:Get(iSubkey, strName, "FST_DATA") or ""
    sett:Free()
    local self = new(loadstring(data))
    self.Subkey, self.Name = strSubkey, strName
    return self
  end
end

function history:save()
  if self.FileName then
    serial.SaveToFile (self.FileName, "Data", self.Data)
  elseif self.Name then
    far.FreeSettings()
    local sett = far.CreateSettings()
    if sett then
      local iSubkey = self.Subkey and GetSubkey(sett, self.Subkey) or 0
      sett:Set(iSubkey, self.Name, "FST_DATA", self:serialize())
      sett:Free()
    end
  end
end

local function dialoghistory (name, from, to)
  local obj = far.CreateSettings("far")
  if obj then
    local root = obj:OpenSubkey(0, name) -- e.g., "NewFolder"
    local data = root and obj:Enum(root, from, to)
    obj:Free()
    return data
  end
end

return {
  newfile = newfile,
  newsettings = newsettings,
  dialoghistory = dialoghistory,
}
