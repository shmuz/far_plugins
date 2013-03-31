-- Rename files in the directory, using Far regular expressions
--

local AppName = "LF Rename"
local RegPath = "LuaFAR\\"..AppName.."\\"
local far2_dialog = require "far2.dialog"
local far2_message = require "far2.message"
local F = far.Flags

local far2_history = require "far2.history"
local History = far2_history.newsettings(AppName, "alldata")
local HistData = History:field("alldata")

local function ErrorMsg (text, title)
  far.Message (text, title or AppName, nil, "w")
end

local function TransformReplacePat (aStr)
  local T = {}
  aStr = regex.gsub(aStr, [[
      \\([NX]) |
      \\([LlUuE]) |
      (\\R \{ ([-]?\d+) , (\d+) \}) |
      (\\R \{ ([-]?\d+) \}) |
      (\\R) |
      \\x([0-9a-fA-F]{0,4}) |
      \\(.?) |
      \$(.?) |
      (.)
    ]],
    function(nm, c0, R1,R11,R12, R2,R21, R3, c1,c2,c3,c4)
      if nm then
        T[#T+1] = (nm == "N") and {"name"} or {"extension"}
      elseif c0 then
        T[#T+1] = { "case", c0 }
      elseif R1 or R2 or R3 then
        -- trying to work around the Far regex capture bug
        T[#T+1] = { "counter", R1 and tonumber(R11) or R2 and tonumber(R21) or 0,
                               R1 and tonumber(R12) or 0 }
      elseif c1 then
        c1 = tonumber(c1,16) or 0
        T[#T+1] = { "hex", unicode.utf8.char(c1) }
      elseif c2 then
        T[#T+1] = { "literal", c2:match("[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]")
          or error("invalid escape: \\"..c2) }
      elseif c3 then
        T[#T+1] = { "capture", tonumber(c3,16)
          or error("Invalid capture number"..": $"..c3) }
      elseif c4 then
        if T[#T] and T[#T][1]=="literal" then T[#T][2] = T[#T][2] .. c4
        else T[#T+1] = { "literal", c4 }
        end
      end
    end, nil, "sx")
  return T
end

local function NewGsub (aSubj, aRegex, aRepFunc, aCounter)
  local nFound, nReps = 0, 0
  local sOut = ""
  local x = 0
  local bAllowEmpty = true

  -- iterate on current file name
  while x <= aSubj:len() do
    -----------------------------------------------------------------------
    local collect = { aRegex:find(aSubj, x+1) }
    local fr, to = collect[1], collect[2]
    if not fr then break end
    -----------------------------------------------------------------------
    if fr==x+1 and to==x then
      if not bAllowEmpty then
        if x == aSubj:len() then break end
        collect = { aRegex:find(aSubj, x+1) }
        fr, to = collect[1], collect[2]
        if not fr then break end
      end
    end
    -----------------------------------------------------------------------
    sOut = sOut .. aSubj:sub(x+1, fr-1)
    collect[2] = aSubj:sub(fr, to)
    nFound = nFound + 1
    bAllowEmpty = false
    -----------------------------------------------------------------------
    local sRepFinal = aRepFunc(aSubj, collect, aCounter)
    if sRepFinal then
      sOut = sOut .. sRepFinal
      nReps = nReps + 1
    end
  -----------------------------------------------------------------------
    if x < to then
      x = to
    else
      x = x + 1
      sOut = sOut .. aSubj:sub(x, x)
    end
  -----------------------------------------------------------------------
  end -- current filename loop
  sOut = sOut .. aSubj:sub(x+1)
  return sOut, nFound, nReps
end

local function GetReplaceFunction (aReplacePat)
  if type(aReplacePat) == "table" then
    return function(fullname, collect, counter)
      local name, ext = fullname:match("^(.*)%.([^.]*)$")
      if not name then name, ext = fullname, "" end
      local rep, stack = "", {}
      local case, instant_case
      for k,v in ipairs(aReplacePat) do
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
          rep = rep .. ("%%0%dd"):format(v[3]):format(counter+v[2])
        ---------------------------------------------------------------------
        elseif v[1] == "hex" then
          rep = rep .. v[2]
        ---------------------------------------------------------------------
        else
          local c
          if     v[1] == "literal"   then c = v[2]
          elseif v[1] == "name"      then c = name
          elseif v[1] == "extension" then c = ext
          elseif v[1] == "capture"   then c = collect[2 + v[2]]
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

local function GetReplaceFunctionFromString (aReplacePat)
  local t = TransformReplacePat(aReplacePat)
  local f = GetReplaceFunction(t)
  return t, f
end

local UserGuid = win.Uuid("af8d7072-ff17-4407-9af4-7323273ba899")

local function UserDialog (aData, aList, aHelpTopic, aDlgTitle)
  local HIST_SEARCHPAT = RegPath .. "Search"
  local HIST_REPLACEPAT = RegPath .. "Replace"
  local W, X1 = 72, 14
  ------------------------------------------------------------------------------
  local D = far2_dialog.NewDialog()
  D._          = {"DI_DOUBLEBOX",3, 1, W,12,0, 0, 0, 0, aDlgTitle}
  D.lab        = {"DI_TEXT",     5, 2, 0,0, 0, 0, 0, 0, "&Search for:"}
  D.sSearchPat = {"DI_EDIT",     5, 3,W-2,6, 0, HIST_SEARCHPAT, 0, {DIF_HISTORY=1,DIF_USELASTHISTORY=1}, ""}
  D.lab        = {"DI_TEXT",     5, 4, 0,0, 0, 0, 0, 0, "&Replace with:"}
  D.sReplacePat= {"DI_EDIT",     5, 5,W-2,6, 0, HIST_REPLACEPAT, 0, {DIF_HISTORY=1,DIF_USELASTHISTORY=1}, ""}
  D.sep        = {"DI_TEXT",     5, 6, 0,0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  D.lab        = {"DI_TEXT",     5, 7, 0,0, 0, 0, 0, 0, "Before:"}
  D.labBefore  = {"DI_TEXT",    X1, 7, 0,0, 0, 0, 0, 0, ""}
  D.lab        = {"DI_TEXT",     5, 8, 0,0, 0, 0, 0, 0, "After :"}
  D.labAfter   = {"DI_TEXT",    X1, 8, 0,0, 0, 0, 0, 0, ""}
  D.sep        = {"DI_TEXT",     5, 9, 0,0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  D.bLogFile   = {"DI_CHECKBOX", 5,10, 0,0, HistData.bLogFile and 1 or 0, 0, 0, 0, "&Log file" }
  D.btnOk      = {"DI_BUTTON",   0,11, 0,0, 0, 0, 0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, "Ok"}
  D.btnCancel  = {"DI_BUTTON",   0,11, 0,0, 0, 0, 0, "DIF_CENTERGROUP", "Cancel"}
  ------------------------------------------------------------------------------
  local uRegex, tReplace, fReplace
  local sErrSearch, sErrReplace
  local close_params

  local function UpdateLabel (hDlg)
    if uRegex and fReplace then
      res = NewGsub(aList[1], uRegex, fReplace, 1)
      if res:len() > W-X1 then res = (res:sub(1, W-X1) .. "}") end
    else
      res = ""
    end
    D.labAfter:SetText(hDlg, res)
  end

  local function UpdateSearchPat (hDlg)
    -- get search pattern
    local pat = D.sSearchPat:GetText(hDlg)
    -- compile search pattern
    local ok, res = pcall(regex.new, pat, "i")
    -- process compilation results
    if ok then uRegex, sErrSearch = res, nil
    else uRegex, sErrSearch = nil, res
    end
  end

  local function UpdateReplacePat (hDlg)
    -- get replace pattern
    local repl = D.sReplacePat:GetText(hDlg)
    -- get replace function
    local ok, t, f = pcall(GetReplaceFunctionFromString, repl)
    -- process compilation results
    if ok then tReplace, fReplace, sErrReplace = t, f, nil
    else tReplace, fReplace, sErrReplace = nil, nil, t
    end
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      D.labBefore:SetText(hDlg, aList[1])
      UpdateSearchPat(hDlg)
      UpdateReplacePat(hDlg)
      UpdateLabel(hDlg)
    elseif msg == F.DN_EDITCHANGE then
      if param1 == D.sSearchPat.id then
        UpdateSearchPat(hDlg)
        UpdateLabel(hDlg)
      elseif param1 == D.sReplacePat.id then
        UpdateReplacePat(hDlg)
        UpdateLabel(hDlg)
      end
    elseif msg == F.DN_CLOSE then
      if param1 == D.btnOk.id then
        D.sSearchPat:SaveText(hDlg, aData)
        D.sReplacePat:SaveText(hDlg, aData)
        if uRegex and fReplace then
          close_params = { Regex=uRegex, ReplacePat=tReplace }
        else
          if sErrSearch then
            ErrorMsg(sErrSearch, "Search Pattern"..": ".."syntax error")
          elseif sErrReplace then
            ErrorMsg(sErrReplace, "Replace Pattern"..": ".."syntax error")
          end
          return 0
        end
        HistData.bLogFile = D.bLogFile:GetCheck(hDlg)
        History:save()
      end
    end
  end
  far.Dialog (UserGuid,-1,-1,W+4,14,aHelpTopic,D,0,DlgProc)
  return close_params
end

local function GetUserChoice (aTitle, s_found, s_rep)
  local color = far2_message.GetInvertedColor("COL_DIALOGTEXT")
  local c = far2_message.Message(
    {
      "Rename\n",
      { text=s_found, color=color },"\n",
      "to\n",
      { text=s_rep, color=color },
    },
    aTitle, "&Rename;&All;&Skip;&Cancel", "c", nil,
    win.Uuid("b527e9e5-25c0-4572-952d-3002b57a5463"))
  return c==1 and "yes" or c==2 and "all" or c==3 and "no" or "cancel"
end

local function DoAction (aParams, aList, aDir, aLog)
  aLog = aLog or { write=function() end }
  local Regex = aParams.Regex
  local fReplace = GetReplaceFunction(aParams.ReplacePat)
  local nFound, nReps = 0, 0
  local sChoice
  for i, oldname in ipairs(aList) do
    local sLine, nF, nR = NewGsub(oldname, Regex, fReplace, i)
    nFound, nReps = nFound + nF, nReps + nR
    if sLine ~= oldname then
      if sChoice ~= "all" then
        sChoice = GetUserChoice(AppName, oldname, sLine)
        if sChoice == "cancel" then break end
      end
      if sChoice ~= "no" then
        local res, err = win.RenameFile(aDir..oldname, aDir..sLine)
        aLog:write('"', oldname, '" >> "', sLine, '"')
        if err then
          err = string.gsub(err, "[\r\n]+", " ")
          aLog:write(" >> ERROR: ", err)
        end
        aLog:write("\n")
      end
    end
  end
  return nFound, nReps
end

local function main (helpTopic)
  local panelInfo = panel.GetPanelInfo(nil, 1)
  if panelInfo.ItemsNumber <= 1 then
    far.Message(" Nothing to rename. ", AppName)
    return
  end

  -- prepare list of files to rename, to avoid recursive renaming
  local list = {}
  local dlgTitle
  if (panelInfo.SelectedItemsNumber > 1) or
        (panelInfo.SelectedItemsNumber == 1 and
        bit64.band(panel.GetSelectedPanelItem(nil, 1, 1).Flags, F.PPIF_SELECTED) ~= 0) then
    for i=1, panelInfo.SelectedItemsNumber do
      local item = panel.GetSelectedPanelItem (nil, 1, i)
      table.insert(list, item.FileName)
    end
    dlgTitle = ("%s (%d selected %s)"):format(AppName, #list, (#list==1) and "item" or "items")
  else
    for i=1, panelInfo.ItemsNumber do
      local item = panel.GetPanelItem (nil, 1, i)
      if item.FileName ~= ".." then table.insert(list, item.FileName) end
    end
    dlgTitle = ("%s (total of %d %s)"):format(AppName, #list, (#list==1) and "item" or "items")
  end

  local data = {}
  local tParams = UserDialog(data, list, helpTopic, dlgTitle)
  if not tParams then return end

  local dir = panel.GetPanelDirectory(nil, 1).Name
  if not dir:find("[\\/]$") then dir = dir.."\\" end

  local log = HistData.bLogFile and assert( io.open(dir.."lf_rename.log", "w") )
  if log then  -- print log-file header
    log:write (("====="):rep(15), "\n")
    log:write ("Pattern:  \"", data.sSearchPat, "\"\n")
    log:write ("Replace:  \"", data.sReplacePat, "\"\n")
    log:write (("====="):rep(15), "\n\n")
  end

  DoAction (tParams, list, dir, log)

  if log then log:write("\n"); log:close(); end

  panel.UpdatePanel (nil, 1, true)
  panel.RedrawPanel (nil, 1)
end

local arg = ...
local helpTopic = arg and arg[1]
main(helpTopic)
