-- Rename files in the directory, using Far regular expressions
--
-- luacheck: globals _Plugin

local Common     = require "lfs_common"
local M          = require "lfs_message"

local libDialog  = require "far2.dialog"
local libMessage = require "far2.message"

local AppName = "LF Rename"
local RegPath = "LuaFAR\\"..AppName.."\\"

local F = far.Flags
local KEEP_DIALOG_OPEN = 0
local HistData = _Plugin.History:field("rename")
local GsubMB = Common.GsubMB
local Rex = Common.GetRegexLib("far")

local function ErrorMsg (text, title)
  far.Message (text, title or AppName, nil, "w")
end

local NewLog do
  local Log = {}
  local LogMeta = {__index=Log}

  NewLog = function (real)
    local self = real and {real=true,header={},items={},footer={}} or {}
    return setmetatable(self, LogMeta)
  end

  function Log:IsReal()         return self.real or false end
  function Log:AddHeaderLine(s) if self.real then self.header[#self.header+1]=s end end
  function Log:StartAddItems(s) if self.real then self.startitems=s end end
  function Log:AddItem(s)       if self.real then self.items[#self.items+1]=s end end
  function Log:EndAddItems(s)   if self.real then self.enditems=s end end
  function Log:AddFooterLine(s) if self.real then self.footer[#self.footer+1]=s end end
  function Log:GetItemsCount()  return self.real and #self.items or 0 end

  function Log:WriteFile (filename)
    if not self.real then return end
    local fp = assert( io.open(filename, "w") )

    if self.header[1] then
      for _,v in ipairs(self.header) do fp:write(v, "\n") end
      fp:write("\n")
    end

    if self.startitems then fp:write(self.startitems, "\n") end
    for _,v in ipairs(self.items) do fp:write(v, "\n") end
    if self.enditems then fp:write(self.enditems, "\n") end

    if self.footer[1] then
      fp:write("\n")
      for _,v in ipairs(self.footer) do fp:write(v, "\n") end
    end
    fp:close()
  end
end

local function TransformReplacePat (aStr)
  local T = { MaxGroupNumber=0 }
  local patt = [[
    \\([NX]) |
    \\([LlUuE]) |
    (\\R) (?: \{ ([-]?\d+) (?: , (\d+))? \} )? |
    \\x([0-9a-fA-F]{0,4}) |
    \\D \{ ([^\}]+) \} |
    \\(.?) |
    \$(.?) |
    (.)
  ]]

  for nm,case,R1,R2,R3,hex,date,escape,group,char in regex.gmatch(aStr,patt,"sx") do
    if nm then
      T[#T+1] = { nm=="N" and "name" or "extension" }

    elseif case then
      T[#T+1] = { "case", case }

    elseif R1 then
      T[#T+1] = { "counter", R2 and tonumber(R2) or 1, R3 and tonumber(R3) or 0 }

    elseif hex then
      local dec = tonumber(hex,16) or 0
      T[#T+1] = { "hex", ("").char(dec) }

    elseif date then
      T[#T+1] = { "date", date }

    elseif escape then
      local val = escape:match("[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]")
      if val then T[#T+1] = { "literal", val }
      else return nil, "invalid or incomplete escape: \\"..escape
      end

    elseif group then
      local val = tonumber(group,36)
      if val then
        if T.MaxGroupNumber < val then T.MaxGroupNumber = val end
        T[#T+1] = { "group", val }
      else
        return nil, M.MErrorGroupNumber..": $"..group
      end

    elseif char then
      if T[#T] and T[#T][1]=="literal" then T[#T][2] = T[#T][2] .. char
      else T[#T+1] = { "literal", char }
      end

    end

    local curr = T[#T]
    if curr[1]=="hex" or curr[1]=="literal" then
      local c = curr[2]:match("[\\/:*?\"<>|%c%z]")
      if c then
        return nil, "invalid filename character: "..(curr[1]=="hex" and "\\x"..hex or c)
      end
    end

  end
  return T
end

local function GetReplaceFunction (aReplacePat)
  if type(aReplacePat) == "function" then return
    function(collect,nMatch,nReps)
      local rep, ret2 = aReplacePat(collect, nMatch, nReps+1)
      if type(rep)=="number" then rep=tostring(rep) end
      return rep, ret2
    end

  elseif type(aReplacePat) == "table" then
    return function(collect, nFound, nReps, fullname)
      local name, ext = fullname:match("^(.*)%.([^.]*)$")
      if not name then name, ext = fullname, "" end
      local rep, stack = "", {}
      local case, instant_case
      for _,v in ipairs(aReplacePat) do
        local instant_case_set = nil
        ---------------------------------------------------------------------
        if v[1] == "case" then
          if v[2] == "L" or v[2] == "U" then
            stack[#stack+1], case = v[2], v[2]
          elseif v[2] == "E" then
            if stack[1] then table.remove(stack) end
            case = stack[#stack]
          else
            instant_case, instant_case_set = v[2], true
          end
        ---------------------------------------------------------------------
        elseif v[1] == "counter" then
          rep = rep .. ("%%0%dd"):format(v[3]):format(nReps+v[2])
        ---------------------------------------------------------------------
        elseif v[1] == "hex" then
          rep = rep .. v[2]
        ---------------------------------------------------------------------
        else
          local c
          if     v[1] == "literal"   then c = v[2]
          elseif v[1] == "name"      then c = name
          elseif v[1] == "extension" then c = ext
          elseif v[1] == "group"     then
            c = collect[v[2]]
            assert (c ~= nil, "invalid capture index")
          elseif v[1] == "date" then
            local d = os.date(v[2])
            if type(d)=="string" then rep = rep .. d end
          end
          if c then -- a capture *can* equal false or nil
            if instant_case then
              local d = c:sub(1,1)
              rep = rep .. (instant_case=="l" and d:lower() or d:upper())
              c = c:sub(2)
            end
            c = (case=="L" and c:lower()) or (case=="U" and c:upper()) or c
            rep = rep .. c
          end
        ---------------------------------------------------------------------
        end
        if not instant_case_set then
          instant_case = nil
        end
      end
      return rep
    end
  else
    error("invalid type of replace pattern")
  end
end

local LogTable = {
  "MDlgFileMask",           "sFileMask",
  "MDlgRenameInAll",        "rSearchInAll",
  "MDlgRenameInSelected",   "rSearchInSelected",
  "MDlgRenameInSubfolders", "bRenRecurse",
  "MDlgRenameFiles",        "bRenFiles",
  "MDlgRenameFolders",      "bRenFolders",
  "MDlgSearchPat",          "sSearchPat",
  "MDlgReplacePat",         "sReplacePat",
  "MDlgRepIsFunc",          "bRepIsFunc",
  "MRenameConfirmRename",   "bConfirmRename",
  "MDlgAdvanced",           "bAdvanced",
  "MDlgInitFunc",           "sInitFunc",
  "MDlgFinalFunc",          "sFinalFunc",
}

local UserGuid = win.Uuid("af8d7072-ff17-4407-9af4-7323273ba899")

local function UserDialog (aData, aList, aDlgTitle)
  local HIST_SEARCH  = RegPath .. "Search"
  local HIST_REPLACE = RegPath .. "Replace"
  local HIST_INITFUNC  = _Plugin.DialogHistoryPath .. "InitFunc"
  local HIST_FINALFUNC = _Plugin.DialogHistoryPath .. "FinalFunc"

  local W = 72
  local X1 = 5 + M.MDlgFileMask:len() -- mask offset
  local X2 = 5 + math.max(M.MDlgRenameBefore:len()+4, M.MDlgRenameAfter:len())

  local FLAGS_SEP = {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}
  local FLAGS_EDIT = {DIF_HISTORY=1,DIF_USELASTHISTORY=1}
  local FLAGS_BTNOK = {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}
  ------------------------------------------------------------------------------
  local Dlg = libDialog.NewDialog()
  Dlg._                 = {"DI_DOUBLEBOX", 3, 1,  W,22, 0, 0, 0, 0, aDlgTitle}

  Dlg.lab               = {"DI_TEXT",        5, 2,  0, 0, 0, 0, 0, 0, M.MDlgFileMask}
  Dlg.sFileMask         = {"DI_EDIT",       X1, 2, 70, 0, 0, "Masks", 0, "DIF_HISTORY", ""}
  Dlg.rSearchInAll      = {"DI_RADIOBUTTON", 5, 3,  0, 0, 1, 0, 0, "DIF_GROUP", M.MDlgRenameInAll}
  Dlg.rSearchInSelected = {"DI_RADIOBUTTON", 5, 4,  0, 0, 0, 0, 0, 0, M.MDlgRenameInSelected}
  Dlg.bRenFiles         = {"DI_CHECKBOX",   39, 3,  0, 0, 1, 0, 0, 0, M.MDlgRenameFiles }
  Dlg.bRenFolders       = {"DI_CHECKBOX",   39, 4,  0, 0, 0, 0, 0, 0, M.MDlgRenameFolders }
  Dlg.bRenRecurse       = {"DI_CHECKBOX",    5, 5,  0, 0, 0, 0, 0, 0, M.MDlgRenameInSubfolders }
  Dlg.sep               = {"DI_TEXT",        5, 6,  0, 0, 0, 0, 0, FLAGS_SEP, ""}

  Dlg.lab               = {"DI_TEXT",        5, 7,  0, 0, 0, 0, 0, 0, M.MDlgSearchPat}
  Dlg.sSearchPat        = {"DI_EDIT",        5, 8,W-2, 6, 0, HIST_SEARCH, 0, FLAGS_EDIT, ""}
  Dlg.lab               = {"DI_TEXT",        5, 9,  0, 0, 0, 0, 0, 0, M.MDlgReplacePat}
  Dlg.sReplacePat       = {"DI_EDIT",        5,10,W-2, 6, 0, HIST_REPLACE, 0, FLAGS_EDIT, ""}
  Dlg.bRepIsFunc        = {"DI_CHECKBOX",    7,11,  0, 0, 0, 0, 0, 0, M.MDlgRepIsFunc}
  Dlg.bConfirmRename    = {"DI_CHECKBOX",   39,11,  0, 0, 1, 0, 0, 0, M.MRenameConfirmRename }
  Dlg.bLogFile          = {"DI_CHECKBOX",    7,12,  0, 0, 1, 0, 0, 0, M.MDlgRenameLogfile }
  Dlg.sep               = {"DI_TEXT",        5,13,  0, 0, 0, 0, 0, FLAGS_SEP, ""}

  Dlg.bAdvanced         = {"DI_CHECKBOX",    5,14,  0, 0, 0, 0, 0, 0, M.MDlgAdvanced}
  Dlg.labInitFunc       = {"DI_TEXT",        5,15,  0, 0, 0, 0, 0, 0, M.MDlgInitFunc}
  Dlg.sInitFunc         = {"DI_EDIT",        5,16, 36, 0, 0, HIST_INITFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  Dlg.labFinalFunc      = {"DI_TEXT",       39,15,  0, 0, 0, 0, 0, 0, M.MDlgFinalFunc}
  Dlg.sFinalFunc        = {"DI_EDIT",       39,16, 70, 0, 0, HIST_FINALFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  Dlg.sep               = {"DI_TEXT",        5,17,  0, 0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}

  Dlg.btnBefore         = {"DI_BUTTON",      5,18,  0, 0, 0, 0, 0, "DIF_BTNNOCLOSE", M.MDlgRenameBefore}
  Dlg.edtBefore         = {"DI_EDIT",       X2,18,W-2, 0, 0, 0, 0, "DIF_READONLY", "", _noauto=1, skipF4=1}
  Dlg.lab               = {"DI_TEXT",        5,19,  0, 0, 0, 0, 0, 0, M.MDlgRenameAfter}
  Dlg.edtAfter          = {"DI_EDIT",       X2,19,W-2, 0, 0, 0, 0, "DIF_READONLY", "", _noauto=1, skipF4=1}
  Dlg.sep               = {"DI_TEXT",        5,20,  0, 0, 0, 0, 0, FLAGS_SEP, ""}

  Dlg.btnOk             = {"DI_BUTTON",      0,21,  0, 0, 0, 0, 0, FLAGS_BTNOK, M.MOk, NoHilite=1}
  Dlg.btnConfig         = {"DI_BUTTON",      0,21,  0, 0, 0, 0, 0, "DIF_CENTERGROUP", M.MDlgBtnConfig}
  Dlg.btnCancel         = {"DI_BUTTON",      0,21,  0, 0, 0, 0, 0, "DIF_CENTERGROUP", M.MCancel, NoHilite=1}
  ------------------------------------------------------------------------------

  local m_index = 1    -- circular index into aList; incremented when btnBefore is pressed;
  local m_uRegex       -- compiled regular expression; gets recompiled upon every change in sSearchPat field;
  local m_tReplace     --
  local m_fReplace     -- replace function; gets recreated upon every change in sReplacePat field;
  local m_sErrSearch   -- description of error in the sSearchPat field (if any);
  local m_sErrReplace  -- description of error in the sReplacePat field (if any);
  local m_sErrMaxGroup -- fixed message "inexistent group" (if any);
  local m_InitFunc     -- function to be executed before the operation;
  local m_FinalFunc    -- function to be executed after the operation;
  ------------------------------------------------------------------------------

  -- Workaround Far glitch:
  --   when the previous value was longer than DM_EDIT length and the new value is short,
  --   Far incorrectly calculates LeftPos and the new value may either not show at all
  --   or show only a few of its last characters.
  local function FixLeftPos (hDlg, Id)
    local len = hDlg:send("DM_GETTEXT", Id):len()
    local p = hDlg:send("DM_GETITEMPOSITION", Id)
    hDlg:send("DM_SETEDITPOSITION", Id,
      { LeftPos=math.max(1, len+1-(p.Right-p.Left)); CurPos=len+1; CurTabPos=len+1 })
  end

  local function UpdatePreviewLabel (hDlg)
    local text
    m_sErrMaxGroup = nil
    if m_sErrSearch then
      text = "<S> "..m_sErrSearch
    elseif m_sErrReplace then
      text = "<R> "..m_sErrReplace
    elseif not Dlg.bRepIsFunc:GetCheck(hDlg) and m_tReplace.MaxGroupNumber >= m_uRegex:bracketscount() then
      m_sErrMaxGroup = "inexistent group"
      text = "<R> "..m_sErrMaxGroup
    else
      local name = aList[m_index]:match("[^\\/]+$")
      local ok, res = pcall(GsubMB, name, m_uRegex, m_fReplace, m_index, m_index-1, name) -- m_fReplace can raise error
      if ok then text = res
      else text = "<R> "..res
      end
    end
    Dlg.edtAfter:SetText(hDlg, text)
    FixLeftPos(hDlg, Dlg.edtBefore.id)
    FixLeftPos(hDlg, Dlg.edtAfter.id)
  end

  local function UpdateSearchPat (hDlg)
    local pat = Dlg.sSearchPat:GetText(hDlg)
    local ok, res = pcall(Rex.new, pat, "i")
    if ok then m_uRegex, m_sErrSearch = res, nil
    else m_uRegex, m_sErrSearch = nil, res
    end
  end

  local function NewEnvir()
    local Envir = setmetatable({rex=Rex}, {__index=_G})
    Envir.dofile = function(fname)
      local f = assert(loadfile(fname))
      return setfenv(f, Envir)()
    end
    return Envir
  end

  local function UpdateReplacePat (hDlg)
    local repl = Dlg.sReplacePat:GetText(hDlg)
    m_sErrReplace = nil
    if Dlg.bRepIsFunc:GetCheck(hDlg) then
      local func, msg = loadstring("local T,M,R = ...\n" .. repl, M.MReplaceFunction)
      if func then m_tReplace = setfenv(func, NewEnvir())
      else m_sErrReplace = msg
      end
    else
      local ret, msg = TransformReplacePat(repl)
      if ret then m_tReplace = ret
      else m_sErrReplace = msg
      end
    end
    if m_sErrReplace==nil then m_fReplace = GetReplaceFunction(m_tReplace) end
  end

  local function CheckAdvancedEnab (hDlg)
    local bEnab = Dlg.bAdvanced:GetCheck(hDlg)
    Dlg.labInitFunc   :Enable(hDlg, bEnab)
    Dlg.sInitFunc     :Enable(hDlg, bEnab)
    Dlg.labFinalFunc  :Enable(hDlg, bEnab)
    Dlg.sFinalFunc    :Enable(hDlg, bEnab)
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      Dlg.edtBefore:SetText(hDlg, aList[1])
      UpdateSearchPat(hDlg)
      UpdateReplacePat(hDlg)
      UpdatePreviewLabel(hDlg)
      if not (Dlg.bRenFolders:GetCheck(hDlg) or Dlg.bRenFolders:GetCheck(hDlg)) then
        Dlg.bRenFiles:SetCheck(hDlg,1)
      end
      CheckAdvancedEnab(hDlg)

    elseif msg == F.DN_EDITCHANGE then
      if param1 == Dlg.sSearchPat.id then
        UpdateSearchPat(hDlg)
        UpdatePreviewLabel(hDlg)
      elseif param1 == Dlg.sReplacePat.id then
        UpdateReplacePat(hDlg)
        UpdatePreviewLabel(hDlg)
      end

    elseif msg == F.DN_BTNCLICK then
      if param1 == Dlg.bRenFiles.id then
        if not Dlg.bRenFiles:GetCheck(hDlg) then Dlg.bRenFolders:SetCheck(hDlg,1) end
      elseif param1 == Dlg.bRenFolders.id then
        if not Dlg.bRenFolders:GetCheck(hDlg) then Dlg.bRenFiles:SetCheck(hDlg,1) end
      elseif param1 == Dlg.bRepIsFunc.id then
        UpdateReplacePat(hDlg)
        UpdatePreviewLabel(hDlg)
      elseif param1 == Dlg.btnBefore.id then
        m_index = (m_index < #aList) and m_index+1 or 1
        Dlg.edtBefore:SetText(hDlg, aList[m_index])
        UpdatePreviewLabel(hDlg)
      elseif param1 == Dlg.bAdvanced.id then
        CheckAdvancedEnab(hDlg)
      end

    elseif msg == F.DN_CLOSE then
      if param1 == Dlg.btnOk.id then
        local mask = Dlg.sFileMask:GetText(hDlg)
        if not far.ProcessName("PN_CHECKMASK", mask, "", "PN_SHOWERRORMESSAGE") then
          Common.GotoEditField(hDlg, Dlg.sFileMask.id)
          return KEEP_DIALOG_OPEN
        end
        if m_sErrSearch then
          ErrorMsg(m_sErrSearch, M.MSearchPattern..": "..M.MSyntaxError)
          Common.GotoEditField(hDlg, Dlg.sSearchPat.id)
          return KEEP_DIALOG_OPEN
        elseif m_sErrReplace or m_sErrMaxGroup then
          ErrorMsg(m_sErrReplace or m_sErrMaxGroup, M.MReplacePattern..": "..M.MSyntaxError)
          Common.GotoEditField(hDlg, Dlg.sReplacePat.id)
          return KEEP_DIALOG_OPEN
        end
        if Dlg.bAdvanced:GetCheck(hDlg) then
          local msg2
          local sInitFunc = Dlg.sInitFunc:GetText(hDlg)
          m_InitFunc, msg2 = loadstring (sInitFunc or "", "Initial")
          if not m_InitFunc then
            ErrorMsg(msg2, "Initial Function: " .. M.MSyntaxError)
            Common.GotoEditField(hDlg, Dlg.sInitFunc.id)
            return KEEP_DIALOG_OPEN
          end
          local sFinalFunc = Dlg.sFinalFunc:GetText(hDlg)
          m_FinalFunc, msg2 = loadstring (sFinalFunc or "", "Final")
          if not m_FinalFunc then
            ErrorMsg(msg2, "Final Function: " .. M.MSyntaxError)
            Common.GotoEditField(hDlg, Dlg.sFinalFunc.id)
            return KEEP_DIALOG_OPEN
          end
          local env = type(m_tReplace)=="function" and getfenv(m_tReplace) or NewEnvir()
          setfenv(m_InitFunc, env)
          setfenv(m_FinalFunc, env)
        end
      elseif param1 == Dlg.btnConfig.id then
        hDlg:send(F.DM_SHOWDIALOG, 0)
        Common.ConfigDialog()
        hDlg:send(F.DM_SHOWDIALOG, 1)
        hDlg:send(F.DM_SETFOCUS, Dlg.btnOk.id)
        return KEEP_DIALOG_OPEN
      end
    end
  end

  Common.AssignHotKeys(Dlg)
  libDialog.LoadData(Dlg, aData)
  if far.Dialog (UserGuid,-1,-1,W+4,24,"Rename",Dlg,0,DlgProc) == Dlg.btnOk.id then
    libDialog.SaveData(Dlg, aData)
    _Plugin.History:save()
    return {
      Regex             = m_uRegex,
      fReplace          = m_fReplace,
      bRenFiles         = aData.bRenFiles,
      bRenFolders       = aData.bRenFolders,
      bRenRecurse       = aData.bRenRecurse,
      bConfirmRename    = aData.bConfirmRename,
      rSearchInSelected = aData.rSearchInSelected,
      rSearchInAll      = aData.rSearchInAll,
      sFileMask         = aData.sFileMask,
      InitFunc          = m_InitFunc,
      FinalFunc         = m_FinalFunc,
    }
  end
end

local function GetUserChoice (s_found, s_rep)
  local color = libMessage.GetInvertedColor("COL_DIALOGTEXT")
  local c = libMessage.Message(
    {
      M.MRenameUserChoiceRename,"\n",
      { text=s_found, color=color },"\n",
      M.MRenameUserChoiceTo,"\n",
      { text=s_rep, color=color },
    },
    AppName, M.MRenameUserChoiceButtons, "c", nil,
    win.Uuid("b527e9e5-25c0-4572-952d-3002b57a5463"))
  return c==1 and "yes" or c==2 and "all" or c==3 and "no" or "cancel"
end

local function DoAction (Params, aDir, aLog)
  local Regex = Params.Regex
  local fReplace = Params.fReplace
  local bRecurse = Params.bRenRecurse
  local bRenFiles = Params.bRenFiles
  local bRenFolders = Params.bRenFolders

  local nMatch, nReps = 0, 0
  local sChoice = not Params.bConfirmRename and "all"

  local function RenameItem (aItem, aFullName)
    if aItem.FileAttributes:find("d") then
      if not bRenFolders then return end
    else
      if not bRenFiles then return end
    end
    nMatch = nMatch + 1
    local path, oldname = aFullName:match("^(.-)([^\\]+)$")
    local newname = GsubMB(oldname, Regex, fReplace, nMatch, nReps, oldname)
    if newname ~= oldname then
      if sChoice ~= "all" then
        sChoice = GetUserChoice(oldname, newname)
        if sChoice == "cancel" then return true end
      end
      if sChoice ~= "no" then
        local prefix = [[\\?\]]
        local newFullName = path .. newname
        local res, err = win.RenameFile(prefix..aFullName, prefix..newFullName)
        if res then
          nReps = nReps + 1
          aLog:AddItem(("  %q, %q, %q,"):format(prefix..path, oldname, newname))
          return nil, newFullName
        else
          err = string.gsub(err, "[\r\n]+", " ")
          aLog:AddItem(("--%q, %q, %q, --ERROR: %s"):format(prefix..path, oldname, newname, err))
          far.Message(aFullName.."\n\n"..newFullName.."\n\n"..err, AppName, nil, "wl")
        end
      end
    end
  end

  local ShowProgress do
    local W = 50
    local prefix = M.MRenameProcessingDir:sub(1,W)
    prefix = prefix .. (" "):rep(W-prefix:len()) .. "\n"
    ShowProgress = function (dir)
      if dir:len() > W then dir = dir:sub(1,16).."..."..dir:sub(-W+3+16) end
      far.Message(prefix..dir, AppName, "", "l")
    end
  end

  local function ProcessDirectory (dir, mask)
    ShowProgress(dir)

    if win.ExtractKey()=="ESCAPE" and 1==far.Message(M.MUsrBrkPrompt, AppName, M.MBtnYesNo, "w") then
      return true
    end

    nMatch, nReps = 0, 0
    if far.RecursiveSearch(dir, mask, RenameItem, 0) then
      return true
    end
    if bRecurse then
      if far.RecursiveSearch(dir, "*",
        function (item, fullpath)
          if item.FileAttributes:find("d") then
            if ProcessDirectory(fullpath, mask) then return true end
          end
        end, 0)
      then
        return true
      end
    end
  end

  local panelInfo = panel.GetPanelInfo(nil, 1)
  local dir = panel.GetPanelDirectory(nil, 1).Name
  if dir ~= "" then dir = dir:gsub("\\?$", "\\", 1) end
  local ItemsNumber = Params.rSearchInAll and panelInfo.ItemsNumber or panelInfo.SelectedItemsNumber
  local GetItem = Params.rSearchInAll and panel.GetPanelItem or panel.GetSelectedPanelItem
  local ItemList = {}
  local DirList = bRecurse and {}

  local function GetFullPath (FileName) return dir=="" and FileName or dir..FileName end

  ShowProgress(dir~="" and dir or M.MRenamePluginDir)

  for i=1, ItemsNumber do
    local item = GetItem(nil, 1, i)
    if item and item.FileName ~= ".." then ItemList[#ItemList+1] = item end
  end

  for _, item in ipairs(ItemList) do
    if far.ProcessName("PN_CMPNAMELIST", Params.sFileMask, item.FileName, "PN_SKIPPATH") then
      local oldpath = GetFullPath(item.FileName)
      local oldChoice = sChoice
      local _, newpath = RenameItem(item, oldpath)
      if sChoice=="cancel" then
        break
      elseif sChoice=="all" and oldChoice~="all" then
        ShowProgress(dir~="" and dir or M.MRenamePluginDir)
      end
      if DirList and item.FileAttributes:find("d") then
        DirList[#DirList+1] = newpath or oldpath
      end
    else
      if DirList and item.FileAttributes:find("d") then
        DirList[#DirList+1] = GetFullPath(item.FileName)
      end
    end
  end

  if sChoice ~= "cancel" then
    if DirList then
      for _, fullpath in ipairs(DirList) do
        if ProcessDirectory(fullpath, Params.sFileMask) or sChoice == "cancel" then
          break
        end
      end
    end
  end
end

local function GetLogFileName()
  local config = _Plugin.History:field("config")
  local name = config.sLogFileTemplate or Common.DefaultLogFileName
  local tReplace = Common.TransformLogFilePat(name)
  local fReplace = GetReplaceFunction(tReplace)
  local rex = Common.GetRegexLib("far")
  local uRegex = rex.new(".*")
  local name2 = GsubMB("", uRegex, fReplace, 0, 1, "")
  return name2
end

local function main()
  local panelInfo = panel.GetPanelInfo(nil, 1)
  if panelInfo.ItemsNumber <= 1 then
    far.Message(M.MRenameNothingToRename, AppName)
    return
  end

  -- prepare list of files to rename, to avoid recursive renaming
  local list = {}
  if (panelInfo.SelectedItemsNumber > 1) or
        (panelInfo.SelectedItemsNumber == 1 and
        bit64.band(panel.GetSelectedPanelItem(nil, 1, 1).Flags, F.PPIF_SELECTED) ~= 0) then
    for i=1, panelInfo.SelectedItemsNumber do
      local item = panel.GetSelectedPanelItem (nil, 1, i)
      table.insert(list, item.FileName)
    end
  else
    for i=1, panelInfo.ItemsNumber do
      local item = panel.GetPanelItem (nil, 1, i)
      if item.FileName ~= ".." then table.insert(list, item.FileName) end
    end
  end

  local tParams = UserDialog(HistData, list, AppName)
  if not tParams then return end

  local dir = panel.GetPanelDirectory(nil, 1).Name
  if not (dir == "" or dir:find("[\\/]$")) then dir = dir.."\\" end

  local log = NewLog(HistData.bLogFile)
  if log:IsReal() then
    log:AddHeaderLine("--[====[------------------------------------------------------------------------")
    for k=1,#LogTable,2 do
      local name = M[LogTable[k]]:gsub("&",""):gsub("%:?$",":",1)
      local value = HistData[LogTable[k+1]]
      local fmt = type(value)=="string" and "  %-36s \"%s\"" or "  %-36s %s"
      log:AddHeaderLine(fmt:format(name, tostring(value)))
    end
    log:AddHeaderLine("--------------------------------------------------------------------------]====]")
  end

  if tParams.InitFunc then tParams.InitFunc() end
  log:StartAddItems ("local List = {")
  DoAction (tParams, dir, log)
  log:EndAddItems("}")
  if tParams.FinalFunc then tParams.FinalFunc() end

  if log:GetItemsCount() > 0 then
    log:AddFooterLine([[
for k = #List,1,-3 do
  local src, dst = List[k-2]..List[k], List[k-2]..List[k-1]
  local ok, msg = win.RenameFile(src, dst)
  if not ok then
    far.Message(src.."\n\n"..dst.."\n\n"..msg, "Warning", nil, "wl")
  end
end
panel.UpdatePanel(nil,1)
panel.RedrawPanel(nil,1)]])
  end

  log:WriteFile(dir..GetLogFileName())
  panel.UpdatePanel(nil,1); panel.RedrawPanel(nil,1)
  panel.UpdatePanel(nil,0); panel.RedrawPanel(nil,0)
end

return {
  main = main,
}
