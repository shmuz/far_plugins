-- lfs_panels.lua
-- luacheck: globals _Plugin

local M           = require "lfs_message"
local libCommon   = require "lfs_common"
local libEditors  = require "lfs_editors"
local libReader   = require "reader"
local libUCD      = require "ucd"
local libCqueue   = require "shmuz.cqueue"
local libDialog   = require "far2.dialog"
local libMessage  = require "far2.message"

local libTmpPanel = require "far2.tmppanel"
libTmpPanel.SetMessageTable(M) -- message localization support

local AssignHotKeys        = libCommon.AssignHotKeys
local Check_F4_On_DI_EDIT  = libCommon.Check_F4_On_DI_EDIT
local CheckMask            = libCommon.CheckMask
local CheckSearchArea      = libCommon.CheckSearchArea
local CreateSRFrame        = libCommon.CreateSRFrame
local DisplayReplaceState  = libCommon.DisplayReplaceState
local DisplaySearchState   = libCommon.DisplaySearchState
local ErrorMsg             = libCommon.ErrorMsg
local FormatTime           = libCommon.FormatTime
local GetReplaceFunction   = libCommon.GetReplaceFunction
local GetSearchAreas       = libCommon.GetSearchAreas
local GotoEditField        = libCommon.GotoEditField
local IndexToSearchArea    = libCommon.IndexToSearchArea
local NewUserBreak         = libCommon.NewUserBreak
local ProcessDialogData    = libCommon.ProcessDialogData
local SaveCodePageCombo    = libCommon.SaveCodePageCombo
local ActivateHighlight    = libEditors.ActivateHighlight
local SetHighlightPattern  = libEditors.SetHighlightPattern

local F = far.Flags
local KEEP_DIALOG_OPEN = 0

local bor, band, bxor, lshift = bit64.bor, bit64.band, bit64.bxor, bit64.lshift
local clock = os.clock
local strbyte, strgsub = string.byte, string.gsub
local Utf16, Utf8 = win.Utf8ToUtf16, win.Utf16ToUtf8
local MultiByteToWideChar = win.MultiByteToWideChar
local WideCharToMultiByte = win.WideCharToMultiByte

local TmpPanelDefaults = {
  CopyContents             = 0,
  ReplaceMode              = true,
  NewPanelForSearchResults = true,
  ColumnTypes              = "NR,S",
  ColumnWidths             = "0,8",
  StatusColumnTypes        = "NR,SC,D,T",
  StatusColumnWidths       = "0,8,0,5",
  FullScreenPanel          = false,
  StartSorting             = "14,0",
  PreserveContents         = true,
}


local function MsgCannotOpenFile (name)
  ErrorMsg(M.MCannotOpenFile.."\n"..name)
end


local function SwapEndian (str)
  return (strgsub(str, "(.)(.)", "%2%1"))
end


local function MaskGenerator (mask, skippath)
  if not CheckMask(mask) then
    return false
  elseif skippath then
    return function(name) return far.ProcessName("PN_CMPNAMELIST", mask, name, "PN_SKIPPATH") end
  else
    return function(name) return far.ProcessName("PN_CMPNAMELIST", mask, name, 0) end
  end
end


-- used code by Kein-Hong Man
-- //this function should move to some library//
local function CheckUtf8 (str)
  local pos, len = 1, 0
  while pos <= #str do
    local ext, c, min
    local v = strbyte(str, pos)
    if v <= 0x7F then ext, c, min = 0, v, 0
    elseif v <= 0xC1 then return false -- bad sequence
    elseif v <= 0xDF then ext, c, min = 1, band(v, 0x1F), 0x80
    elseif v <= 0xEF then ext, c, min = 2, band(v, 0x0F), 0x800
    elseif v <= 0xF4 then ext, c, min = 3, band(v, 0x07), 0x10000
    else return false -- can't fit
    end
    if pos + ext > #str then return false end -- incomplete last character
    pos, len = pos+1, len+1
    -- verify extended sequence
    for _ = 1, ext do
      v = strbyte(str, pos)
      if v < 0x80 or v > 0xBF then return false end -- bad sequence
      c = bor(lshift(c, 6), band(v, 0x3F))
      pos = pos + 1
    end
    if c < min then return false end -- bad sequence
  end
	return len
end


