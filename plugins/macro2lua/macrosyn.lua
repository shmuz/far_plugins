-- encoding: UTF-8

-- Macro Parser
-- by Shmuel Zeigerman

-- Allow running this module without Far Manager
-- (any free hanging C-style identifier will be accepted as a key then).
if not far then
  far = { NameToInputRecord=function() return true end }
end

local lpeg = require "lpeg"

local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C, Cc, Cs, Cmt, Cf, Cp, Carg =
  lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Cmt, lpeg.Cf, lpeg.Cp, lpeg.Carg

local digit = R"09"
local alpha = R("az","AZ")
local alnum = R("az","AZ","09")
local ident = (alpha + "_") * (alnum + "_")^0
local macroident = ident * (P"." * ident)^0


local space  = (S" \t\r\n")^0
local rspace = (S" \t\r\n")^1 -- "real space"
local hexnum = (P "-")^-1 * space * P"0" * S"xX" * R("09","af","AF")^1
local octnum = (P "-")^-1 * space * P"0" * R("07")^0 / function(c) return tonumber(c,8) end
local decnum = (P "-")^-1 * space * R("19") * R("09")^0

local Number = hexnum +
               octnum * -S(".eE") +
               (digit^1 * P(".")^-1 * digit^0  + "." * digit^1) * (S"eE" * P("-")^-1 * digit^1)^-1
Number = Number * -(alnum + "_")

local String = P'@'/'' * P'"' * (P'\\'/'\\\\' + P'""'/'\\"' + (1 - S('"\r\n')))^0 * P'"' + -- "verbatim" string
               P'"' * (P"\\" * P(1) + (1 - S'"\r\n'))^0 * P'"'

-- FML strings are currently not converted to Lua strings; this work is left to MacroLib plugin.
local FmlString = P'@"' * (P'""' + (1 - S('"\r\n')))^0 * P'"' + -- "verbatim" string
                  P"@'" * (P"''" + (1 - S("'\r\n")))^0 * P"'" + -- 'verbatim' string
                  P'"' * (P"\\" * P(1) + P'""' + (1 - S('"\r\n')))^0 * P'"' +
                  P"'" * (P"\\" * P(1) + P"''" + (1 - S("'\r\n")))^0 * P"'"

local var = (P"%%" + P"%") * ident

local function K (k) -- keyword
  local pat = P""
  for c in string.gmatch(k,".") do pat = pat * S(c:lower()..c:upper()) end
  return pat * -(alnum + S "_.")
end

local rus_c = P("\209\129") + P("\208\161") -- in UTF-8
local comment = P"%" * (S"cC" + rus_c) * (K"omment" + K"oment")

local unop = P "-" +
             --P "~" +
             P "!" / " not ";

