-- utils.lua --

local F = far.Flags
local band, bor = bit64.band, bit64.bor
local PluginDir = far.PluginStartupInfo().ModuleDir

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

  local jumps, j, buttons = {}, 0, "&OK"
  msg = tostring(msg):gsub("[^\n]+",
    function(line)
      line = line:gsub("^\t", ""):gsub("(.-)%:(%d+)%:(%s*)",
        function(file, numline, space)
          if j < 10 then
            local file2 = file:sub(1,3) ~= "..." and file or repair(file:sub(4))
            if file2 then
              local name = file2:match('^%[string "(.*)"%]$')
              if not name or name=="all text" or name=="selection" then
                j = j + 1
                jumps[j] = { file=file2, line=tonumber(numline) }
                buttons = buttons .. (j<10 and ";&" or ";") .. j
                return ("\16[J%d]:%s:%s:\n"):format(j, file, numline)
              end
            end
          end
          return "[?]:" .. file .. ":" .. numline .. ":" .. space
        end)
      return line
    end)
  collectgarbage "collect"
  local caption = ("Error [used: %d KB]"):format(collectgarbage "count")
  local ret = far.Message(msg, caption, buttons, "wl")
  if ret <= 1 then return end

  local file, line = jumps[ret-1].file, jumps[ret-1].line
  local luaScript = file=='[string "all text"]' or file=='[string "selection"]'
  if not luaScript then
    local trgInfo
    for i=1,far.AdvControl("ACTL_GETWINDOWCOUNT") do
      local wInfo = far.AdvControl("ACTL_GETWINDOWINFO", i)
      if wInfo.Type==F.WTYPE_EDITOR and
        Lower(wInfo.Name:gsub("/","\\")) == Lower(file:gsub("/","\\"))
      then
        trgInfo = wInfo
        if 0 ~= band(wInfo.Flags, F.WIF_CURRENT) then break end
      end
    end
    if trgInfo then
      if 0 == band(trgInfo.Flags, F.WIF_CURRENT) then
        far.AdvControl("ACTL_SETCURRENTWINDOW", trgInfo.Pos)
        far.AdvControl("ACTL_COMMIT")
      end
    else
      editor.Editor(file, nil,nil,nil,nil,nil, {EF_NONMODAL=1,EF_IMMEDIATERETURN=1},line)
    end
  end

  local eInfo = editor.GetInfo()
  if eInfo then
    if file == '[string "selection"]' then
      local startsel = eInfo.BlockType~=F.BTYPE_NONE and eInfo.BlockStartLine-1 or 0
      line = line + startsel
    end
    local offs = math.floor(eInfo.WindowSizeY / 2)
    editor.SetPosition(nil, line, 0, 0, line>offs and line-offs or 1)
    editor.Redraw()
  end
end

local function LoadEmbeddedScript (name)
  local embed_name = "<"..name
  local loader = package.preload[embed_name]
  return loader and loader(embed_name)
end

local function RunInternalScript (name, ...)
  local f = LoadEmbeddedScript(name)
  if f then return f(...) end
  local f2, errmsg = loadfile(PluginDir..name..".lua")
  if f2 then return f2(...) end
  error(errmsg)
end

local function LoadName (str)
  local f = LoadEmbeddedScript(str)
  if f then return f end
  str = str:gsub("[./]", "\\")
  for part in package.path:gmatch("[^;]+") do
    local name = part:gsub("%?", str)
    local attr = win.GetFileAttr(name)
    if attr and not attr:find("d") then
      return assert(loadfile(name))
    end
  end
  error(str..": file not found")
end

