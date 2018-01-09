---- Debug lines ----
--far.ReloadDefaultScript = true
--package.loaded.macrosyn = nil
---- End debug lines ----

do
  local marker = "B723A193-0A88-4A15-AA2E-F204B5C828EB"
  if not package[marker] then
    package.path = far.PluginStartupInfo().ModuleDir.."?.lua;"..package.path
    package.cpath = far.PluginStartupInfo().ModuleDir.."?.dll;"..package.cpath
    package[marker] = true
  end
end

local F = far.Flags
local macrosyn = require "macrosyn"

local function ErrMsg (str, flags)
  local info = export.GetGlobalInfo()
  local ver = table.concat(info.Version, ".", 1, 2)
  local title = ("%s ver.%s"):format(info.Title, ver)
  far.Message(str, title, nil, flags or "w")
end

-- Split command line into separate arguments.
-- * An argument is either of:
--     a) a sequence of 0 or more characters enclosed within a pair of non-escaped
--        double quotes; can contain spaces; enclosing double quotes are stripped
--        from the argument.
--     b) a sequence of 1 or more non-space characters.
-- * Backslashes only escape double quotes.
-- * The function does not raise errors.
local function SplitCommandLine (str)
  local pat = [["((?:\\"|[^"])*)"|((?:\\"|\S)+)]]
  local out = {}
  for c1, c2 in regex.gmatch(str, pat) do
    out[#out+1] = regex.gsub(c1 or c2, [[\\(")|(.)]], "%1%2")
  end
  return out
end

local function ExpandPath (path)
  if not path:find("^[a-zA-Z]:") then
    local panelDir = panel.GetPanelDirectory(nil, 1).Name
    if path:find("^[\\/]") then
      path = panelDir:sub(1,2) .. path
    else
      path = panelDir:gsub("[^\\/]$", "%1\\") .. path
    end
  end
  return path
end

local PluginMenuGuid1 = win.Uuid("06b31136-ccb9-42e5-b52f-67014b94954a")

local PluginInfo = {
  CommandPrefix = "m2l",
  Flags = PF_DISABLEPANELS,
  -- Flags = F.PF_EDITOR,
  -- PluginMenuGuids = PluginMenuGuid1.."",
  -- PluginMenuStrings = { export.GetGlobalInfo().Title },
}

function export.GetPluginInfo()
  return PluginInfo
end

-- AVAILABLE OPERATIONS
-- "xml_file"
-- "xml_macros"
-- "xml_keymacros"
-- "xml_macro"

-- "fml_file"
-- "fml_macro"

-- "chunk"
-- "expression"
local function ConvertFile (srcfile, trgfile, syntax)
  local fp, err = io.open(srcfile)
  if not fp then ErrMsg(err) return end

  local text = fp:read("*all")
  fp:close()
  local Bom = "\239\187\191" -- UTF-8 BOM
  if string.sub(text,1,3)==Bom then text=string.sub(text,4)
  else Bom = ""
  end

  local text,msg = macrosyn.Convert(syntax,text)

  if not text and msg == "" then msg = "conversion failed" end
  if msg ~= "" then ErrMsg(srcfile.."\n"..msg, text and "l" or "lw") end
  if text then
    local fp, err = io.open(trgfile, "w")
    if not fp then ErrMsg(err) return end
    fp:write(Bom, text)
    fp:close()
  end
end

local function RunFile (file, ...)
  local func,msg = loadfile(file)
  if not func then ErrMsg(msg) return end
  local env = { Convert=macrosyn.Convert }
  setmetatable(env, {__index=_G})
  setfenv(func, env)(...)
end

local function ShowSyntax()
  ErrMsg([=[
M2L: convert <input file> <output file> [<syntax>]
M2L: run <script file> [<arguments>]]=], "l")
end

local function ProcessArgs (args)
  if #args==0 then ShowSyntax() return end
  local command = args[1]:lower()
  if command == "convert" then
    if #args<3 then ShowSyntax() return end
    local srcfile, trgfile = ExpandPath(args[2]), ExpandPath(args[3])
    local syntax = (args[4] or "xml_file"):lower()
    ConvertFile(srcfile, trgfile, syntax)
  elseif command == "run" then
    if #args<2 then ShowSyntax() return end
    RunFile(ExpandPath(args[2]), unpack(args,3))
  else
    ShowSyntax()
  end
end

function export.Open (OpenFrom, Guid, Item)
  local area = bit64.band(0xFF, OpenFrom)
  if area == F.OPEN_COMMANDLINE then
    ProcessArgs(SplitCommandLine(Item))
  elseif area == F.OPEN_PLUGINSMENU then
  elseif area == F.OPEN_EDITOR then
  elseif area == F.OPEN_FROMMACRO then
    if type(Item)=="table" then
      local syntax,input = Item[1],Item[2]
      if type(syntax)=="string" and type(input)=="string" then
        return macrosyn.Convert(syntax, input)
      end
    end
  end
end

function export.ConvertChunk (strInput)
  local strOutput,msg = macrosyn.Convert("chunk", strInput or "")
  return strOutput
end

--local function Convert (op, subj)
--  local func = op:find("^xml_") and GetXMLPattern or GetMacroPattern
--  local converter = Cs(P(func(op)))
--  local t_log = {}
--  local ok, str = pcall(lpeg.match, converter, subj, 1, subj, t_log)
--  return ok and str, table.concat(t_log, "\n")
--end