-- Lines iterator: returns a line at a time.
-- When codepage of the file is 1201 (UTF-16BE), the returned lines are encoded
-- in UTF-16LE but the returned EOLs are still in UTF-16BE. This is by design,
-- to minimize number of conversions needed.
-- //this function should move to some library//
local function Lines (aFile, aCodePage, userbreak)
  local aPattern = "([^\r\n]*)(\r?\n?)"
  local BLOCKSIZE = 8*1024
  local start, chunk, posInner, posOuter

  local CHARSIZE, EMPTY, CR, LF, CRLF, find
  if aCodePage == 1200 or aCodePage == 1201 then
    CHARSIZE, EMPTY, CR, LF, CRLF = 2, Utf16"", Utf16"\r", Utf16"\n", Utf16"\r\n"
    find = regex.findW
  else
    CHARSIZE, EMPTY, CR, LF, CRLF = 1, "", "\r", "\n", "\r\n"
    find = string.find
  end

  local read = (aCodePage == 1201) and
    function(size)
      local portion = aFile:read(size)
      if portion then portion = SwapEndian(portion) end
      return portion
    end or
    function(size) return aFile:read(size) end

  return function()
    if start == nil then
      -- first run
      start = 1
      posOuter = aFile:seek("cur")
      chunk = read(BLOCKSIZE) or "" -- default value "" lets us process empty files
      posInner = aFile:seek("cur")
    end

    local line, eol, tb
    aFile:seek("set", posInner)
    while chunk do
      local fr, to
      fr, to, line, eol = find(chunk, aPattern, start)
      if eol ~= EMPTY then
        if eol == CR and to == #chunk/CHARSIZE then
          chunk = read(CHARSIZE)
          if chunk then
            if chunk == LF then
              eol, chunk = CRLF, EMPTY
            end
            start = 1
          end
        else
          start = to + 1
        end
        break
      else
        if userbreak and userbreak:fInterrupt() then
          aFile:seek("set", posOuter)
          return nil
        end
        start, chunk = 1, read(BLOCKSIZE)
        if chunk then
          tb = tb or {}
          tb[#tb+1] = line
        end
      end
    end
    if tb or line then
      if tb then
        tb[#tb+1] = line
        line = table.concat(tb)
      end
      posInner = aFile:seek("cur")
      posOuter = posOuter + #line + #eol
      aFile:seek("set", posOuter)
      if aCodePage == 1201 then eol = SwapEndian(eol) end
      return line, eol
    end
    aFile:seek("set", posOuter)
    return nil
  end
end


local function GetDirFilterFunctions (aData)
  local fDirMask = function() return true end
  local fDirExMask = function() return false end
  if aData.bUseDirFilter then
    local sDirMask, sDirExMask = aData.sDirMask, aData.sDirExMask
    if sDirMask and sDirMask~="" and sDirMask~="*" and sDirMask~="*.*" then
      fDirMask = MaskGenerator(sDirMask, not aData.bDirMask_ProcessPath)
    end
    if sDirExMask and sDirExMask~="" then
      fDirExMask = MaskGenerator(sDirExMask, not aData.bDirExMask_ProcessPath)
    end
  end
  return fDirMask, fDirExMask
end


----------------------------------------------------------------------------------------------------
-- @param InitDir       : starting directory to search its contents recursively
-- @param UserFunc      : function to call when a file/subdirectory is found
-- @param Flags         : table that can have boolean fields 'symlinks' and 'recurse'
-- @param FileFilter    : userdata object having a method 'IsFileInFilter'
-- @param fFileMask     : function that checks the current item's name
-- @param fDirMask      : function that determines whether to search in a given directory
-- @param fDirExMask    : function that determines whether to skip a directory with all its subtree
-- @param tRecurseGuard : table (set) for preventing repeated scanning of the same directories
----------------------------------------------------------------------------------------------------
local FileIterator = _Plugin.Finder.Files
local function RecursiveSearch (sInitDir, UserFunc, Flags, FileFilter,
                                fFileMask, fDirMask, fDirExMask, tRecurseGuard)

  local bSymLinks = Flags and Flags.symlinks
  local bRecurse = Flags and Flags.recurse

  local function Recurse (InitDir)
    local bSearchInThisDir = fDirMask(InitDir)

    local findspec = InitDir:find([[^\\]])
        and InitDir..[[\*]] -- do not prepend \\?\ for a network drive (it will not work)
        or  [[\\?\]]..InitDir..[[\*]]
    local SlashInitDir = InitDir:find("\\$") and InitDir or InitDir.."\\"

    for fdata, hndl in FileIterator(findspec) do
      if fdata.FileName ~= "." and fdata.FileName ~= ".." then
        local fullname = SlashInitDir .. fdata.FileName
        if not FileFilter or FileFilter:IsFileInFilter(fdata) then
          local param = bSearchInThisDir and fFileMask(fdata.FileName) and fdata or "display_state"
          if UserFunc(param,fullname) == "break" then
            hndl:FindClose(); return true
          end
          if bRecurse and fdata.FileAttributes:find("d") and not fDirExMask(fullname) then
            local realDir = far.GetReparsePointInfo(fullname) or fullname
            if not tRecurseGuard[realDir] then
              if bSymLinks or not fdata.FileAttributes:find("e") then
                tRecurseGuard[realDir] = true
                if Recurse(realDir) then
                  hndl:FindClose(); return true
                end
              end
            end
          end
        else
          if UserFunc("display_state",fullname) == "break" then
            hndl:FindClose(); return true
          end
        end
      end
    end
    return false
  end

  local realDir = far.GetReparsePointInfo(sInitDir) or sInitDir
  tRecurseGuard[realDir] = true
  Recurse(realDir)
end


local BomPatterns = {
  ["^\255\254"] = 1200,
  ["^\254\255"] = 1201,
  ["^\239\187\191"] = 65001,
  ["^%+/v[89+/]"] = 65000,
}

local function GetFileFormat (file, nBytes)
  -- Try BOMs
  file:seek("set", 0)
  local sTemp = file:read(8)
  if sTemp then
    for pattern, codepage in pairs(BomPatterns) do
      local bom = string.match(sTemp, pattern)
      if bom then
        file:seek("set", #bom)
        return codepage, bom
      end
    end
  end

  -- Try IsTextUnicode()
  local nCodePage
  file:seek("set", 0)
  local Buffer = file:read(nBytes or 0x8000)
  file:seek("set", 0)
  if Buffer and #Buffer >= 2 then
    local FF = libUCD.GetFlags()
    local tests = bor(
      FF.ASCII16,    FF.REVERSE_ASCII16,
      FF.STATISTICS, FF.REVERSE_STATISTICS,
      FF.CONTROLS, FF.REVERSE_CONTROLS,
      FF.ILLEGAL_CHARS, FF.ODD_LENGTH, FF.NULL_BYTES)
    local _, fl = libUCD.IsTextUnicode(Buffer, tests)
    if fl.ASCII16 then
      nCodePage = 1200
    elseif fl.REVERSE_ASCII16 then
      nCodePage = 1201
    elseif not (fl.ODD_LENGTH or fl.ILLEGAL_CHARS) then
      if (fl.NULL_BYTES or fl.CONTROLS) and fl.STATISTICS then
        nCodePage = 1200
      elseif (fl.NULL_BYTES or fl.REVERSE_CONTROLS) and fl.REVERSE_STATISTICS then
        nCodePage = 1201
      end
    end

    -- Try UCD
    if not nCodePage then
      local ns = libUCD.NewDetector()
      ns:HandleData(Buffer)
      ns:DataEnd()
      nCodePage = ns:GetCodePage()
      ns:Close()
    end
  end

  return nCodePage, nil
end

local CfgGuid = win.Uuid("9888a43b-9e55-4022-9c57-d9213c06167d")

local function ConfigDialog()
  local Data = _Plugin.History:field("tmppanel")
  local WIDTH, HEIGHT = 78, 13
  local DC = math.floor(WIDTH/2-1)

  local Dlg = libDialog.NewDialog()
  Dlg._                  = {"DI_DOUBLEBOX", 3,1,WIDTH-4,HEIGHT-2, 0,0,0,0,M.MConfigTitleTmpPanel}
  Dlg._                  = {"DI_TEXT",    5, 2, 0,0,  0,0,0,0,M.MColumnTypes}
  Dlg.ColumnTypes        = {"DI_EDIT",    5, 3,36,3,  0,0,0,0,""}
  Dlg._                  = {"DI_TEXT",    5, 4, 0,0,  0,0,0,0,M.MColumnWidths}
  Dlg.ColumnWidths       = {"DI_EDIT",    5, 5,36,5,  0,0,0,0,""}
  Dlg._                  = {"DI_TEXT",    5, 6, 0,0,  0,0,0,0,M.MStartSorting}
  Dlg.StartSorting       = {"DI_EDIT",    5, 7,36,5,  0,0,0,0,""}
  Dlg._                  = {"DI_TEXT",   DC, 2, 0,0,  0,0,0,0,M.MStatusColumnTypes}
  Dlg.StatusColumnTypes  = {"DI_EDIT",   DC, 3,72,3,  0,0,0,0,""}
  Dlg._                  = {"DI_TEXT",   DC, 4, 0,0,  0,0,0,0,M.MStatusColumnWidths}
  Dlg.StatusColumnWidths = {"DI_EDIT",   DC, 5,72,5,  0,0,0,0,""}
  Dlg.FullScreenPanel    = {"DI_CHECKBOX",DC,7, 0,0,  0,0,0,0,M.MFullScreenPanel}
  Dlg.PreserveContents   = {"DI_CHECKBOX",DC,8, 0,0,  0,0,0,0,M.MPreserveContents}
  Dlg._                  = {"DI_TEXT",    5, 9, 0,0,  0,0,0,{DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  Dlg.btnOk              = {"DI_BUTTON",  0,10, 0,0,  0,0,0,{DIF_CENTERGROUP=1,DIF_DEFAULTBUTTON=1}, M.MOk}
  Dlg.btnCancel          = {"DI_BUTTON",  0,10, 0,0,  0,0,0,"DIF_CENTERGROUP", M.MCancel}
  Dlg.btnDefaults        = {"DI_BUTTON",  0,10, 0,0,  0,0,0,{DIF_CENTERGROUP=1,DIF_BTNNOCLOSE=1}, M.MBtnDefaults}

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == Dlg.btnDefaults.id then
        libDialog.LoadDataDyn (hDlg, Dlg, TmpPanelDefaults)
      end
    end
  end

  libDialog.LoadData (Dlg, Data)
  local ret = far.Dialog(CfgGuid, -1, -1, WIDTH, HEIGHT, "SearchResultsPanel", Dlg, 0, DlgProc)
  if ret == Dlg.btnOk.id then
    libDialog.SaveData (Dlg, Data)
    if not Data.PreserveContents then
      _Plugin.FileList = nil
    end
    _Plugin.History:save()
    return true
  end
end
libTmpPanel.Panel.AS_F9 = ConfigDialog


local function GetCodePages (aData)
  local Checked = {}
  if aData.tCheckedCodePages then
    for _,v in ipairs(aData.tCheckedCodePages) do Checked[v]=true end
  end
  local delim = ("").char(9474)
  local function makeline(codepage, name)
    return ("%5d %s %s"):format(codepage, delim, name)
  end
  local function split_cpname (cpname)
    local cp, text = cpname:match("^(%d+)%s+%((.+)%)$")
    if cp then return tonumber(cp), text end
  end

  local items = {
    SelectIndex = 1,
    { Text = M.MDefaultCodePages, CodePage = -1 },
    { Text = M.MCheckedCodePages, CodePage = -2 },
    ---------------------------------------------------------------------------
    { Text = M.MSystemCodePages,  Flags = F.LIF_SEPARATOR },
    { CodePage = win.GetOEMCP() },
    { CodePage = win.GetACP() },
    ---------------------------------------------------------------------------
    { Text = M.MUnicodeCodePages, Flags = F.LIF_SEPARATOR },
    { CodePage = 1200, Text = makeline(1200, "UTF-16 (Little endian)") },
    { CodePage = 1201, Text = makeline(1201, "UTF-16 (Big endian)") },
    { CodePage = 65000 },
    { CodePage = 65001 },
    ---------------------------------------------------------------------------
    { Text = M.MOtherCodePages,   Flags = F.LIF_SEPARATOR },
  }

  -- Fill predefined code pages
  local used = {}
  for _,v in ipairs(items) do
    if v.CodePage then
      used[v.CodePage] = true
      local info = win.GetCPInfo(v.CodePage)
      if info then
        local num, name = split_cpname(info.CodePageName)
        if num then v.Text = makeline(num, name) end
      end
      if Checked[v.CodePage] then v.Flags = bor(v.Flags or 0, F.LIF_CHECKED) end
      if v.CodePage == aData.iSelectedCodePage then
        v.Flags = bor(v.Flags or 0, F.LIF_SELECTED)
        items.SelectIndex = nil
      end
    end
  end

  -- Add code pages found in the system
  local pages = assert(win.EnumSystemCodePages())
  for i,v in ipairs(pages) do pages[i]=tonumber(v) end
  table.sort(pages)
  for _,v in ipairs(pages) do
    if not used[v] then
      local info = win.GetCPInfo(v)
      if info and info.MaxCharSize == 1 then
        local num, name = split_cpname(info.CodePageName)
        if num then
          local item = { Text=makeline(num, name), CodePage=v }
          items[#items+1] = item
          if Checked[v] then
            item.Flags = bor(item.Flags or 0, F.LIF_CHECKED)
          end
          if v == aData.iSelectedCodePage then
            item.Flags = bor(item.Flags or 0, F.LIF_SELECTED)
            items.SelectIndex = nil
          end
        end
      end
    end
  end

  return items
end


local function DirectoryFilterDialog (aData)
  local Guid = win.Uuid("276DAB4E-8D58-487D-A3FF-E99681B38C1B")
  local Dlg = libDialog.NewDialog()

  Dlg.frame                  = {"DI_DOUBLEBOX", 3, 1,72,12,   0, 0, 0, 0, M.MDirFilterTitle}
  Dlg.lab                    = {"DI_TEXT",      5, 2, 0, 0,   0, 0, 0, 0, M.MDlgDirMask}
  Dlg.sDirMask               = {"DI_EDIT",      5, 3,70, 0,   0, "DirMasks", 0, F.DIF_HISTORY, "", _default=""}
  Dlg.bDirMask_ProcessPath   = {"DI_CHECKBOX",  7, 4, 0, 0,   0, 0, 0, 0, M.MDirFilterProcessPath}
  Dlg.lab                    = {"DI_TEXT",      5, 6, 0, 0,   0, 0, 0, 0, M.MDlgDirExMask}
  Dlg.sDirExMask             = {"DI_EDIT",      5, 7,70, 0,   0, "DirExMasks", 0, F.DIF_HISTORY, "", _default=""}
  Dlg.bDirExMask_ProcessPath = {"DI_CHECKBOX",  7, 8, 0, 0,   0, 0, 0, 0, M.MDirFilterProcessPathEx}
  Dlg.sep                    = {"DI_TEXT",      5,10, 0, 0,   0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  Dlg.btnOk                  = {"DI_BUTTON",    0,11, 0, 0,   0, 0, 0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MOk}
  Dlg.btnCancel              = {"DI_BUTTON",    0,11, 0, 0,   0, 0, 0, "DIF_CENTERGROUP", M.MCancel}
  ----------------------------------------------------------------------------

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_CLOSE and param1 == Dlg.btnOk.id then
      local mask1 = Dlg.sDirMask:GetText(hDlg) -- this mask is allowed to be empty
      if not (mask1 == "" or CheckMask(mask1)) then
        GotoEditField(hDlg, Dlg.sDirMask.id)
        return KEEP_DIALOG_OPEN
      end
      local mask2 = Dlg.sDirExMask:GetText(hDlg) -- this mask is allowed to be empty
      if not (mask2 == "" or CheckMask(mask2)) then
        GotoEditField(hDlg, Dlg.sDirExMask.id)
        return KEEP_DIALOG_OPEN
      end
    end
  end

  libDialog.LoadData(Dlg, aData)
  local ret = far.Dialog(Guid, -1, -1, 76, 14, "DirectoryFilter", Dlg, 0, DlgProc)
  if ret == Dlg.btnOk.id then libDialog.SaveData(Dlg, aData) end
end


local searchGuid  = win.Uuid("3cd8a0bb-8583-4769-bbbc-5b6667d13ef9")
local replaceGuid = win.Uuid("f7118d4a-fbc3-482e-a462-0167df7cc346")
local grepGuid    = win.Uuid("74D7F486-487D-40D0-9B25-B2BB06171D86")

local function PanelDialog (aOp, aData, aScriptCall)
  local sepflags = bor(F.DIF_BOXCOLOR, F.DIF_SEPARATOR)
  local D = libDialog.NewDialog()
  local Frame = CreateSRFrame(D, aData, false, aScriptCall)
  ------------------------------------------------------------------------------
  local title = aOp=="search" and M.MTitleSearch or aOp=="replace" and M.MTitleReplace or M.MTitleGrep
  D.dblbox      = {"DI_DOUBLEBOX",3, 1,72, 0, 0, 0, 0, 0, title}
  local Y = Frame:InsertInDialog(true, 2, aOp)
  ------------------------------------------------------------------------------
  D.sep         = {"DI_TEXT",     5, Y, 0, 0, 0, 0, 0, sepflags, ""}
if aOp == "search" then
  Y = Y + 1
  D.lab         = {"DI_TEXT",     5, Y, 0,0, 0, 0, 0, 0, M.MDlgCodePages}
  Y = Y + 1
  D.cmbCodePage = {"DI_COMBOBOX", 5, Y,70,0, GetCodePages(aData), 0, 0, F.DIF_DROPDOWNLIST, "", _noauto=1}
end
  Y = Y + 1
  D.lab         = {"DI_TEXT",     5, Y, 0,0, 0, 0, 0, 0, M.MDlgSearchArea}
  Y = Y + 1
  D.cmbSearchArea={"DI_COMBOBOX", 5, Y,36,0, GetSearchAreas(aData), 0, 0, F.DIF_DROPDOWNLIST, "", _noauto=1}
if aOp == "search" then
  D.bSearchFolders ={"DI_CHECKBOX",40,Y-1,0,0,  0,0,0,0, M.MDlgSearchFolders}
end
  D.bSearchSymLinks = {"DI_CHECKBOX",40, Y, 0,0,  0,0,0,0, M.MDlgSearchSymLinks}
  Y = Y + 1
  local X1 =  5 + M.MDlgUseDirFilter:gsub("&",""):len() + 5
  local X2 = 40 + M.MDlgUseFileFilter:gsub("&",""):len() + 5
  D.bUseDirFilter  = {"DI_CHECKBOX", 5, Y, 0,0,  0,0,0,0, M.MDlgUseDirFilter}
  D.btnDirFilter   = {"DI_BUTTON",  X1, Y, 0,0,  0,0,0,F.DIF_BTNNOCLOSE, M.MDlgBtnDirFilter}
  D.bUseFileFilter = {"DI_CHECKBOX",40, Y, 0,0,  0,0,0,0, M.MDlgUseFileFilter}
  D.btnFileFilter  = {"DI_BUTTON",  X2, Y, 0,0,  0,0,0,F.DIF_BTNNOCLOSE, M.MDlgBtnFileFilter}
  Y = Y + 1
  D.sep         = {"DI_TEXT",     5, Y, 0,0, 0, 0, 0, sepflags, ""}

if aOp=="replace" then
  local HIST_INITFUNC   = _Plugin.DialogHistoryPath .. "InitFunc"
  local HIST_FINALFUNC  = _Plugin.DialogHistoryPath .. "FinalFunc"
  D.bAdvanced   = {"DI_CHECKBOX", 5, Y+1,  0, 0, 0, 0, 0, 0, M.MDlgAdvanced}
  D.labInitFunc = {"DI_TEXT",     5, Y+2,  0, 0, 0, 0, 0, 0, M.MDlgInitFunc}
  D.sInitFunc   = {"DI_EDIT",     5, Y+3, 36, 0, 0, HIST_INITFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  D.labFinalFunc= {"DI_TEXT",    39, Y+2,  0, 0, 0, 0, 0, 0, M.MDlgFinalFunc}
  D.sFinalFunc  = {"DI_EDIT",    39, Y+3, 70, 0, 0, HIST_FINALFUNC, 0, "DIF_HISTORY", "", F4=".lua"}
  D.sep         = {"DI_TEXT",     5, Y+4,  0, 0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  Y = Y + 4
end

if aOp=="grep" then
  D.bGrepShowLineNumbers = {"DI_CHECKBOX", 5, Y+1,  0, 0, 0, 0, 0, 0, M.MDlgGrepShowLineNumbers}
  D.bGrepHighlight       = {"DI_CHECKBOX", 5, Y+2,  0, 0, 0, 0, 0, 0, M.MDlgGrepHighlight}
  D.bGrepInverseSearch   = {"DI_CHECKBOX", 5, Y+3,  0, 0, 0, 0, 0, 0, M.MDlgGrepInverseSearch}
  D.label                = {"DI_TEXT",    40, Y+1,  0, 0, 0, 0, 0, 0, M.MDlgGrepContextBefore}
  D.sGrepLinesBefore     = {"DI_FIXEDIT", 66, Y+1, 70, 0, 0, 0, "99999", "DIF_MASKEDIT", "0"}
  D.label                = {"DI_TEXT",    40, Y+2,  0, 0, 0, 0, 0, 0, M.MDlgGrepContextAfter}
  D.sGrepLinesAfter      = {"DI_FIXEDIT", 66, Y+2, 70, 0, 0, 0, "99999", "DIF_MASKEDIT", "0"}
  D.sep                  = {"DI_TEXT",     5, Y+4,  0, 0, 0, 0, 0, sepflags, ""}
  Y = Y + 4
end

  local btnNum = 0
  local function NN (str) btnNum=btnNum+1 return "&"..btnNum..str end
  Y = Y + 1
  D.btnOk       = {"DI_BUTTON",   0, Y, 0,0, 0, 0, 0, bor(F.DIF_CENTERGROUP, F.DIF_DEFAULTBUTTON), M.MOk, NoHilite=1}
if aOp == "grep" then
  D.btnCount    = {"DI_BUTTON",   0, Y, 0,0, 0, 0, 0, F.DIF_CENTERGROUP, NN(M.MDlgBtnCount)}
end
  D.btnPresets  = {"DI_BUTTON",   0, Y, 0,0, 0, 0, 0, bor(F.DIF_CENTERGROUP, F.DIF_BTNNOCLOSE), NN(M.MDlgBtnPresets)}
if aOp == "search" then
  D.btnConfig   = {"DI_BUTTON",   0, Y, 0,0, 0, 0, 0, F.DIF_CENTERGROUP, NN(M.MDlgBtnConfig)}
end
  D.btnCancel   = {"DI_BUTTON",   0, Y, 0,0, 0, 0, 0, F.DIF_CENTERGROUP, M.MCancel, NoHilite=1}
  D.dblbox.Y2   = Y+1

  local function DlgProc (hDlg, msg, param1, param2)
    local NeedCallFrame = true
    --------------------------------------------------------------------------------------
    if msg == F.DN_INITDIALOG then
      D.btnDirFilter:Enable(hDlg, D.bUseDirFilter:GetCheck(hDlg))
      D.btnFileFilter:Enable(hDlg, D.bUseFileFilter:GetCheck(hDlg))
      if D.cmbCodePage then
        hDlg:send(F.DM_SETCOMBOBOXEVENT, D.cmbCodePage.id, F.CBET_KEY)
        local t = {}
        for i,v in ipairs(D.cmbCodePage.ListItems) do
          if v.CodePage then
            t.Index, t.Data = i, v.CodePage
            hDlg:send(F.DM_LISTSETDATA, D.cmbCodePage.id, t)
          end
        end
      end
    --------------------------------------------------------------------------------------
    elseif msg == F.DN_CONTROLINPUT or msg == F.DN_INPUT then
      if param2.EventType == F.KEY_EVENT then
        if D.cmbCodePage and param1 == D.cmbCodePage.id then
          local key = far.InputRecordToName(param2)
          if key=="Ins" or key=="Num0" or key=="Space" then
            local pos = D.cmbCodePage:GetListCurPos(hDlg)
            if pos > 2 then -- if not ("Default code pages" or "Checked code pages")
              local item = hDlg:send(F.DM_LISTGETITEM, param1, pos)
              item.Flags = bxor(item.Flags, F.LIF_CHECKED)
              item.Index = pos
              hDlg:send(F.DM_LISTUPDATE, param1, item)
            end
          end
        else
          Check_F4_On_DI_EDIT(D, hDlg, msg, param1, param2)
        end
      end
    --------------------------------------------------------------------------------------
    elseif msg == F.DN_CLOSE then
      if D.btnConfig and param1 == D.btnConfig.id then
        hDlg:send(F.DM_SHOWDIALOG, 0)
        ConfigDialog()
        hDlg:send(F.DM_SHOWDIALOG, 1)
        hDlg:send(F.DM_SETFOCUS, D.btnOk.id)
        return KEEP_DIALOG_OPEN
      end

      local ok_or_count = (D.btnOk and param1==D.btnOk.id) or
                          (D.btnCount and param1==D.btnCount.id)
      if ok_or_count then
        if not CheckMask(D.sFileMask:GetText(hDlg)) then
          GotoEditField(hDlg, D.sFileMask.id)
          return KEEP_DIALOG_OPEN
        end
        if (aOp=="replace" or aOp=="grep") and D.sSearchPat:GetText(hDlg) == "" then
          ErrorMsg(M.MSearchFieldEmpty)
          GotoEditField(hDlg, D.sSearchPat.id)
          return KEEP_DIALOG_OPEN
        end
        aData.sSearchArea = IndexToSearchArea(D.cmbSearchArea:GetListCurPos(hDlg))
        D.bUseDirFilter:SaveCheck(hDlg, aData)
        D.bUseFileFilter:SaveCheck(hDlg, aData)
      end
      -- store selected code pages no matter what user pressed: OK or Esc.
      if D.cmbCodePage then
        SaveCodePageCombo(hDlg, D.cmbCodePage, aData, ok_or_count)
      end
    --------------------------------------------------------------------------------------
    elseif msg==F.DN_BTNCLICK and param1==D.btnPresets.id then
      Frame:DoPresets(hDlg)
      hDlg:send(F.DM_SETFOCUS, D.btnOk.id)
      NeedCallFrame = false
    --------------------------------------------------------------------------------------
    elseif msg==F.DN_BTNCLICK and param1==D.bUseDirFilter.id then
      D.btnDirFilter:Enable(hDlg, D.bUseDirFilter:GetCheck(hDlg))
      NeedCallFrame = false
    --------------------------------------------------------------------------------------
    elseif msg==F.DN_BTNCLICK and param1==D.btnDirFilter.id then
      hDlg:send(F.DM_SHOWDIALOG, 0)
      DirectoryFilterDialog(aData)
      hDlg:send(F.DM_SHOWDIALOG, 1)
      NeedCallFrame = false
    --------------------------------------------------------------------------------------
    elseif msg==F.DN_BTNCLICK and param1==D.bUseFileFilter.id then
      D.btnFileFilter:Enable(hDlg, D.bUseFileFilter:GetCheck(hDlg))
      NeedCallFrame = false
    --------------------------------------------------------------------------------------
    elseif msg==F.DN_BTNCLICK and param1==D.btnFileFilter.id then
      local filter = far.CreateFileFilter(1, "FFT_FINDFILE")
      if filter and filter:OpenFiltersMenu() then aData.FileFilter = filter end
      NeedCallFrame = false
    --------------------------------------------------------------------------------------
    end
    if NeedCallFrame then
      return Frame:DlgProc(hDlg, msg, param1, param2)
    end
  end

  AssignHotKeys(D)
  libDialog.LoadData(D, aData)
  Frame:OnDataLoaded(aData)
  local Guid = aOp=="search" and searchGuid or aOp=="replace" and replaceGuid or grepGuid

  local helpTopic = aOp=="grep" and "PanelGrep" or "OperInPanels"
  local ret = far.Dialog(Guid, -1, -1, 76, Y+3, helpTopic, D, 0, DlgProc)
  if     aOp == "search" then
    return (ret == D.btnOk.id) and Frame.close_params
  elseif aOp == "replace" then
    if ret == D.btnOk.id then return "replace", Frame.close_params; end
  elseif aOp == "grep" then
    if     ret == D.btnOk.id    then return "grep", Frame.close_params
    elseif ret == D.btnCount.id then return "count", Frame.close_params
    end
  end
end


local function MakeItemList (panelInfo, searchArea)
  local itemList, flags = {}, {recurse=true}
  local bRealNames = (band(panelInfo.Flags, F.PFLAGS_REALNAMES) ~= 0)
  local bPlugin = (band(panelInfo.Flags, F.PFLAGS_PLUGIN) ~= 0)
  local sPanelDir = panel.GetPanelDirectory(nil, 1).Name or ""

  if searchArea == "FromCurrFolder" or searchArea == "OnlyCurrFolder" then
    if bRealNames then
      if bPlugin then
        for i=1, panelInfo.ItemsNumber do
          local name = panel.GetPanelItem(nil,1,i).FileName
          if name ~= ".." and name ~= "." then
            itemList[#itemList+1] = name
          end
        end
      else
        itemList[1] = sPanelDir
      end
      if searchArea == "OnlyCurrFolder" then
        flags = {}
      end
    end
  elseif searchArea == "SelectedItems" then
    if bRealNames then
      local curdir_slash = bPlugin and "" or sPanelDir:gsub("\\?$","\\",1)
      for i=1, panelInfo.SelectedItemsNumber do
        local item = panel.GetSelectedPanelItem(nil, 1, i)
        itemList[#itemList+1] = curdir_slash .. item.FileName
      end
    end
  elseif searchArea == "RootFolder" then
    itemList[1] = sPanelDir:sub(1,3)
  elseif searchArea == "NonRemovDrives" or searchArea == "LocalDrives" then
    for _,drive in ipairs(win.GetLogicalDriveStrings()) do
      local tp = win.GetDriveType(drive)
      if searchArea == "NonRemovDrives" then
        if tp=="fixed" then
          itemList[#itemList+1] = drive
        end
      else -- saLocalDrives
        if tp=="fixed" or tp=="removable" or tp=="cdrom" or tp=="ramdisk" then
          itemList[#itemList+1] = drive
        end
      end
    end
  elseif searchArea == "PathFolders" then
    flags = {}
    local path = win.GetEnv("PATH")
    if path then path:gsub("[^;]+", function(c) itemList[#itemList+1]=c end) end
  end

  return itemList, flags
end


local DisplayListState do
  local lastclock = 0
  local WIDTH = 60
  local s = (" "):rep(WIDTH).."\n" -- preserve constant width of the message box
  DisplayListState = function (cnt, userbreak)
    local newclock = far.FarClock()
    if newclock >= lastclock then
      lastclock = newclock + 2e5 -- period = 0.2 sec
      far.Message(s..cnt..M.MPanelFilelistText, M.MPanelFilelistTitle, "")
      return userbreak and userbreak:ConfirmEscape()
    end
  end
end


local function GetActiveCodePages (aData)
  if aData.iSelectedCodePage then
    if aData.iSelectedCodePage > 0 then
      return { aData.iSelectedCodePage }
    elseif aData.iSelectedCodePage == -2 then
      local t = aData.tCheckedCodePages
      if t and t[1] then return t end
    end
  end
  return { win.GetOEMCP(), win.GetACP(), 1200, 1201, 65000, 65001 }
end


local function CheckBoms (str)
  if str then
    local find = string.find
    if find(str, "^\254\255")         then return { 1201  }, 2 -- UTF16BE
    elseif find(str, "^\255\254")     then return { 1200  }, 2 -- UTF16LE
    elseif find(str, "^%+/v[89+/]")   then return { 65000 }, 4 -- UTF7
    elseif find(str, "^\239\187\191") then return { 65001 }, 3 -- UTF8
    end
  end
end


local function SearchFromPanel (aData, aWithDialog, aScriptCall)
  local tParams
  if aWithDialog then
    tParams = PanelDialog("search", aData, aScriptCall)
  else
    tParams = ProcessDialogData(aData, false, false, true)
  end
  if not tParams then return end
  ----------------------------------------------------------------------------
  local fFileMask = MaskGenerator(aData.sFileMask)
  if not fFileMask then return end
  local fDirMask, fDirExMask = GetDirFilterFunctions(aData)
  if not (fDirMask and fDirExMask) then return end
  ----------------------------------------------------------------------------
  local activeCodePages = GetActiveCodePages(aData)
  local userbreak = NewUserBreak()
  local tFoundFiles, nTotalFiles = {}, 0
  local Regex = tParams.Regex
  local Find = Regex.findW or Regex.find
  local bTextSearch = (tParams.tMultiPatterns and tParams.tMultiPatterns.NumPatterns > 0) or
                      (not tParams.tMultiPatterns and tParams.sSearchPat ~= "")
  local bNoTextSearch = not bTextSearch
  local bNoFolders = bTextSearch or not aData.bSearchFolders
  local reader = bTextSearch and assert(libReader.new(4*1024*1024)) -- (default = 4 MiB)

  local function Search_ProcessFile (fdata, fullname)
    if fdata == "display_state" then
      return DisplaySearchState(fullname, #tFoundFiles, nTotalFiles, 0, userbreak) and "break"
    end
    ---------------------------------------------------------------------------
    local isFolder = fdata.FileAttributes:find("d")
    if isFolder and bNoFolders then return end
    ---------------------------------------------------------------------------
    nTotalFiles = nTotalFiles + 1
    if isFolder or bNoTextSearch then
      tFoundFiles[#tFoundFiles+1] = fullname
      return DisplaySearchState(fullname, #tFoundFiles, nTotalFiles, 0, userbreak) and "break"
    end
    if DisplaySearchState(fullname, #tFoundFiles, nTotalFiles, 0, userbreak) then
      return "break"
    end
    ---------------------------------------------------------------------------
    if not reader:openfile(Utf16(fullname)) then return end
    local str = reader:get_next_overlapped_chunk()
    local currCodePages, len = CheckBoms(str)
    if currCodePages then
      str = string.sub(str, len+1)
    else
      currCodePages = activeCodePages
    end

    local found, stop
    local tPlus, uMinus, uUsual
    if tParams.tMultiPatterns then
      local t = tParams.tMultiPatterns
      uMinus, uUsual = t.Minus, t.Usual -- copy; do not modify the original table fields!
      tPlus = {}; for k,v in pairs(t.Plus) do tPlus[k]=v end -- copy; do not use the original table directly!
    end

    while str do
      if userbreak:ConfirmEscape("in_file") then
        reader:closefile()
        return userbreak.fullcancel and "break"
      end
      for _, cp in ipairs(currCodePages) do
        local s = (cp == 1200 or cp == 65001) and str or
                  (cp == 1201) and SwapEndian(str) or
                  MultiByteToWideChar(str, cp)
        if s then
          if Regex.ufindW then
            if cp == 65001 then s = win.Utf8ToUtf16(s) end
          else
            if cp ~= 65001 then s = win.Utf16ToUtf8(s) end
          end
          if s then
            if tPlus == nil then
              local ok, start = pcall(Find, Regex, s)
              if ok and start then found = true; break; end
            else
              if uMinus and Find(uMinus, s) then
                stop=true; break
              end
              for pattern in pairs(tPlus) do
                if Find(pattern, s) then tPlus[pattern]=nil end
              end
              if uUsual and Find(uUsual, s) then
                uUsual = nil
              end
              if not (next(tPlus) or uMinus or uUsual) then
                found=true; break
              end
            end
          end
        end
      end
      if found or stop then
        break
      end
      if fdata.FileSize >= 0x100000 then
        local pos = reader:ftell()
        DisplaySearchState(fullname, #tFoundFiles, nTotalFiles, pos/fdata.FileSize)
      end
      if #str > 0x100000 then
        str = nil; collectgarbage("collect")
      end
      str = reader:get_next_overlapped_chunk()
    end
    if tPlus then
      found = found or not (stop or next(tPlus) or uUsual)
    end
    if not found ~= not tParams.bInverseSearch then
      tFoundFiles[#tFoundFiles+1] = fullname
    end
    reader:closefile()
  end

  local area = CheckSearchArea(aData.sSearchArea) -- can throw error
  local hScreen = far.SaveScreen()
  DisplaySearchState("", 0, 0, 0)
--local t1=os.clock()

  do -- was: "Search_ProcessAllItems (aData, userbreak, Search_ProcessFile)"
    local FileFilter = tParams.FileFilter
    if FileFilter then FileFilter:StartingToFilter() end
    local panelInfo = panel.GetPanelInfo(nil, 1)
    local bPlugin = (band(panelInfo.Flags, F.PFLAGS_PLUGIN) ~= 0)
    local itemList, flags = MakeItemList(panelInfo, area)
    if aData.bSearchSymLinks then
      flags.symlinks = true
    end

    local tRecurseGuard = {}
    for _, item in ipairs(itemList) do
      local filedata = win.GetFileInfo(item)
      -- note: filedata can be nil for root directories
      local isFile = filedata and not filedata.FileAttributes:find("d")
      ---------------------------------------------------------------------------
      if isFile or ((area == "FromCurrFolder" or area == "OnlyCurrFolder") and bPlugin and filedata) then
        if not FileFilter or FileFilter:IsFileInFilter(filedata) then
          if fFileMask(filedata.FileName) then
            Search_ProcessFile(filedata, item)
          end
        end
      end
      if not isFile and not (area == "OnlyCurrFolder" and bPlugin) then
        RecursiveSearch(item, Search_ProcessFile, flags, FileFilter, fFileMask, fDirMask,
                        fDirExMask, tRecurseGuard)
      end
      ---------------------------------------------------------------------------
      if userbreak.fullcancel then break end
    end
  end

  far.RestoreScreen(hScreen)
  if tFoundFiles[1] then
    far.Message(M.MFilesFound..#tFoundFiles.."/"..nTotalFiles, M.MSearchIsOver, "")
  end
  if reader then reader:delete() end
--far.Message(os.clock()-t1)
  far.AdvControl("ACTL_REDRAWALL")
  return tFoundFiles, userbreak.fullcancel
end


local function CreateTmpPanel (tFileList, tData)
  tFileList = tFileList or {}
  local t = {}
  t.Opt = setmetatable({}, { __index=tData or TmpPanelDefaults })
  t.Opt.CommonPanel = false
  t.Opt.Mask = "*.temp" -- make possible to reopen saved panels with the standard TmpPanel plugin
  local env = libTmpPanel.NewEnv(t)
  local panel = env:NewPanel()
  panel:ReplaceFiles(tFileList)
  return panel
end


local function CollectAllItems (aData, tParams, fFileMask, fDirMask, fDirExMask, userbreak)
  local FileFilter = tParams.FileFilter
  if FileFilter then FileFilter:StartingToFilter() end

  local panelInfo = panel.GetPanelInfo(nil, 1)
  local bPlugin = (band(panelInfo.Flags, F.PFLAGS_PLUGIN) ~= 0)
  local area = CheckSearchArea(aData.sSearchArea)
  local itemList, flags = MakeItemList(panelInfo, area)
  if aData.bSearchSymLinks then
    flags.symlinks = true
  end

  local fileList = {}
  local tRecurseGuard = {}
  DisplayListState(0)
  for _, item in ipairs(itemList) do
    local filedata = win.GetFileInfo(item)
    -- note: filedata can be nil for root directories
    local isFile = filedata and not filedata.FileAttributes:find("d")
    ---------------------------------------------------------------------------
    if isFile or ((area == "FromCurrFolder" or area == "OnlyCurrFolder") and bPlugin) then
      fileList[#fileList+1] = filedata
      fileList[#fileList+1] = item
    end
    if not isFile and not (area == "OnlyCurrFolder" and bPlugin) then
      RecursiveSearch(item,
        function(fdata, fullname)
          if fdata == "display_state" then
            return DisplayListState(#fileList/2, userbreak)
          end
          if not fdata.FileAttributes:find("d") then
            local n = #fileList
            fileList[n+1] = fdata
            fileList[n+2] = fullname
            if n%20 == 0 then
              if DisplayListState(n/2, userbreak) then return "break"; end
            end
          end
        end, flags, FileFilter, fFileMask, fDirMask, fDirExMask, tRecurseGuard)
    end
    if userbreak.fullcancel then break end
  end
  return fileList
end


local function Replace_CreateOutputFile (fullname, numlines, codepage, bom, userbreak)
  local fOut, tmpname
  for k = 0,999 do
    local name = ("%s.%03d.tmp"):format(fullname, k)
    if win.GetFileAttr(name) == nil then tmpname=name; break; end
  end
  if tmpname ~= nil then
    if numlines <= 0 then
      fOut = io.open(tmpname, "wb")
      if bom then fOut:write(bom) end
    else
      local fIn = io.open(fullname, "rb")
      if fIn then
        fOut = io.open(tmpname, "wb")
        if fOut then
          if bom then
            fIn:seek("set", #bom)
            fOut:write(bom)
          end
          for line, eol in Lines(fIn, codepage, userbreak) do
            if codepage == 1201 then line = SwapEndian(line) end
            fOut:write(line, eol)
            numlines = numlines - 1
            if numlines == 0 then break end
          end
        end
        fIn:close()
      end
    end
  end
  return fOut, tmpname
end


-- Note: function MultiByteToWideChar, in Windows older than Vista, does not
--       check UTF-8 characters reliably. That is the reason for using
--       function CheckUtf8.
local function Replace_GetConvertors (bWideCharRegex, nCodePage)
  local Identical = function(str) return str end
  local Convert, Reconvert
  if bWideCharRegex then
    if nCodePage == 1200 then
      Convert, Reconvert = Identical, Identical
    elseif nCodePage == 1201 then
      Convert, Reconvert = Identical, SwapEndian
    else
      if nCodePage == 65001 then
        Convert = function(str) return CheckUtf8(str) and MultiByteToWideChar(str, nCodePage, "e") end
      else
        Convert = function(str) return MultiByteToWideChar(str, nCodePage, "e") end
      end
      Reconvert = function(str) return (WideCharToMultiByte(str, nCodePage)) end
    end
  else
    if nCodePage == 65001 then
      Convert = function(str) return CheckUtf8(str) and str end
      Reconvert = Identical
    elseif nCodePage == 1200 then
      Convert, Reconvert = Utf8, Utf16
    elseif nCodePage == 1201 then
      Convert = Utf8
      Reconvert = function(str) return SwapEndian(Utf16(str)) end
    else
      Convert = function(str) local s=MultiByteToWideChar(str, nCodePage, "e");return s and Utf8(s);end
      Reconvert = function(str) return (WideCharToMultiByte(Utf16(str), nCodePage)) end
    end
  end
  return Convert, Reconvert
end


-- return the entire file contents
local function Lines2 (fp, nCodePage, userbreak)
  local t, n = {}, 0
  return function()
    if t == nil then
      return nil
    end
    while true do
      if userbreak and userbreak:fInterrupt() then
        t = nil; return nil
      end
      local s = fp:read(0x4000) -- 16 KiB
      if not s then
        break
      end
      n = n + 1
      t[n] = s
    end
    local contents = table.concat(t)
    local eol = (nCodePage==1200 or nCodePage==1201) and Utf16("") or ""
    t = nil
    return contents, eol
  end
end


-- ??? All arguments must be in UTF-8.
local function GetReplaceChoice(
  Line, from, to,
  sReplace,
  bWideCharRegex,
  filename,
  numline,
  nCodePageDetected,
  nCodePage
)
  local bReplace = sReplace~=true
  local len, sub
  if bWideCharRegex then len, sub = win.lenW, win.subW
  else len, sub = string.len, string.sub
  end

  local linelen = len(Line)
  local color = libMessage.GetInvertedColor("COL_DIALOGTEXT")

  -- show some context around the match
  local left, right = 0, 0
  local maxchars = libMessage.GetMaxChars()
  local extra = maxchars - (to-from+1)
  if extra > 0 then
    left = math.ceil(extra / 2)
    right = extra - left
    if from-left < 1 then
      left = from - 1
      right = extra - left
    elseif to+right > linelen then
      right = linelen - to
      left = extra - right
      if from-left < 1 then left = from - 1 end
    end
  end
  --================================================================
  local currclock = clock()
  local extract = bWideCharRegex and
    function(i1,i2) return Utf8(sub(Line,i1,i2)) end or
    function(i1,i2) return sub(Line,i1,i2) end

  local callback = function (heights, maxlines, lines)
    if lines <= maxlines then return end
    local avail = maxlines
    for i,h in ipairs(heights) do
      if i~=9 and i~=13 then avail = avail-h end
    end
    avail = avail + 1 -- compensate for newline heights[11]
    local half = math.floor(avail / 2)
    if heights[9] <= half then
      heights[13] = avail - (heights[9] + 2)
    elseif heights[13] <= half then
      heights[9] = avail - (heights[13] + 2)
    else
      heights[9], heights[13] = half - 1, avail - half - 1
    end
    return true
  end

  local msg = {
      filename,"\n",
      ("%s:%d, %s:%d, %s:%d"):format(M.MPanelUC_Line, numline,
          M.MPanelUC_Position, from, M.MPanelUC_Length, to-from+1),"\n",
      M.MPanelUC_Codepage:format(nCodePageDetected or M.MPanelUC_NoCodepage, nCodePage),"\n",
      { separator=1, text=bReplace and M.MUserChoiceReplace or M.MUserChoiceDeleteLine},
      extract(from-left, from-1), {text=extract(from,to), color=color}, extract(to+1, to+right),
      bReplace and "\n" or nil,
      bReplace and { separator=1, text=M.MUserChoiceWith } or nil,
      bReplace and { text=bWideCharRegex and Utf8(sReplace) or sReplace, color=color } or nil,
      callback = callback,
  }

  local Choice = libMessage.Message(
    msg,
    M.MMenuTitle,
    bReplace and M.MPanelUC_Buttons or M.MPanelUC_Buttons2,
    "cl",         -- flags
    nil,          -- help topic
    win.Uuid("f93c6128-52b7-4173-9779-55bf84dd133d") -- id
  )
  Choice = ({"yes","fAll","all","no","fCancel","cancel"})[Choice] or "cancel"
  return Choice, clock() - currclock
end


local function Replace_ProcessFile (fdata, fullname, cdata)
  local ExtendedName = [[\\?\]] .. fullname
  local fp = io.open(ExtendedName, "rb")
  if not fp then
    MsgCannotOpenFile(fullname)
    return
  end
  cdata.nFilesProcessed = cdata.nFilesProcessed + 1
  ---------------------------------------------------------------------------
  local nCodePageDetected, sBom = GetFileFormat(fp)
  local nCodePage = nCodePageDetected or win.GetACP() -- GetOEMCP() ?
  ---------------------------------------------------------------------------
  local fReplace = cdata.fReplace
  local fChoice = cdata.fUserChoiceFunc or GetReplaceChoice
  local bWideCharRegex, Regex, ufind_method = cdata.bWideCharRegex, cdata.Regex, cdata.ufind_method
  local bReplaceAll, userbreak = cdata.bReplaceAll, cdata.userbreak
  local bSkipAll = false
  local fout, tmpname
  local nMatches, nReps = 0, 0
  local numline = 0

  local len, sub
  if bWideCharRegex then len, sub = win.lenW, win.subW
  else len, sub = string.len, string.sub
  end

  local Convert, Reconvert = Replace_GetConvertors (bWideCharRegex, nCodePage)
  local lines_iter = --[[cdata.bFileAsLine and Lines2 or]] Lines
  for line, eol in lines_iter(fp, nCodePage, userbreak) do
    if bSkipAll then
      fout:write(line, eol)
    else
      numline = numline + 1
      -------------------------------------------------------------------------
      local Line = Convert(line)
      if not Line then
        if fout then fout:write(line, eol) end
      else
        -- iterate on current line
        local x = 1
        local linelen = len(Line)
        local bDeleteLine
        while true do
          local fr, to, collect = ufind_method(Regex, Line, x)
          if not fr then break end
          nMatches = nMatches + 1
          -----------------------------------------------------------------------
          local sCurMatch = sub(Line, fr, to)
          collect[0] = sCurMatch
          local ok, sRepFinal, bStop = pcall(fReplace, collect, nMatches, nReps, numline)
          bSkipAll = bStop and bReplaceAll
          if not ok then
            fp:close()
            if fout then
              fout:close()
              win.DeleteFile(tmpname)
            end
            cdata.bWasError = true
            ErrorMsg(sRepFinal)
            return
          end
          if sRepFinal then
            local sUserChoice, nElapsed
            if not bReplaceAll then
              sUserChoice, nElapsed = fChoice(
                  Line, fr, to, sRepFinal, bWideCharRegex, fullname,
                  numline, nCodePageDetected, nCodePage)
              cdata.last_clock = cdata.last_clock + (nElapsed or 0)
              if     sUserChoice == "yes"     then -- do nothing
              elseif sUserChoice == "fAll"    then bReplaceAll = true
              elseif sUserChoice == "all"     then bReplaceAll,cdata.bReplaceAll = true,true
              elseif sUserChoice == "no"      then -- do nothing                        -- "skip"
              elseif sUserChoice == "fCancel" then bSkipAll = true                      -- "skip in this file"
              else                            bSkipAll,userbreak.fullcancel = true,true -- "cancel"
              end
            end
            ----------------------------------------------------------------------
            if bReplaceAll or sUserChoice=="yes" then
              nReps = nReps + 1
              bDeleteLine = sRepFinal==true
              if not fout then
                fout, tmpname = Replace_CreateOutputFile(ExtendedName, numline-1, nCodePage, sBom, userbreak)
                if not fout or userbreak.cancel then
                  cdata.nMatchesTotal = cdata.nMatchesTotal + nMatches
                  cdata.nFilesWithMatches = cdata.nFilesWithMatches + 1
                  fp:close()
                  if fout then
                    fout:close()
                    win.DeleteFile(tmpname)
                  end
                  ErrorMsg(M.MErrorCreateOutputFile)
                  return
                end
                if not bDeleteLine then
                  fout:write(Reconvert(sub(Line, 1, x-1)))
                end
              end
              if bDeleteLine then break end
              fout:write(Reconvert(sub(Line, x, fr-1)), Reconvert(sRepFinal))
            else
              if fout then fout:write(Reconvert(sub(Line, x, fr-1)), Reconvert(sCurMatch)) end
            end
          else -- if not sRepFinal:
            if fout then fout:write(Reconvert(sub(Line, x, fr-1)), Reconvert(sCurMatch)) end
          end
          ----------------------------------------------------------------------
          if to >= x then
            x = to + 1
          else
            if fout then fout:write(Reconvert(sub(Line, x, x))) end
            x = x + 1
          end
          ----------------------------------------------------------------------
          if x > linelen then break end
          if bSkipAll then break end
        end -- iterate on current line
        if fout then
          if not bDeleteLine then
            fout:write(Reconvert(sub(Line, x)), eol)
          end
        else
          if bSkipAll then break end
        end
      end -- if Line
    end -- if not bSkipAll
    if fdata.FileSize >= 1e6 and numline%100 == 0 then
      local pos = fp:seek("cur")
      DisplayReplaceState(fullname, cdata.nFilesProcessed-1, pos/fdata.FileSize)
    end
  end -- for line, eol in lines_iter(...)
  if nMatches > 0 then
    cdata.nMatchesTotal = cdata.nMatchesTotal + nMatches
    cdata.nFilesWithMatches = cdata.nFilesWithMatches + 1
  end
  fp:close()
  if fout then
    fout:close()
    if userbreak.cancel then
      win.DeleteFile(tmpname)
    else
      if cdata.bMakeBackupCopy then
        local name, num = regex.match(ExtendedName, [[^(.*)\.(\d+)\.bak$]], nil, "i")
        if not name then name, num = ExtendedName, 0 end
        num = tonumber(num)
        for k = num+1, 999 do
          local bakname = ("%s.%03d.bak"):format(name, k)
          if win.RenameFile(ExtendedName, bakname) then break end
        end
      else
        win.SetFileAttr(ExtendedName, "")
        win.DeleteFile(ExtendedName)
      end
      win.RenameFile(tmpname, ExtendedName)
      win.SetFileAttr(ExtendedName, fdata.FileAttributes)
      cdata.nFilesModified = cdata.nFilesModified + 1
      cdata.nRepsTotal = cdata.nRepsTotal + nReps
    end
  end
end


-- cdata.sOp: operation - either "grep" or "count"
local function Grep_ProcessFile (fdata, fullname, cdata)
  local fp = io.open(fullname,"rb") or io.open([[\\?\]]..fullname,"rb")
  if not fp then
    MsgCannotOpenFile(fullname)
    return
  end
  cdata.nFilesProcessed = cdata.nFilesProcessed + 1
  ---------------------------------------------------------------------------
  local nCodePageDetected = GetFileFormat(fp)
  local nCodePage = nCodePageDetected or win.GetACP() -- GetOEMCP() ?
  ---------------------------------------------------------------------------
  local bWideCharRegex, Regex, ufind_method = cdata.bWideCharRegex, cdata.Regex, cdata.ufind_method
  local userbreak = cdata.userbreak
  local nMatches = 0
  local numline = 0

  local len = bWideCharRegex and win.lenW or string.len
  local grepBefore, grepAfter = cdata.tGrep.nBefore, cdata.tGrep.nAfter
  local grepInverse = not not cdata.tGrep.bInverse -- convert to boolean
  local tGrep, qLinesBefore, numline_match
  if cdata.sOp=="grep" then
    tGrep = { FileName=fullname }
    table.insert(cdata.tGrep, tGrep)
    qLinesBefore = grepBefore > 0 and libCqueue.new(grepBefore)
  end

  local Convert = Replace_GetConvertors (bWideCharRegex, nCodePage)
  local lines_iter = --[[cdata.bFileAsLine and Lines2 or]] Lines
  for line, eol in lines_iter(fp, nCodePage, userbreak) do
    numline = numline + 1
    -------------------------------------------------------------------------
    local Line = Convert(line)
    if Line then
      -- iterate on current line
      local x = 1
      local linelen = len(Line)
      while true do
        local bFound
        local fr, to, collect = ufind_method(Regex, Line, x)
        if fr then
          if not (cdata.sOp == "grep" and cdata.tGrep.bSkip and collect[1]) then
            bFound = true
            nMatches = nMatches+1
          end
        end
        ----------------------------------------------------------------------
        if cdata.sOp == "grep" then
          if (not bFound) == grepInverse then -- 'not' needed for conversion to boolean
            if qLinesBefore then
              local size = qLinesBefore:size()
              for k=1, size do
                tGrep[#tGrep+1] = -(numline - size + k - 1)
                tGrep[#tGrep+1] = qLinesBefore:get(k)
              end
              qLinesBefore:clear()
            end
            numline_match = numline
            tGrep[#tGrep+1] = numline
            tGrep[#tGrep+1] = Line
          else
            if numline_match and numline-numline_match <= grepAfter then
              tGrep[#tGrep+1] = -numline
              tGrep[#tGrep+1] = Line
            elseif qLinesBefore then
              qLinesBefore:push(Line)
            end
          end
          break
        end
        ----------------------------------------------------------------------
        if not fr then break end
        ----------------------------------------------------------------------
        if to >= x then
          x = to + 1
        else
          x = x + 1
        end
        ----------------------------------------------------------------------
        if x > linelen then break end
      end -- iterate on current line
    end -- if Line
    if fdata.FileSize >= 1e6 and numline%100 == 0 then
      local pos = fp:seek("cur")
      DisplayReplaceState(fullname, cdata.nFilesProcessed-1, pos/fdata.FileSize)
    end
  end -- for line, eol in lines_iter(...)
  if nMatches > 0 then
    cdata.nMatchesTotal = cdata.nMatchesTotal + nMatches
    cdata.nFilesWithMatches = cdata.nFilesWithMatches + 1
  end
  fp:close()
end


-- @param aOp: either "replace" or "grep"
local function ReplaceOrGrep (aOp, aData, aWithDialog, aScriptCall)
  local sOp, tParams
  if aWithDialog then
    sOp, tParams = PanelDialog(aOp, aData, aScriptCall)
    if sOp and not aScriptCall then _Plugin.History:save() end
  else
    sOp, tParams = aOp, ProcessDialogData(aData, true, false)
  end
  if not (sOp and tParams) then return end
  ----------------------------------------------------------------------------
  if sOp=="replace" and aData.bAdvanced then tParams.InitFunc() end
  ----------------------------------------------------------------------------
  local fFileMask = MaskGenerator(aData.sFileMask)
  if not fFileMask then return end
  local fDirMask, fDirExMask = GetDirFilterFunctions(aData)
  if not (fDirMask and fDirExMask) then return end
  -----------------------------------------------------------------------------
  -- Collect all items
  -----------------------------------------------------------------------------
  local last_clock = clock()
  local userbreak = NewUserBreak()
  userbreak.time = 0
  local fileList = CollectAllItems(aData, tParams, fFileMask, fDirMask, fDirExMask, userbreak)
  if userbreak.fullcancel then
    far.AdvControl("ACTL_REDRAWALL")
    return ReplaceOrGrep(aOp, aData, aWithDialog, aScriptCall)
  end
  local timeSearch = clock() - last_clock - userbreak.time

  -----------------------------------------------------------------------------
  -- Search and replace in files: prepare data
  -----------------------------------------------------------------------------
  local bWideCharRegex = tParams.Regex.ufindW and true
  local cdata = { -- common data
    bFileAsLine = tParams.bFileAsLine,                                -- in
    bMakeBackupCopy = aData.bMakeBackupCopy,                          -- in
    bReplaceAll = not aData.bConfirmReplace,                          -- in/out
    bWideCharRegex = bWideCharRegex,                                     -- in
    ufind_method = tParams.Regex.ufindW or tParams.Regex.ufind,          -- in
    fReplace = aOp=="replace" and GetReplaceFunction(tParams.ReplacePat, bWideCharRegex), -- in
    nFilesModified = 0,                                                  -- out
    nFilesProcessed = 0,                                                 -- out
    nFilesWithMatches = 0,                                               -- out
    nMatchesTotal = 0,                                                   -- out
    nRepsTotal = 0,                                                      -- out
    sOp = sOp,                                                           -- in
    Regex = tParams.Regex,                                               -- in
    userbreak = userbreak,                                               -- out
    fUserChoiceFunc = aData.fUserChoiceFuncP,                            -- in
    bWasError = false,                                                   -- out
    tGrep = {                                                            -- in/out
      nBefore = tonumber(aData.sGrepLinesBefore) or 0;
      nAfter  = tonumber(aData.sGrepLinesAfter) or 0;
      bInverse = aData.bGrepInverseSearch;
      bSkip = tParams.bSkip;
    },
  }

  -----------------------------------------------------------------------------
  -- Search and replace in files: run
  -----------------------------------------------------------------------------
  cdata.last_clock = clock()
  userbreak.time = 0
  local sProcessReadonly
  DisplayReplaceState("", 0, 0)
  for k=1,#fileList,2 do
    if userbreak:ConfirmEscape() then break end
    local fdata, fullname = fileList[k], fileList[k+1]
    local bCanProcess = true
    if sOp == "replace" and fdata.FileAttributes:find("r") then
      if sProcessReadonly == "none" then
        bCanProcess = false
      elseif sProcessReadonly ~= "all" then
        local currclock = clock()
        local res = far.Message(
          M.MPanelRO_Readonly..fullname..M.MPanelRO_Question,
          M.MWarning, M.MPanelRO_Buttons, "w")
        cdata.last_clock = cdata.last_clock + clock() - currclock
        if res == 1 then -- do nothing
        elseif res == 2 then sProcessReadonly="all"
        elseif res == 3 then bCanProcess=false
        elseif res == 4 then bCanProcess=false; sProcessReadonly="none"
        else                 bCanProcess=false; userbreak.fullcancel=true
        end
      end
    end
    if bCanProcess then
--local n=cdata.nFilesWithMatches
      cdata.userbreak.cancel = nil
      DisplayReplaceState(fullname, cdata.nFilesProcessed, 0)
      if sOp == "replace" then
        Replace_ProcessFile(fdata, fullname, cdata)
      else
        Grep_ProcessFile(fdata, fullname, cdata)
      end
      if cdata.bWasError then break end
--if n==cdata.nFilesWithMatches then far.Message(fullname) end
    end
    if userbreak.fullcancel then break end
  end
  -----------------------------------------------------------------------------
  if sOp=="replace" and aData.bAdvanced then tParams.FinalFunc() end
  -----------------------------------------------------------------------------
  local timeProcess = clock() - cdata.last_clock - userbreak.time
  far.AdvControl("ACTL_REDRAWALL")

  -----------------------------------------------------------------------------
  -- Statistics, etc.
  -----------------------------------------------------------------------------
  if (not aScriptCall) and (sOp=="replace" or sOp=="count") then
    if #fileList > 0 then
      local items = {}
      ----------------------------------------------------------------------------------------------
      table.insert(items, { M.MPanelFin_FilesFound,       #fileList/2 })
      table.insert(items, { M.MPanelFin_FilesProcessed,   cdata.nFilesProcessed })
      table.insert(items, { M.MPanelFin_FilesWithMatches, cdata.nFilesWithMatches })
      if sOp == "replace" then
        table.insert(items, { M.MPanelFin_FilesModified, cdata.nFilesModified })
      end
      table.insert(items, { separator=1 })
      ----------------------------------------------------------------------------------------------
      table.insert(items, { M.MPanelFin_MatchesTotal,     cdata.nMatchesTotal })
      if sOp == "replace" then
        table.insert(items, { M.MPanelFin_RepsTotal, cdata.nRepsTotal })
      end
      table.insert(items, { separator=1 })
      table.insert(items, { M.MPanelFin_TimeSearch,       FormatTime(timeSearch) .. " s" })
      table.insert(items, { M.MPanelFin_TimeProcess,      FormatTime(timeProcess) .. " s" })
      ----------------------------------------------------------------------------------------------
      libMessage.TableBox(items, M.MMenuTitle)
    else
      if userbreak.fullcancel or 1==far.Message(M.MNoFilesFound,M.MMenuTitle,M.MButtonsNewSearch) then
        return ReplaceOrGrep(aOp, aData, aWithDialog, aScriptCall)
      end
    end
  end

  if sOp == "grep" then
    local fp
    local insert_empty_lines = cdata.tGrep.nBefore>0 or cdata.tGrep.nAfter>0
    local fname = far.MkTemp()
    local numfile = 0
    for _,v in ipairs(cdata.tGrep) do
      if v[1] then
        numfile = numfile + 1
        fp = fp or assert(io.open(fname, "wb"))
        fp:write("[", tostring(numfile), "] ", v.FileName, "\r\n")
        local last_numline = -1
        for m=1,#v,2 do
          local lnum, line = v[m], v[m+1]
          local abs_numline = math.abs(lnum)
          if insert_empty_lines then
            if abs_numline - last_numline > 1 then fp:write("\r\n") end
            last_numline = abs_numline
          end
          if aData.bGrepShowLineNumbers then
            fp:write(tostring(abs_numline), lnum>0 and ":" or "-")
          end
          if tParams.Regex.ufindW then line=Utf8(line) end
          fp:write(line, "\r\n")
        end
        fp:write("\r\n")
      end
    end
    if fp then
      fp:close()
      local flags = {EF_DELETEONLYFILEONCLOSE=1,EF_NONMODAL=1,EF_IMMEDIATERETURN=1,EF_DISABLEHISTORY=1}
      if editor.Editor(fname,nil,nil,nil,nil,nil,flags,nil,nil,65001) == F.EEC_MODIFIED then
        if aData.bGrepHighlight then
          SetHighlightPattern(tParams.Regex, true, aData.bGrepShowLineNumbers, tParams.bSkip)
          ActivateHighlight(true)
        end
      end
    else
      if userbreak.fullcancel or 1==far.Message(M.MNoFilesFound,M.MMenuTitle,M.MButtonsNewSearch) then
        return ReplaceOrGrep(aOp, aData, aWithDialog, aScriptCall)
      end
    end
  end
end


local function ReplaceFromPanel (aData, aWithDialog, aScriptCall)
  return ReplaceOrGrep("replace", aData, aWithDialog, aScriptCall)
end


local function GrepFromPanel (aData, aWithDialog, aScriptCall)
  return ReplaceOrGrep("grep", aData, aWithDialog, aScriptCall)
end


local function InitTmpPanel()
  local history = _Plugin.History:field("tmppanel")
  for k,v in pairs(TmpPanelDefaults) do
    if history[k] == nil then history[k] = v end
  end

  libTmpPanel.PutExportedFunctions(export)
  export.SetFindList = nil

  local tpGetOpenPanelInfo = export.GetOpenPanelInfo
  export.GetOpenPanelInfo = function (Panel, Handle)
    local hist = _Plugin.History:field("tmppanel")
    local Info = tpGetOpenPanelInfo (Panel, Handle)
    Info.StartSortMode, Info.StartSortOrder = hist.StartSorting:match("(%d+)%s*,%s*(%d+)")
    for _,mode in pairs(Info.PanelModesArray) do
      mode.Flags.PMFLAGS_FULLSCREEN = hist.FullScreenPanel
    end
    return Info
  end

  export.ClosePanel = function(object, handle)
    local hist = _Plugin.History:field("tmppanel")
    if hist.PreserveContents then
      _Plugin.FileList = object:GetItems()
      _Plugin.FileList.NoDuplicates = true
    else
      _Plugin.FileList = nil
    end
  end
end


return {
  SearchFromPanel   = SearchFromPanel,
  ReplaceFromPanel  = ReplaceFromPanel,
  GrepFromPanel     = GrepFromPanel,
  InitTmpPanel      = InitTmpPanel,
  CreateTmpPanel    = CreateTmpPanel,
  ConfigDialog      = ConfigDialog,
}