local kwords_functions = { -- 99 functions
  ["bm.add"]                = "BM.Add",
  ["bm.back"]               = "BM.Back",
  ["bm.clear"]              = "BM.Clear",
  ["bm.del"]                = "BM.Del",
  ["bm.get"]                = "BM.Get",
  ["bm.goto"]               = "BM.Goto",
  ["bm.next"]               = "BM.Next",
  ["bm.pop"]                = "BM.Pop",
  ["bm.prev"]               = "BM.Prev",
  ["bm.push"]               = "BM.Push",
  ["bm.stat"]               = "BM.Stat",
  ["dlg.getvalue"]          = "Dlg.GetValue",
  ["dlg.setfocus"]          = "Dlg.SetFocus",
  ["editor.delline"]        = "Editor.DelLine",
  ["editor.getstr"]         = "Editor.GetStr",
  ["editor.insstr"]         = "Editor.InsStr",
  ["editor.pos"]            = "Editor.Pos",
  ["editor.sel"]            = "Editor.Sel",
  ["editor.set"]            = "Editor.Set",
  ["editor.setstr"]         = "Editor.SetStr",
  ["editor.settitle"]       = "Editor.SetTitle",
  ["editor.undo"]           = "Editor.Undo",
  ["far.cfg.get"]           = "Far.Cfg_Get",
  ["history.disable"]       = "Far.DisableHistory",
  ["kbdlayout"]             = "Far.KbdLayout",
  ["keybar.show"]           = "Far.KeyBar_Show",
  ["window.scroll"]         = "Far.Window_Scroll",
  ["menu.filter"]           = "Menu.Filter",
  ["menu.filterstr"]        = "Menu.FilterStr",
  ["menu.getvalue"]         = "Menu.GetValue",
  ["menu.itemstatus"]       = "Menu.ItemStatus",
  ["menu.select"]           = "Menu.Select",
  ["menu.show"]             = "Menu.Show",
  ["checkhotkey"]           = "Object.CheckHotkey",
  ["gethotkey"]             = "Object.GetHotkey",
  ["panel.fattr"]           = "Panel.FAttr",
  ["panel.fexist"]          = "Panel.FExist",
  ["panel.item"]            = "Panel.Item",
  ["panel.select"]          = "Panel.Select",
  ["panel.setpath"]         = "Panel.SetPath",
  ["panel.setpos"]          = "Panel.SetPos",
  ["panel.setposidx"]       = "Panel.SetPosIdx",
  ["plugin.call"]           = "Plugin.Call",
  ["callplugin"]            = "Plugin.Call",
  ["plugin.command"]        = "Plugin.Command",
  ["plugin.config"]         = "Plugin.Config",
  ["plugin.exist"]          = "Plugin.Exist",
  ["plugin.load"]           = "Plugin.Load",
  ["plugin.menu"]           = "Plugin.Menu",
  ["plugin.unload"]         = "Plugin.Unload",
  ["akey"]                  = "akey",
  ["eval"]                  = "eval",
  ["abs"]                   = "mf.abs",
  ["asc"]                   = "mf.asc",
  ["atoi"]                  = "mf.atoi",
  ["beep"]                  = "mf.beep",
  ["chr"]                   = "mf.chr",
  ["clip"]                  = "mf.clip",
  ["date"]                  = "mf.date",
  ["env"]                   = "mf.env",
  ["fattr"]                 = "mf.fattr",
  ["fexist"]                = "mf.fexist",
  ["float"]                 = "mf.float",
  ["flock"]                 = "mf.flock",
  ["fmatch"]                = "mf.fmatch",
  ["fsplit"]                = "mf.fsplit",
  ["iif"]                   = "mf.iif",
  ["index"]                 = "mf.index",
  ["int"]                   = "mf.int",
  ["itoa"]                  = "mf.itoa",
  ["key"]                   = "mf.key",
  ["lcase"]                 = "mf.lcase",
  ["len"]                   = "mf.len",
  ["max"]                   = "mf.max",
  ["min"]                   = "mf.min",
  ["mload"]                 = "mf.mload",
  ["mod"]                   = "mf.mod",
  ["msave"]                 = "mf.msave",
  ["replace"]               = "mf.replace",
  ["rindex"]                = "mf.rindex",
  ["size2str"]              = "mf.size2str",
  ["sleep"]                 = "mf.sleep",
  ["string"]                = "mf.string",
  ["strpad"]                = "mf.strpad",
  ["strwrap"]               = "mf.strwrap",
  ["substr"]                = "mf.substr",
  ["testfolder"]            = "mf.testfolder",
  ["trim"]                  = "mf.trim",
  ["ucase"]                 = "mf.ucase",
  ["waitkey"]               = "mf.waitkey",
  ["xlat"]                  = "mf.xlat",
  ["mmode"]                 = "mmode",
  ["msgbox"]                = "msgbox",
  ["print"]                 = "print",
  ["prompt"]                = "prompt",
  ["macro.keyword"]         = false,
  ["macro.const"]           = false,
  ["macro.func"]            = false,
  ["macro.var"]             = false,
}

