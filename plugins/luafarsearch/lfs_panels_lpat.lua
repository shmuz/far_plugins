-- Started:                       2020-03-13
-- Included in LF Search plugin:  2020-03-26
-- Goal:         Find files containing text matching a given Lua pattern
-- Why started:  Encountered a difficulty to find [\128-\255] with LF Search plugin

local Common = require "lfs_common"
local M      = require "lfs_message"

local AssignHotKeys      = Common.AssignHotKeys
local CheckMask          = Common.CheckMask
local DisplaySearchState = Common.DisplaySearchState
local ErrorMsg           = Common.ErrorMsg
local GotoEditField      = Common.GotoEditField
local NewUserBreak       = Common.NewUserBreak

local F = far.Flags
local HistData = _Plugin.History:field("lua_pattern")
local GuidDlg = "120E9831-4C0F-4EFC-B39B-8B2F2F192BAC"


local function GetDialogData()
  local hist_flags = F.DIF_HISTORY + F.DIF_USELASTHISTORY
  local def_flags  = F.DIF_DEFAULTBUTTON + F.DIF_CENTERGROUP
  local mcurr      = HistData.bOnlyCurrFolder and 1 or 0
  local minvr      = HistData.bInverseSearch and 1 or 0
  local Items = {
--[[01]] {F.DI_DOUBLEBOX,  3, 1,72,11,   0,     0,            0, 0,                 M.MTitleSearchLua},
--[[02]] {F.DI_TEXT,       5, 2, 0, 0,   0,     0,            0, 0,                 M.MDlgFileMask},
--[[03]] {F.DI_EDIT,       5, 3,70, 0,   0,     "Masks",      0, hist_flags,        ""},
--[[04]] {F.DI_TEXT,       5, 4, 0, 0,   0,     0,            0, 0,                 M.MDlgSearchPat},
--[[05]] {F.DI_EDIT,       5, 5,70, 0,   0,     "SearchText", 0, hist_flags,        ""},
--[[06]] {F.DI_TEXT,      -1, 6, 0, 0,   0,     0,            0, F.DIF_SEPARATOR,   ""},

--[[07]] {F.DI_CHECKBOX,   5, 7, 0, 0,   mcurr, 0,            0, 0,                 M.MSaOnlyCurrFolder},
--[[08]] {F.DI_CHECKBOX,   5, 8, 0, 0,   minvr, 0,            0, 0,                 M.MDlgInverseSearch},
--[[09]] {F.DI_TEXT,      -1, 9, 0, 0,   0,     0,            0, F.DIF_SEPARATOR,   ""},

--[[10]] {F.DI_BUTTON,     0,10, 0, 0,   0,     0,            0, def_flags,         M.MOk, NoHilite=1},
--[[11]] {F.DI_BUTTON,     0,10, 0, 0,   0,     0,            0, F.DIF_CENTERGROUP, M.MCancel, NoHilite=1},
  }
  local edtMask, edtPatt, cbxCurrFolder, cbxInverseSearch, btnOK = 3,5,7,8,10
  local sFileMask, sSearchPat
  local EscTable = { a="\a", b="\b", f="\f", n="\n", r="\r", t="\t",
                     ["\\"]="\\", ["\""]="\"", ["'"]="'" }

  local function DlgProc (hDlg,Msg,Param1,Param2)
    if Msg == F.DN_CLOSE and Param1 == btnOK then
      sFileMask = hDlg:send("DM_GETTEXT", edtMask)
      if not CheckMask(sFileMask) then
        GotoEditField(hDlg, edtMask)
        return 0
      end

      sSearchPat = hDlg:send("DM_GETTEXT", edtPatt)
      if sSearchPat == "" then
        ErrorMsg(M.MSearchFieldEmpty)
        GotoEditField(hDlg, edtPatt)
        return 0
      end

      local OK, msg = pcall(
        function()
          sSearchPat = string.gsub(sSearchPat, "\\(.?)",
            function(c) return EscTable[c] or error("Invalid escape pattern: \"\\"..c.."\"") end)
          local _ = (""):find(sSearchPat) -- can raise error
        end)
      if not OK then
        msg = msg:gsub(".-:%d+: ", "", 1) -- remove file name and line number
        far.Message(msg, M.MSearchPattern..": "..M.MSyntaxError, nil, "w")
        GotoEditField(hDlg, edtPatt)
        return 0
      end

      HistData.bOnlyCurrFolder = F.BSTATE_CHECKED == hDlg:send("DM_GETCHECK",cbxCurrFolder)
      HistData.bInverseSearch  = F.BSTATE_CHECKED == hDlg:send("DM_GETCHECK",cbxInverseSearch)
    end
  end

  AssignHotKeys(Items)
  if btnOK == far.Dialog (win.Uuid(GuidDlg),-1,-1,76,13,nil,Items,nil,DlgProc) then
    return {
      sFileMask = sFileMask;
      sSearchPat = sSearchPat;
      bOnlyCurrFolder = HistData.bOnlyCurrFolder;
      bInverseSearch = HistData.bInverseSearch;
    }
  end
end

local function SearchFromPanel()
  local Data = GetDialogData()
  if not Data then return nil, true end

  local _build = far.GetLuafarVersion and select(4,far.GetLuafarVersion(true))
  local readmode = _build and _build>=737 and "*b" or "*l" -- "*b" is a LuaFAR extension of file:read()
  local tFoundFiles, nTotalFiles = {}, 0
  local userbreak = NewUserBreak()

  DisplaySearchState("", 0, 0, 0, nil) -- inform the user as the 1-st callback may occur not soon
  far.RecursiveSearch(far.GetCurrentDirectory(), Data.sFileMask,
    function(aItem, aFullPath)
      if aItem.FileAttributes:find("d") then return; end
      if DisplaySearchState(aFullPath,#tFoundFiles,nTotalFiles,0,userbreak) then return "break"; end
      nTotalFiles = nTotalFiles + 1
      local fp = io.open(aFullPath, "rb") -- open in binary mode
      if fp then
        local found, skipped = false, false
        local tstart = far.FarClock()
        while true do
          local line = fp:read(readmode)
          if line == nil then break end
          if far.FarClock() - tstart >= 1e5 then
            if userbreak:ConfirmEscape(true) then skipped=true; break; end
            tstart = far.FarClock()
          end
          if string.match(line, Data.sSearchPat) then
            found = true; break
          end
        end
        fp:close()
        if not skipped and found == (not Data.bInverseSearch) then
          table.insert(tFoundFiles, aFullPath)
        end
        if userbreak.fullcancel then return "break"; end
      end -- end file processing
    end, -- end callback function
    Data.bOnlyCurrFolder and 0 or "FRS_RECUR")
  table.sort(tFoundFiles)
  return tFoundFiles[1] and tFoundFiles, false
end


return {
  SearchFromPanel = SearchFromPanel,
}