-- @aItem.filename:  script file name
-- @aItem.env:       environment to run the script in
-- @aItem.arg:       array of arguments associated with aItem
--
-- @aProperties:     table with property-like arguments, e.g.: "From", "hDlg"
--
-- ...:              sequence of additional arguments (appended to existing arguments)
--
local function RunUserItem (aItem, aProperties, ...)
  assert(aItem.filename, "no file name")
  assert(aItem.env, "no environment")

  -- Get the chunk. If it is not given directly then find and compile the file.
  local chunk = type(aItem.filename)=="function" and aItem.filename or LoadName(aItem.filename)

  -- Set environment. Use pcall since if chunk is not a Lua function an error is thrown.
  pcall(setfenv, chunk, aItem.env)

  -- Copy "fixed" and append "variable" arguments, then run the chunk.
  if aItem.unpack then
    local args = { unpack(aItem.arg, 1, aItem.arg.n) }
    local n2 = select("#", ...)
    for k=1,n2 do args[aItem.arg.n + k] = select(k, ...); end
    return chunk(unpack(args, 1, aItem.arg.n + n2))
  else
    local args = {}
    for k,v in pairs(aProperties) do args[k] = v end
    for i,v in ipairs(aItem.arg)  do args[i] = v end
    local n, n2 = #args, select("#", ...)
    args.n = n + n2
    for i=1,n2 do args[n+i] = select(i, ...) end
    return chunk(args)
  end
end

local function ConvertUserHotkey(str)
  local d = 0
  for elem in str:upper():gmatch("[^+%-]+") do
    if elem == "ALT" then d = bor(d, 0x01)
    elseif elem == "CTRL" then d = bor(d, 0x02)
    elseif elem == "SHIFT" then d = bor(d, 0x04)
    else d = d .. "+" .. elem; break
    end
  end
  return d
end

local function MakeAddToMenu (Items, Env, HotKeyTable, Unpack)
  local function AddToMenu (aWhere, aItemText, aHotKey, aFileName, ...)
    if type(aWhere) ~= "string" then return end
    aWhere = aWhere:lower()
    if not aWhere:find("[evpdc]") then return end
    ---------------------------------------------------------------------------
    local SepText = type(aItemText)=="string" and aItemText:match("^:sep:(.*)")
    local bUserItem = SepText or type(aFileName)=="string" or type(aFileName)=="function"
    if not bUserItem then
      if aItemText~=true or type(aFileName)~="number" then
        return
      end
    end
    ---------------------------------------------------------------------------
    if HotKeyTable and not SepText and aWhere:find("[ec]") and type(aHotKey)=="string" then
      local key = ConvertUserHotkey (aHotKey)
      if HotKeyTable[key] then
        far.Message(("Key `%s' is already allocated"):format(aHotKey),"AddToMenu",nil,"w")
      elseif bUserItem then
        local n = select("#", ...)
        HotKeyTable[key] = {filename=aFileName, env=Env, arg={n=n, ...}, unpack=Unpack}
      else
        HotKeyTable[key] = aFileName -- menu position of a built-in utility
      end
    end
    ---------------------------------------------------------------------------
    if bUserItem and aItemText then
      local item
      if SepText then
        item = { text=SepText, separator=true }
      else
        local n = select("#", ...)
        item = { text=tostring(aItemText), filename=aFileName, env=Env, arg={n=n, ...}, unpack=Unpack }
      end
      if aWhere:find"c" then table.insert(Items.config, item) end
      if aWhere:find"d" then table.insert(Items.dialog, item) end
      if aWhere:find"e" then table.insert(Items.editor, item) end
      if aWhere:find"p" then table.insert(Items.panels, item) end
      if aWhere:find"v" then table.insert(Items.viewer, item) end
    end
  end
  return AddToMenu
end

local function MakeAddCommand (CommandTable, Env, Unpack)
  return function (aCommand, aFileName, ...)
    local fntype = type(aFileName)
    if type(aCommand)=="string" and (fntype=="string" or fntype=="function") then
      local n = select("#", ...)
      CommandTable[aCommand] = { filename=aFileName, env=Env, arg={n=n, ...}, unpack=Unpack }
    end
  end
end