local kwords_properties = { -- 127 properties
  ["apanel.bof"]            = "APanel.Bof",
  ["apanel.columncount"]    = "APanel.ColumnCount",
  ["apanel.curpos"]         = "APanel.CurPos",
  ["apanel.current"]        = "APanel.Current",
  ["apanel.drivetype"]      = "APanel.DriveType",
  ["apanel.empty"]          = "APanel.Empty",
  ["apanel.eof"]            = "APanel.Eof",
  ["apanel.filepanel"]      = "APanel.FilePanel",
  ["apanel.filter"]         = "APanel.Filter",
  ["apanel.folder"]         = "APanel.Folder",
  ["apanel.format"]         = "APanel.Format",
  ["apanel.height"]         = "APanel.Height",
  ["apanel.hostfile"]       = "APanel.HostFile",
  ["apanel.itemcount"]      = "APanel.ItemCount",
  ["apanel.lfn"]            = "APanel.LFN",
  ["apanel.left"]           = "APanel.Left",
  ["apanel.opiflags"]       = "APanel.OPIFlags",
  ["apanel.path"]           = "APanel.Path",
  ["apanel.path0"]          = "APanel.Path0",
  ["apanel.plugin"]         = "APanel.Plugin",
  ["apanel.prefix"]         = "APanel.Prefix",
  ["apanel.root"]           = "APanel.Root",
  ["apanel.selcount"]       = "APanel.SelCount",
  ["apanel.selected"]       = "APanel.Selected",
  ["apanel.type"]           = "APanel.Type",
  ["apanel.uncpath"]        = "APanel.UNCPath",
  ["apanel.visible"]        = "APanel.Visible",
  ["apanel.width"]          = "APanel.Width",
  ["macro.area"]            = "Area.Current",
  ["dialog"]                = "Area.Dialog",
  ["dialog.autocompletion"] = "Area.DialogAutoCompletion",
  ["disks"]                 = "Area.Disks",
  ["editor"]                = "Area.Editor",
  ["findfolder"]            = "Area.FindFolder",
  ["help"]                  = "Area.Help",
  ["info"]                  = "Area.Info",
  ["mainmenu"]              = "Area.MainMenu",
  ["menu"]                  = "Area.Menu",
  ["other"]                 = "Area.Other",
  ["qview"]                 = "Area.QView",
  ["search"]                = "Area.Search",
  ["shell"]                 = "Area.Shell",
  ["shell.autocompletion"]  = "Area.ShellAutoCompletion",
  ["tree"]                  = "Area.Tree",
  ["usermenu"]              = "Area.UserMenu",
  ["viewer"]                = "Area.Viewer",
  ["cmdline.bof"]           = "CmdLine.Bof",
  ["cmdline.curpos"]        = "CmdLine.CurPos",
  ["cmdline.empty"]         = "CmdLine.Empty",
  ["cmdline.eof"]           = "CmdLine.Eof",
  ["cmdline.itemcount"]     = "CmdLine.ItemCount",
  ["cmdline.selected"]      = "CmdLine.Selected",
  ["cmdline.value"]         = "CmdLine.Value",
  ["dlg.curpos"]            = "Dlg.CurPos",
  ["dlg.info.id"]           = "Dlg.Id",
  ["dlg.itemcount"]         = "Dlg.ItemCount",
  ["dlg.itemtype"]          = "Dlg.ItemType",
  ["dlg.info.owner"]        = "Dlg.Owner",
  ["dlg.prevpos"]           = "Dlg.PrevPos",
  ["drv.showmode"]          = "Drv.ShowMode",
  ["drv.showpos"]           = "Drv.ShowPos",
  ["editor.curline"]        = "Editor.CurLine",
  ["editor.curpos"]         = "Editor.CurPos",
  ["editor.filename"]       = "Editor.FileName",
  ["editor.lines"]          = "Editor.Lines",
  ["editor.realpos"]        = "Editor.RealPos",
  ["editor.selvalue"]       = "Editor.SelValue",
  ["editor.state"]          = "Editor.State",
  ["editor.value"]          = "Editor.Value",
  ["fullscreen"]            = "Far.FullScreen",
  ["far.height"]            = "Far.Height",
  ["isuseradmin"]           = "Far.IsUserAdmin",
  ["far.pid"]               = "Far.PID",
  ["far.title"]             = "Far.Title",
  ["far.uptime"]            = "Far.UpTime",
  ["far.width"]             = "Far.Width",
  ["help.filename"]         = "Help.FileName",
  ["help.seltopic"]         = "Help.SelTopic",
  ["help.topic"]            = "Help.Topic",
  ["menu.info.id"]          = "Menu.Id",
  ["menu.value"]            = "Menu.Value",
  ["msbutton"]              = "Mouse.Button",
  ["msctrlstate"]           = "Mouse.CtrlState",
  ["mseventflags"]          = "Mouse.EventFlags",
  ["msx"]                   = "Mouse.X",
  ["msy"]                   = "Mouse.Y",
  ["bof"]                   = "Object.Bof",
  ["curpos"]                = "Object.CurPos",
  ["empty"]                 = "Object.Empty",
  ["eof"]                   = "Object.Eof",
  ["height"]                = "Object.Height",
  ["itemcount"]             = "Object.ItemCount",
  ["rootfolder"]            = "Object.RootFolder",
  ["selected"]              = "Object.Selected",
  ["title"]                 = "Object.Title",
  ["width"]                 = "Object.Width",
  ["ppanel.bof"]            = "PPanel.Bof",
  ["ppanel.columncount"]    = "PPanel.ColumnCount",
  ["ppanel.curpos"]         = "PPanel.CurPos",
  ["ppanel.current"]        = "PPanel.Current",
  ["ppanel.drivetype"]      = "PPanel.DriveType",
  ["ppanel.empty"]          = "PPanel.Empty",
  ["ppanel.eof"]            = "PPanel.Eof",
  ["ppanel.filepanel"]      = "PPanel.FilePanel",
  ["ppanel.filter"]         = "PPanel.Filter",
  ["ppanel.folder"]         = "PPanel.Folder",
  ["ppanel.format"]         = "PPanel.Format",
  ["ppanel.height"]         = "PPanel.Height",
  ["ppanel.hostfile"]       = "PPanel.HostFile",
  ["ppanel.itemcount"]      = "PPanel.ItemCount",
  ["ppanel.lfn"]            = "PPanel.LFN",
  ["ppanel.left"]           = "PPanel.Left",
  ["ppanel.opiflags"]       = "PPanel.OPIFlags",
  ["ppanel.path"]           = "PPanel.Path",
  ["ppanel.path0"]          = "PPanel.Path0",
  ["ppanel.plugin"]         = "PPanel.Plugin",
  ["ppanel.prefix"]         = "PPanel.Prefix",
  ["ppanel.root"]           = "PPanel.Root",
  ["ppanel.selcount"]       = "PPanel.SelCount",
  ["ppanel.selected"]       = "PPanel.Selected",
  ["ppanel.type"]           = "PPanel.Type",
  ["ppanel.uncpath"]        = "PPanel.UNCPath",
  ["ppanel.visible"]        = "PPanel.Visible",
  ["ppanel.width"]          = "PPanel.Width",
  ["viewer.filename"]       = "Viewer.FileName",
  ["viewer.state"]          = "Viewer.State",
  ["far.cfg.err"]           = false,
}

