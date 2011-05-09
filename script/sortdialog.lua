--[[
 Goal: sort lines.
 Start: 2008-10-17 by Shmuel Zeigerman
--]]

local Package = {}
local far = far

local far2_dialog = require "far2.dialog"
local F = far.GetFlags()
local M = require "lf4ed_message"

-- {719ca394-ab79-4973-956b-54a1626e6bec}
local dialogGuid = "\148\163\156\113\121\171\115\073\149\107\084\161\098\110\107\236"

function Package.SortDialog (aData, columntype)
  local COLPAT_DEFAULT = "%S+"
  local regpath = "LuaFAR\\SortLines\\"
  local HIST_EXPR     = regpath .. "Expression"
  local HIST_COLPAT   = regpath .. "ColumnPattern"
  local HIST_FILENAME = regpath .. "FileName"
  ------------------------------------------------------------------------------
  local D = far2_dialog.NewDialog()
  D._         = {"DI_DOUBLEBOX",3,1,72,14, 0, 0, 0, 0, M.MSortLines}
  D.labExpr1  = {"DI_TEXT",     5, 2,0,0,  0, 0, 0, 0, M.MExpr1}
  D.edtExpr1  = {"DI_EDIT",    13, 2,69,6, 0, HIST_EXPR, "DIF_HISTORY", 0, ""}
  D.cbxUse1   = {"DI_CHECKBOX",15, 3,0,0,  0, 1, 0, 0, M.MEnable1}
  D.cbxCase1  = {"DI_CHECKBOX",40, 3,0,0,  0, 0, 0, 0, M.MCase1}
  D.cbxRev1   = {"DI_CHECKBOX",58, 3,0,0,  0, 0, 0, 0, M.MReverse1}
  D.labExpr2  = {"DI_TEXT",     5, 4,0,0,  0, 0, 0, 0, M.MExpr2}
  D.edtExpr2  = {"DI_EDIT",    13, 4,69,6, 0, HIST_EXPR, "DIF_HISTORY", 0, ""}
  D.cbxUse2   = {"DI_CHECKBOX",15, 5,0,0,  0, 0, 0, 0, M.MEnable2}
  D.cbxCase2  = {"DI_CHECKBOX",40, 5,0,0,  0, 0, 0, 0, M.MCase2}
  D.cbxRev2   = {"DI_CHECKBOX",58, 5,0,0,  0, 0, 0, 0, M.MReverse2}
  D.labExpr3  = {"DI_TEXT",     5, 6,0,0,  0, 0, 0, 0, M.MExpr3}
  D.edtExpr3  = {"DI_EDIT",    13, 6,69,6, 0, HIST_EXPR, "DIF_HISTORY", 0, ""}
  D.cbxUse3   = {"DI_CHECKBOX",15, 7,0,0,  0, 0, 0, 0, M.MEnable3}
  D.cbxCase3  = {"DI_CHECKBOX",40, 7,0,0,  0, 0, 0, 0, M.MCase3}
  D.cbxRev3   = {"DI_CHECKBOX",58, 7,0,0,  0, 0, 0, 0, M.MReverse3}
  D.sep       = {"DI_TEXT",     5, 8, 0,0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.cbxOnlySel= {"DI_CHECKBOX", 5, 9,0,0,  0, 0, 0, 0, M.MOnlySel}
  D.lab       = {"DI_TEXT",    28, 9,0,0,  0, 0, 0, 0, M.MColPat}
  D.edtColPat = {"DI_EDIT",    44, 9,56,6, 0, HIST_COLPAT, "DIF_HISTORY", 0, COLPAT_DEFAULT}
  D.btnColPat = {"DI_BUTTON",  59, 9, 0,0, 0, 0, "DIF_BTNNOCLOSE", 0, M.MDefault}
  D.sep       = {"DI_TEXT",     5,10, 0,0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.labFileName={"DI_TEXT",     5,11,0,0,  0, 0, 0, 0, M.MFileName}
  D.edtFileName={"DI_EDIT",    21,11,55,6, 0, HIST_FILENAME, "DIF_HISTORY", 0, ""}
  D.cbxFileName={"DI_CHECKBOX",58,11, 0,0, 0, 0, 0, 0, M.MEnable4}
  D.sep       = {"DI_TEXT",     5,12, 0,0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.btnOk     = {"DI_BUTTON",   0,13, 0,0, 0, 0, "DIF_CENTERGROUP", 1, M.MOk}
  D.btnCancel = {"DI_BUTTON",   0,13, 0,0, 0, 0, "DIF_CENTERGROUP", 0, M.MCancel}
  ------------------------------------------------------------------------------
  local function LoadData()
    far2_dialog.LoadData(D, aData)
    if not columntype then
      D.cbxOnlySel.Selected = 0
      D.cbxOnlySel.Flags = F.DIF_DISABLE
    end
    if not aData.cbxUse1 then D.cbxUse1.Focus=1 end -- work around a FAR bug
  end
  ------------------------------------------------------------------------------
  local function SaveData(hDlg)
    for i, v in ipairs(D) do far.GetDlgItem(hDlg, i-1, v) end
    D.cbxOnlySel._noautosave = not columntype
    far2_dialog.SaveData(D, aData)
  end
  ----------------------------------------------------------------------------
  -- Handlers of dialog events --
  local function Check (hDlg, c1, ...)
    local enbl = c1:GetCheck(hDlg)
    for _, elem in ipairs {...} do elem:Enable(hDlg, enbl) end
  end

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      Check (hDlg, D.cbxUse1, D.edtExpr1, D.cbxRev1, D.labExpr1, D.cbxCase1)
      Check (hDlg, D.cbxUse2, D.edtExpr2, D.cbxRev2, D.labExpr2, D.cbxCase2)
      Check (hDlg, D.cbxUse3, D.edtExpr3, D.cbxRev3, D.labExpr3, D.cbxCase3)
      Check (hDlg, D.cbxFileName, D.labFileName, D.edtFileName)
    elseif msg == F.DN_BTNCLICK then
      if param1 == D.cbxUse1.id then Check (hDlg, D.cbxUse1, D.edtExpr1, D.cbxRev1, D.labExpr1, D.cbxCase1)
      elseif param1 == D.cbxUse2.id then Check (hDlg, D.cbxUse2, D.edtExpr2, D.cbxRev2, D.labExpr2, D.cbxCase2)
      elseif param1 == D.cbxUse3.id then Check (hDlg, D.cbxUse3, D.edtExpr3, D.cbxRev3, D.labExpr3, D.cbxCase3)
      elseif param1 == D.cbxFileName.id then Check (hDlg, D.cbxFileName, D.labFileName, D.edtFileName)
      elseif param1 == D.btnColPat.id then
        D.edtColPat.Data = COLPAT_DEFAULT
        far.SetDlgItem (hDlg, D.edtColPat.id, D.edtColPat)
      end
    elseif msg == F.DN_GETDIALOGINFO then
      return dialogGuid
    elseif msg == F.DN_CLOSE then
      SaveData(hDlg)
    end
  end
  ----------------------------------------------------------------------------
  LoadData()
  local ret = far.Dialog (-1,-1,76,16,"SortLines",D,0,DlgProc)
  return (ret == D.btnOk.id)
end

return Package