local function MakeAutoInstall (AddUserFile)
  local function AutoInstall (startpath, filepattern, depth)
    assert(type(startpath)=="string", "bad arg. #1 to AutoInstall")
    assert(filepattern==nil or type(filepattern)=="string", "bad arg. #2 to AutoInstall")
    assert(depth==nil or type(depth)=="number", "bad arg. #3 to AutoInstall")
    ---------------------------------------------------------------------------
    startpath = PluginDir .. startpath:gsub("[\\/]*$", "\\", 1)
    filepattern = filepattern or "^_usermenu%.lua$"
    ---------------------------------------------------------------------------
    local first = depth
    local offset = PluginDir:len() + 1

    local DirList = {}
    far.RecursiveSearch(startpath, "*",
      function(item, fullname) item.FileName=fullname; DirList[#DirList+1]=item end,
      bor(F.FRS_RECUR,F.FRS_SCANSYMLINK))

    for _, item in ipairs(DirList) do
      if first then
        first = false
        local _, m = item.FileName:gsub("\\", "")
        depth = depth + m
      end
      if not item.FileAttributes:find"d" then
        local try = true
        if depth then
          local _, n = item.FileName:gsub("\\", "")
          try = (n <= depth)
        end
        if try then
          local relName = item.FileName:sub(offset)
          local Name = relName:match("[^\\/]+$")
          if Name:match(filepattern) then AddUserFile(relName) end
        end
      end
    end
  end
  return AutoInstall
end

local function LoadUserMenu (aFileName)
  local userItems = { editor={},viewer={},panels={},config={},dialog={} }
  local commandTable, hotKeyTable = {}, {}
  local handlers = { EditorInput={}, EditorEvent={}, ViewerEvent={}, ExitScript={} }
  local mapHandlers = {
    ProcessEditorInput = handlers.EditorInput,
    ProcessEditorEvent = handlers.EditorEvent,
    ProcessViewerEvent = handlers.ViewerEvent,
    ExitScript         = handlers.ExitScript,
  }
  local uStack, uDepth, uMeta = {}, 0, {__index = _G}
  local env = setmetatable({}, {__index=_G})
  ------------------------------------------------------------------------------
  env.MakeResident = function (source)
    if type(source) == "string" then
      local chunk = LoadName(source)
      local env2 = setmetatable({}, { __index=_G })
      local ok, errmsg = pcall(setfenv(chunk, env2))
      if not ok then error(errmsg, 2) end
      for name, target in pairs(mapHandlers) do
        local f = rawget(env2, name)
        if type(f)=="function" then table.insert(target, f) end
      end
    end
  end
  ------------------------------------------------------------------------------
  env.AddUserFile = function (filename)
    uDepth = uDepth + 1
    filename = PluginDir .. filename
    if uDepth == 1 then
      -- if top-level _usermenu.lua doesn't exist, it isn't error
      local attr = win.GetFileAttr(filename)
      if not attr or attr:find("d") then return end
    end
    local chunk = assert(loadfile(filename))
    uStack[uDepth] = setmetatable({}, uMeta)
    env.AddToMenu    = MakeAddToMenu(userItems, uStack[uDepth], hotKeyTable, false)
    env.AddToMenuEx  = MakeAddToMenu(userItems, uStack[uDepth], hotKeyTable, true)
    env.AddCommand   = MakeAddCommand(commandTable, uStack[uDepth], false)
    env.AddCommandEx = MakeAddCommand(commandTable, uStack[uDepth], true)
    setfenv(chunk, env)()
    uDepth = uDepth - 1
  end
  ------------------------------------------------------------------------------
  env.AutoInstall = MakeAutoInstall(env.AddUserFile)
  env.AddUserFile(aFileName)
  return userItems, commandTable, hotKeyTable, handlers
end

local function AddMenuItems (trg, src, msgtable)
  trg = trg or {}
  for _, item in ipairs(src) do
    local text = item.text
    if type(text)=="string" and text:sub(1,2)=="::" then
      local newitem = {}
      for k,v in pairs(item) do newitem[k] = v end
      newitem.text = msgtable[text:sub(3)]
      trg[#trg+1] = newitem
    else
      trg[#trg+1] = item
    end
  end
  return trg
end

local function CommandSyntaxMessage (tCommands)
  local globalInfo = export.GetGlobalInfo()
  local pluginInfo = export.GetPluginInfo()
  local syn = [[
Command line syntax:
  %s: [<options>] <command>|-r<filename> [<arguments>]

Options:
  -a          asynchronous execution
  -e <str>    execute string <str>
  -l <lib>    load library <lib>

Macro call syntax:
  (guid = "%s")
  Plugin.Call(guid, "code",    <code>     [,<arguments>])
  Plugin.Call(guid, "file",    <filename> [,<arguments>])
  Plugin.Call(guid, "command", <command>  [,<arguments>])
  Plugin.Call(guid, "own",     <command>  [,<arguments>])

Available commands:
]]

  syn = syn:format(pluginInfo.CommandPrefix, win.Uuid(globalInfo.Guid))
  if next(tCommands) then
    local arr = {}
    for k in pairs(tCommands) do arr[#arr+1] = k end
    table.sort(arr)
    syn = syn .. "  " .. table.concat(arr, ", ")
  else
    syn = syn .. "  <no commands available>"
  end
  far.Message(syn, globalInfo.Title, ";Ok", "l")
end

-- Split command line into separate arguments.
-- * An argument is any sequence of (a) and (b):
--     a) a sequence of 0 or more characters enclosed within a pair of non-escaped
--        double quotes; can contain spaces; enclosing double quotes are stripped
--        from the argument.
--     b) a sequence of 1 or more non-space characters.
-- * Backslashes only escape double quotes.
-- * The function does not raise errors.
local function SplitCommandLine (str)
  local quoted   = [[" (?: \\" | [^"]   )* "? ]]
  local unquoted = [[  (?: \\" | [^"\s] )+    ]]
  local pat = ("(?: %s|%s )+"):format(quoted, unquoted)
  local out = {}
  local rep = { ['\\"']='"', ['"']='' }
  for arg in regex.gmatch(str, pat, "x") do
    out[#out+1] = arg:gsub('(\\?")', rep)
  end
  return out
end

local function CompileCommandLine (sCommandLine, tCommands)
  local actions = {}
  local opt
  local args = SplitCommandLine(sCommandLine)
  for i,v in ipairs(args) do
    local curropt, param
    if opt then
      curropt, param, opt = opt, v, nil
    else
      if v:sub(1,1) == "-" then
        local newopt
        newopt, param = v:match("^%-([aelr])(.*)")
        if newopt == nil then
          error("invalid option: "..v)
        end
        if newopt == "a" then actions.async = true
        elseif param == "" then  opt = newopt
        else curropt = newopt
        end
      else
        if not tCommands[v] then
          error("invalid command: "..v)
        end
        actions[#actions+1] = { command=v, unpack(args, i+1) }
        break
      end
    end
    if curropt == "r" then
      actions[#actions+1] = { opt=curropt, param=param, unpack(args, i+1) }
      break
    elseif curropt then
      actions[#actions+1] = { opt=curropt, param=param }
    end
  end
  return actions
end

local function ExecuteCommandLine (tActions, tCommands, sFrom, fConfig)
  local function wrapfunc()
    local env = setmetatable({}, {__index=_G})
    for _,v in ipairs(tActions) do
      if v.command then
        local fileobject = tCommands[v.command]
        RunUserItem(fileobject, {From=sFrom}, unpack(v))
        break
      elseif v.opt == "r" then
        local path = v.param
        if not path:find("^[a-zA-Z]:") then
          local panelDir = panel.GetPanelDirectory(nil, 1).Name
          if path:find("^[\\/]") then
            path = panelDir:sub(1,2) .. path
          else
            path = panelDir:gsub("[^\\/]$", "%1\\") .. path
          end
        end
        local f = assert(loadfile(path))
        setfenv(f, env)(unpack(v))
      elseif v.opt == "e" then
        local f = assert(loadstring(v.param))
        setfenv(f, env)()
      elseif v.opt == "l" then
        require(v.param)
      end
    end
  end
  local oldConfig = fConfig and fConfig()
  local ok, res = xpcall(wrapfunc, function(msg) return debug.traceback(msg, 2) end)
  if fConfig then fConfig(oldConfig) end
  if not ok then export.OnError(res) end
end

local function OpenCommandLine (sCommandLine, tCommands, fConfig)
  local tActions = CompileCommandLine(sCommandLine, tCommands)
  if not tActions[1] then
    CommandSyntaxMessage(tCommands)
  elseif tActions.async then
    ---- autocomplete:good; Escape response:bad when timer period < 20;
    far.Timer(30,
      function(h)
        h:Close(); ExecuteCommandLine(tActions, tCommands, "panels", fConfig)
      end)
  else
    ---- autocomplete:bad; Escape responsiveness:good;
    ExecuteCommandLine(tActions, tCommands, "panels", fConfig)
  end
end

local function OpenMacro (Args, CommandTable, fConfig)
  local op = Args[1]
  if op=="command" then
    if type(Args[2]) == "string" then
      local fileobject = CommandTable[Args[2]]
      if fileobject then
        local oldConfig = fConfig and fConfig()
        local map = {
          [F.MACROAREA_SHELL]  = "panels", [F.MACROAREA_EDITOR] = "editor",
          [F.MACROAREA_VIEWER] = "viewer", [F.MACROAREA_DIALOG] = "dialog",
        }
        local wrapfunc = function()
          return RunUserItem(fileobject, { From=map[far.MacroGetArea()] }, unpack(Args,3,Args.n))
        end
        local retfunc = function (ok, ...)
          if fConfig then fConfig(oldConfig) end
          if ok then return ... end
          export.OnError(...)
          return true
        end
        return retfunc(xpcall(wrapfunc, function(msg) return debug.traceback(msg, 3) end))
      else
        CommandSyntaxMessage(CommandTable)
      end
    end
  elseif op=="code" or op=="file" then
    if type(Args[2]) == "string" then
      local chunk = op=="file" and assert(loadfile((Args[2]:gsub("%%(.-)%%",win.GetEnv))))
                                or assert(loadstring(Args[2]))
      local env = setmetatable({}, { __index=_G })
      setfenv(chunk, env)
      return chunk(unpack(Args,3,Args.n))
    end
  end
  return false
end

-- Add function unicode.utf8.cfind:
-- same as find, but offsets are in characters rather than bytes
-- DON'T REMOVE: it's documented in LF4Ed manual and must be available to user scripts.
local function AddCfindFunction()
  local ulib = getmetatable("").__index
  if type(ulib) == "table" then
    local usub, ssub = ulib.sub, string.sub
    local ulen, slen = ulib.len, string.len
    local ufind = ulib.find
    ulib.cfind = function(s, patt, init, plain)
      init = init and slen(usub(s, 1, init-1)) + 1
      local t = { ufind(s, patt, init, plain) }
      if t[1] == nil then return nil end
      return ulen(ssub(s, 1, t[1]-1)) + 1, ulen(ssub(s, 1, t[2])), unpack(t, 3)
    end
  end
end

local function InitPlugin()
  AddCfindFunction()
  export.OnError = OnError
  local plugin = {}
  plugin.ModuleDir = PluginDir
  return plugin
end

local function GetPluginVersion()
  return table.concat(export.GetGlobalInfo().Version, ".")
end

return {
  AddCfindFunction = AddCfindFunction,
  OnError = OnError,
  AddMenuItems = AddMenuItems,
  GetPluginVersion = GetPluginVersion,
  InitPlugin = InitPlugin,
  LoadUserMenu = LoadUserMenu,
  OpenMacro = OpenMacro,
  OpenCommandLine = OpenCommandLine,
  RunInternalScript = RunInternalScript,
  RunUserItem = RunUserItem,
}