local function patt_from_table (tb)
  local patt = P(false)
  for k in pairs(tb) do patt = patt + K(k) end
  return patt
end

local function rep_prop (c) return kwords_properties[c:lower()] end

local function far_NameToInputRecord(str) return true end

local key1 = P(1) - S" \t\r\n"
local key = Cmt(C(ident * key1^-1 + key1) * #(S" \t\r\n" + -P(1)),
              function(subj,i,str) return far.NameToInputRecord(str) and true end)
local keys = (key * (S(" \t")^1 * key)^0) / 'Keys("%0")'

local reserved = {
  -- 1. Lua keywords
  ["and"]=true,
  ["break"]=true,
  ["do"]=true,
  ["else"]=true,
  ["elseif"]=true,
  ["end"]=true,
  ["false"]=true,
  ["for"]=true,
  ["function"]=true,
  ["if"]=true,
  ["in"]=true,
  ["local"]=true,
  ["nil"]=true,
  ["not"]=true,
  ["or"]=true,
  ["repeat"]=true,
  ["return"]=true,
  ["then"]=true,
  ["true"]=true,
  ["until"]=true,
  ["while"]=true,

  -- 2. Lua globals
  ["_g"]=true,
  ["_version"]=true,
  ["arg"]=true,
  ["assert"]=true,
  ["collectgarbage"]=true,
  ["coroutine"]=true,
  ["debug"]=true,
  ["dofile"]=true,
  ["error"]=true,
  ["gcinfo"]=true,
  ["getfenv"]=true,
  ["getmetatable"]=true,
  ["io"]=true,
  ["ipairs"]=true,
  ["load"]=true,
  ["loadfile"]=true,
  ["loadstring"]=true,
  ["math"]=true,
  ["module"]=true,
  ["newproxy"]=true,
  ["next"]=true,
  ["os"]=true,
  ["package"]=true,
  ["pairs"]=true,
  ["pcall"]=true,
  ["print"]=true,
  ["rawequal"]=true,
  ["rawget"]=true,
  ["rawset"]=true,
  ["require"]=true,
  ["select"]=true,
  ["setfenv"]=true,
  ["setmetatable"]=true,
  ["string"]=true,
  ["table"]=true,
  ["tonumber"]=true,
  ["tostring"]=true,
  ["type"]=true,
  ["unpack"]=true,
  ["xpcall"]=true,

  -- 3. LuaFAR globals
  ["bit64"]=true,
  ["far"]=true,
  ["editor"]=true,
  ["export"]=true,
  ["panel"]=true,
  ["regex"]=true,
  ["unicode"]=true,
  ["viewer"]=true,
  ["win"]=true,

  -- 4. LuaJIT globals
  ["bit"]=true,
  ["ffi"]=true,
  ["jit"]=true,

  -- 5. Macro API global functions
  ["akey"]=true,
  ["band"]=true,
  ["bnot"]=true,
  ["bor"]=true,
  ["bxor"]=true,
  ["lshift"]=true,
  ["rshift"]=true,
  ["eval"]=true,
  ["exit"]=true,
  ["keys"]=true,
  ["mmode"]=true,
  ["msgbox"]=true,
  ["print"]=true,
  ["printf"]=true,
  ["prompt"]=true,

  -- 6. Macro API global tables
  ["mf"]=true,
  ["area"]=true,
  ["apanel"]=true,
  ["ppanel"]=true,
  ["panel"]=true,
  ["bm"]=true,
  ["cmdline"]=true,
  ["dlg"]=true,
  ["drv"]=true,
  ["editor"]=true,
  ["far"]=true,
  ["help"]=true,
  ["menu"]=true,
  ["mouse"]=true,
  ["object"]=true,
  ["plugin"]=true,
  ["viewer"]=true,
}

