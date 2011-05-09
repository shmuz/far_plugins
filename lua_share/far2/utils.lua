-- utils.lua --

local history = require "history"
local Package = {}
local F = far.GetFlags()
local PluginDir = far.PluginStartupInfo().ModuleName:match(".*\\")

function Package.CheckLuafarVersion (reqVersion, msgTitle)
  local v1, v2 = far.LuafarVersion(true)
  local r1, r2 = reqVersion:match("^(%d+)%.(%d+)")
  r1, r2 = tonumber(r1), tonumber(r2)
  if (v1 > r1) or (v1 == r1 and v2 >= r2) then return true end
  far.Message(
    ("LuaFAR %s or newer is required\n(loaded version is %s)")
    :format(reqVersion, far.LuafarVersion()),
    msgTitle, ";Ok", "w")
  return false
end

local function OnError (msg)
  local Lower = far.LLowerBuf

  local tPaths = { Lower(PluginDir) }
  for dir in package.path:gmatch("[^;]+") do
    tPaths[#tPaths+1] = Lower(dir):gsub("/", "\\"):gsub("[^\\]+$", "")
  end

  local function repair(str)
    local Lstr = Lower(str):gsub("/", "\\")
    for _, dir in ipairs(tPaths) do
      local part1, part2 = Lstr, ""
      while true do
        local p1, p2 = part1:match("(.*[\\/])(.+)")
        if not p1 then break end
        part1, part2 = p1, p2..part2
        if part1 == dir:sub(-part1:len()) then
          return dir .. str:sub(-part2:len())
        end
      end
    end
  end

  local jumps, buttons = {}, "&OK"
  msg = tostring(msg):gsub("[^\n]+",
    function(line)
      line = line:gsub("^\t", ""):gsub("(.-)%:(%d+)%:(%s*)",
        function(file, numline, space)
          if #jumps < 9 then
            local file2 = file:sub(1,3) ~= "..." and file or repair(file:sub(4))
            if file2 then
              local name = file2:match('^%[string "(.*)"%]$')
              if not name or name=="all text" or name=="selection" then
                jumps[#jumps+1] = { file=file2, line=tonumber(numline) }
                buttons = buttons .. ";[J&" .. (#jumps) .. "]"
                return ("\16[J%d]:%s:%s:%s"):format(#jumps, file, numline, space)
              end
            end
          end
          return "[?]:" .. file .. ":" .. numline .. ":" .. space
        end)
      return line
    end)
  collectgarbage "collect"
  local caption = ("Error [used: %d Kb]"):format(collectgarbage "count")
  local ret = far.Message(msg, caption, buttons, "wl")
  if ret <= 0 then return end

  local file, line = jumps[ret].file, jumps[ret].line
  local luaScript = file=='[string "all text"]' or file=='[string "selection"]'
  if not luaScript then
    local trgInfo
    for i=1,far.AdvControl("ACTL_GETWINDOWCOUNT") do
      local wInfo = far.AdvControl("ACTL_GETWINDOWINFO", i-1)
      if wInfo.Type==F.WTYPE_EDITOR and
        Lower(wInfo.Name:gsub("/","\\")) == Lower(file:gsub("/","\\"))
      then
        trgInfo = wInfo
        if wInfo.Current then break end
      end
    end
    if trgInfo then
      if not trgInfo.Current then
        far.AdvControl("ACTL_SETCURRENTWINDOW", trgInfo.Pos)
        far.AdvControl("ACTL_COMMIT")
      end
    else
      far.Editor(file, nil,nil,nil,nil,nil, {EF_NONMODAL=1,EF_IMMEDIATERETURN=1})
    end
  end

  local eInfo = far.EditorGetInfo()
  if eInfo then
    if file == '[string "selection"]' then
      local startsel = eInfo.BlockType~=F.BTYPE_NONE and eInfo.BlockStartLine or 0
      line = line + startsel
    end
    local offs = math.floor(eInfo.WindowSizeY / 2)
    far.EditorSetPosition(line-1, 0, 0, line>offs and line-offs or 0)
    far.EditorRedraw()
  end
end

-- Add function unicode.utf8.cfind:
-- same as find, but offsets are in characters rather than bytes
-- DON'T REMOVE: it's documented in LF4Ed manual and must be available to user scripts.
local function AddCfindFunction()
  local usub, ssub = unicode.utf8.sub, string.sub
  local ulen, slen = unicode.utf8.len, string.len
  local ufind = unicode.utf8.find
  unicode.utf8.cfind = function(s, patt, init, plain)
    init = init and slen(usub(s, 1, init-1)) + 1
    local t = { ufind(s, patt, init, plain) }
    if t[1] == nil then return nil end
    return ulen(ssub(s, 1, t[1]-1)) + 1, ulen(ssub(s, 1, t[2])), unpack(t, 3)
  end
end

function Package.InitPlugin (workDir)
  _require, _loadfile, _io = require, loadfile, io
  require, loadfile, io = far.Require, far.LoadFile, uio
  package._loadlib, package.loadlib = package.loadlib, far.LoadLib
  getmetatable("").__index = unicode.utf8
  AddCfindFunction()

  far.OnError = OnError

  local plugin = {}
  plugin.ModuleDir = PluginDir
  plugin.WorkDir = assert(os.getenv("APPDATA")) .."\\".. workDir
  assert(far.CreateDir(plugin.WorkDir, true))
  plugin.History = history.new(plugin.WorkDir.."\\plugin.data")
  return plugin
end

return Package