local function make_f_var()
  local local_vars, global_vars = {}, {}
  return function (name, prefix)
    if prefix == "#%" then
      -- Definition of FML constants.
      local tb = local_vars
      local key = prefix..name:lower()
      if not tb[key] then tb[key] = prefix..name end -- cache it
      return name
    else
      -- 1. Definition and use of variables.
      -- 2. Use of FML constants.
      local tb
      if name:sub(1,2)=="%%" then
        tb, name = global_vars, name:sub(3)
      elseif name:sub(1,1)=="%" then
        tb, name = local_vars, name:sub(2)
      else
        tb = local_vars
      end
      local key = name:lower()
      if not tb[key] then
        local newname = reserved[key] and name.."__RENAMED" or name
        newname = (tb==global_vars) and "_G."..newname or newname
        tb[key] = newname -- cache it
      end
      return tb[key]
    end
  end
end

local function ProcessPos (subj, pos)
  local linenum = 1
  local prevstart = 1
  for linestart in string.gmatch(subj, "()[^\r\n]*\r?\n?") do
    if pos < linestart then
      break
    end
    linenum = linenum+1
    prevstart = linestart
  end
  return linenum-1, pos-prevstart+1
end

local function f_errmsg (subj,pos,msg,t_msg,kind)
  local line,pos = ProcessPos(subj,pos)
  msg = ("Error:%d:%d: %s"):format(line, pos, msg)
  table.insert(t_msg, msg)
  if kind == "error" then
    error(msg)
  end
  return true
end

local function PErr (msg)
  return Cmt(Cc(msg) * Carg(2) * Cc"error", f_errmsg)
end

local function PWarn (msg)
  return Cmt(Cc(msg) * Carg(2) * Cc"warning", f_errmsg)
end

local
  Funcname,Propname,Const,Chunk,Block,Lblock,Whilestat,
  Repstat,Ifstat,Lifstat,Stat0,Stat,Lstat,Term,Exp,
  P1,P2,P3,P4,P5,P6,Functioncall,Explist,Args,
  XML_cdata,XML_text,XML_macro,XML_keymacros,XML_macros,
  XML_file,FML_macro,FML_file
  =
  V"Funcname",V"Propname",V"Const",V"Chunk",V"Block",V"Lblock",V"Whilestat",
  V"Repstat",V"Ifstat",V"Lifstat",V"Stat0",V"Stat",V"Lstat",V"Term",V"Exp",
  V"P1",V"P2",V"P3",V"P4",V"P5",V"P6",V"Functioncall",V"Explist",V"Args",
  V"XML_cdata",V"XML_text",V"XML_macro",V"XML_keymacros",V"XML_macros",
  V"XML_file",V"FML_macro",V"FML_file"

local function GetMacroPattern (op)
  -- Fields starting with 'L' stand for "Loop fields", e.g.:
  -- Lifstat is a statement containing an Lblock

  local f_var = make_f_var()

  local space, rspace, String = space, rspace, String
  local FmlConstStat = P(false)
  local FmlConst = P(false)
  local FmlAkey = P(false)
  local FmlIncludeExt = P(false)
  local FmlIncludeInt = P(false)

  if op:find("^fml_") then
    local sp = S" \t\n" +
               (P";;"+"//")/"--" * (P(1)-"\n")^0 * (P"\n" + -P(1)) +
               (P"/*"/"--[=[") * (P(1) - "*/")^0 * ((P"*/"/"]=]") + -P(1))
    space, rspace = sp^0, sp^1
    String = FmlString
    FmlConstStat = K"const" * space * (C(ident) * Cc"#%" / f_var) *
                   space * "=" * space * (Number + String)
    FmlConst = (P"#%" * ident) / f_var
    FmlAkey = P"#" * K"akey"
    FmlIncludeExt = K"include" * space * String
    FmlIncludeInt = P"#" * K"include" * space * String
  end

  local tbPatt = {
    [1] = space * (
            op=="expression" and Exp or
            op=="chunk"      and Chunk or
            op=="fml_macro"  and FML_macro or
            op=="fml_file"   and FML_file) *
            space * -P(1);

    Funcname = patt_from_table(kwords_functions);

    Propname = patt_from_table(kwords_properties);

    Const = ident - Funcname - Propname;

    -- Macro Complete Syntax

    FML_macro = (K"farmacro" + K"macro") * space *
                (ident * space * "=" * space * (Number + String) * space)^0 *
                P"{{" * space * Chunk * space * "}}";

    FML_file = space * ((FmlConstStat + FmlIncludeExt + FML_macro) * space)^0;

    Chunk = (space * Stat * (space * P ";")^-1)^0;

    Block = Chunk;

    Lblock = (space * Lstat * (space * P ";")^-1)^0;

    Whilestat = (K"$WHILE"/"while") * space * (P"("/" ") * space * Exp * space * (P")"/" do ") *
                  space * Lblock * space * (K"$END"/"end");

    Repstat = (K"$REP")/"for RCounter=" * space * (P"("/"") * space * Exp * space * (P")"/",1,-1 do ") *
                space * Lblock * space * (K"$END"/"end");

    Ifstat = (K"$IF"/"if") * space * (P"("/" ") * space * Exp * space * (P")"/" then ") * space *
             Block * space *
             ((K"$ELSE"/"else") * space * Block * space)^-1 * (K"$END"/"end");

    Lifstat = (K"$IF"/"if") * space * (P"("/" ") * space * Exp * space * (P")"/" then ") * space *
              Lblock * space *
              ((K"$ELSE"/"else") * space * Lblock * space)^-1 * (K"$END"/"end");

    Stat0 = Whilestat +
            Repstat +
            K "$EXIT"    / "exit()" +
            K "$AKEY"    / 'Keys("AKey")' +
            K "$SELWORD" / 'Keys("SelWord")' +
            K "$XLAT"    / 'Keys("XLat")' +
            (comment * space * "=" * space) / "-- " *
              (String / function(c) return c:sub(2,-2) end) *
              ((space * P ";" * S(" \t")^0)/"") * (S"\r\n" + -1) +
            (comment * space * "=" * space) / "--[=[ " *
              (String / function(c) return c:sub(2,-2) end) *
              space * (P";"/"]=]") * S(" \t")^0 * #(P(1) - rspace) +
            var/f_var * space * "=" * space * Exp * space * P ";" +
            Functioncall +
            FmlIncludeInt +
            String / 'print(%0)' + -- NOT DOCUMENTED
            keys;

    Stat = Stat0 +
           Ifstat;

    Lstat = Stat0 +
            Lifstat +
            K "$BREAK"/"break" * #(space * K"$END") +
            K "$BREAK"/"do break end" +
            Carg(1) * Carg(2) * Cp() * C(K("$CONTINUE")) /
              function(subj, t_msg, pos, token)
                local line,pos = ProcessPos(subj,pos)
                msg = ("Warning:%d:%d: operator CONTINUE not supported"):format(line,pos)
                table.insert(t_msg, msg)
                return token
              end;

    Exp = P1 * (space * (P"||"/" or " + C"^^" + P"&&"/" and ") * space * P1)^0;

    P1 = (P2 * (space * P "|" * space * P2)^0) /
           function(...)
             --print("P1:|:",...)
             if select("#", ...)==1 then return ... end
             return "bor(" .. table.concat({...},",") .. ")"
           end;

    P2 = (P3 * (space * P "^" * space * P3)^0) /
           function(...)
             --print("P2:^:",...)
             if select("#", ...)==1 then return ... end
             return "bxor(" .. table.concat({...},",") .. ")"
           end;

    P3 = (P4 * (space * P "&" * space * P4)^0) /
           function(...)
             --print("P3:&:",...)
             if select("#", ...)==1 then return ... end
             return "band(" .. table.concat({...},",") .. ")"
           end;

    P4 = Cs(P5 * (space * (P "==" + (P "!=" / "~=") + P "<=" + P ">=" + S "<>") * space * P5)^0) /
           function(...)
             --print("P4:==:",...)
             return ...
           end;

    P5 = Cf(P6 * (space * (C "<<" + C ">>") * space * P6)^0,
           function(acc,newvalue)
             --print("P5:<<:acc:",acc,newvalue)
             if newvalue=="<<" then return "lshift("..acc..","
             elseif newvalue==">>" then return "rshift("..acc..","
             else return acc..newvalue..")"
             end
           end) /
           function(...)
             --print("P5:<<:",...)
             return ...
           end;

    P6 = (Term * (C(space * S "+-*/" * space) * Term)^0) /
           function(...)
             --print("P6:+:",...)
             local n = select("#", ...)
             if n==1 then return ... end
             local tb = {...}
             for k=2,n,2 do
               if not lpeg.match(space * P"+" * space, tb[k]) then return table.concat(tb) end
             end
             for k=1,n,2 do
               if lpeg.match(String*(-1), tb[k]) then
                 for m=2,n,2 do tb[m]=tb[m]:gsub("%+","..") end
                 break
               end
             end
             return table.concat(tb)
           end;

    Term = Cs(
             Number +
             String +
             unop * space * Term +
             (P "~" / "") * space * (Term / "bnot(%0)") +
             Functioncall +
             Propname / rep_prop +
             var / f_var +
             FmlConst + FmlAkey +
             Const +
             -- -- key +         -- TO DOCUMENT: very problematic to handle correctly
             P "(" * space * Exp * space * P ")"
             );

    Functioncall = -- Process case "eval(akey(1 [,0]))" separately.
        (K"eval" * space * "(" * space * K"akey" * space * "(" * space * "1" *
          (space * P"," * space * "0")^-1 * space * ")" * space * ")") / "Keys(akey(1,0))" +
        Carg(1) * Carg(2) * Cp() * C(macroident) /
          function(subj, t_msg, pos, funcname)
            local outname = kwords_functions[funcname:lower()]
            if not outname then
              local line,pos = ProcessPos(subj,pos)
              msg = ("Warning:%d:%d: function '%s' does not exist"):format(line,pos,funcname)
              table.insert(t_msg, msg)
            end
            return outname or funcname
          end *
          space * Args;

    Explist = Exp * (space * P "," * (space * Exp)^-1)^0;

    Args = P "(" * space * (Explist * space)^-1 * P ")";
  }
  return tbPatt
end

local function ProcessMacro(pos, subj, t_log)
  local converter = Cs(P(GetMacroPattern("chunk")))
  return lpeg.match(converter, subj, 1, subj, t_log)
         or error("bad chunk at position "..pos)
end

local xmlspace = (P"<!--" * (P(1) - "-->")^0 * "-->" + S" \t\r\n")^0

local function GetXMLPattern (op)
  return {
    [1] = space * (
            op=="xml_file" and XML_file or
            op=="xml_macros" and XML_macros or
            op=="xml_keymacros" and XML_keymacros or
            op=="xml_macro" and XML_macro) *
            space * -P(1);

    XML_cdata = P"<![CDATA[" * space *
                  ((Cp() * C((P(1) - "]]>")^0) * Carg(2)) / ProcessMacro) * space * "]]>";

    XML_text = (P"<text>" + PErr"tag <text> expected") * xmlspace *
                 (XML_cdata +
                   Cs(Cc("<![CDATA[ ") * ((Cp() * C((P(1) - "</text>")^0) * Carg(2)) / ProcessMacro) * Cc(" ]]>"))) *
                 xmlspace * "</text>";

    XML_macro = P"<macro" * (P(1) - P">")^0 * P">" *
                xmlspace * XML_text^-1 * xmlspace * "</macro>";

    XML_keymacros = P"<keymacros>" * xmlspace * (XML_macro * xmlspace)^0 * "</keymacros>";

    XML_macros = P"<macros>" *
                   ((P(1) - XML_keymacros - "</macros>")^0 * XML_keymacros)^0 *
                   xmlspace * "</macros>";

    XML_file = (P"<?xml" * (P(1) - "?>")^0 * "?>")^-1 * xmlspace *
                 (P"<farconfig" * (P(1) - ">")^0 * ">" + PErr"tag <farconfig> expected") *
                 ((P(1) - XML_macros - "</farconfig>")^0 * XML_macros)^0 *
                 xmlspace * "</farconfig>";
  }
end

local function Convert (op, subj)
  local func = op:find("^xml_") and GetXMLPattern or GetMacroPattern
  local converter = Cs(P(func(op)))
  local t_log = {}
  local ok, str = pcall(lpeg.match, converter, subj, 1, subj, t_log)
  return ok and str, table.concat(t_log, "\n")
end

if not far.Show then
  print(
    Convert("chunk", [==[
$while(3)
$CONTINUE
$end
]==]))
end

return {
  Convert = Convert,
}
