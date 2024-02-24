--[[
 Goal: sort lines.
 Start: 2008-10-17 by Shmuel Zeigerman
--]]

-- luacheck: max line length 128

local sd = require "far2.simpledialog"
local M  = require "lf4ed_message"
local F  = far.Flags

local function SortDialog (aData, columntype)
  local COLPAT_DEFAULT = "\\S+"
  local regpath = "LuaFAR\\SortLines\\"
  local HIST_EXPR     = regpath .. "Expression"
  local HIST_COLPAT   = regpath .. "ColumnPattern"
  local HIST_FILENAME = regpath .. "FileName"
  local X1,X2,X3,X4 = 13,15,32,58
  ------------------------------------------------------------------------------
  local Items = {
    guid="719CA394-AB79-4973-956B-54A1626E6BEC";
    width=76;
    help="SortLines";
    {tp="dbox";  text=M.MSortLines},
    {tp="text";  name="labExpr1";               text=M.MExpr1; },
    {tp="edit";  name="edtExpr1"; x1=X1; y1=""; hist=HIST_EXPR},
    {tp="chbox"; name="cbxUse1";  x1=X2;        text=M.MEnable1},
    {tp="chbox"; name="cbxCase1"; x1=X3; y1=""; text=M.MCase1; tristate=1},
    {tp="chbox"; name="cbxRev1";  x1=X4; y1=""; text=M.MReverse1},

    {tp="text";  name="labExpr2";               text=M.MExpr2; },
    {tp="edit";  name="edtExpr2"; x1=X1; y1=""; hist=HIST_EXPR},
    {tp="chbox"; name="cbxUse2";  x1=X2;        text=M.MEnable2},
    {tp="chbox"; name="cbxCase2"; x1=X3; y1=""; text=M.MCase2; tristate=1},
    {tp="chbox"; name="cbxRev2";  x1=X4; y1=""; text=M.MReverse2},

    {tp="text";  name="labExpr3";               text=M.MExpr3; },
    {tp="edit";  name="edtExpr3"; x1=X1; y1=""; hist=HIST_EXPR},
    {tp="chbox"; name="cbxUse3";  x1=X2;        text=M.MEnable3},
    {tp="chbox"; name="cbxCase3"; x1=X3; y1=""; text=M.MCase3; tristate=1},
    {tp="chbox"; name="cbxRev3";  x1=X4; y1=""; text=M.MReverse3},
    {tp="sep"; },
    {tp="chbox"; name="cbxOnlySel"; text=M.MOnlySel; nosave=not columntype; },
    {tp="text";                    x1=28, y1=""; text=M.MColPat},
    {tp="edit";  name="edtColPat"; x1=44, y1=""; x2=56; hist=HIST_COLPAT; text=COLPAT_DEFAULT},
    {tp="butt";  name="btnColPat"; x1=59, y1=""; btnnoclose=1; text=M.MDefault},
    {tp="sep"; },
    {tp="text";  name="labFileName"; text=M.MFileName; },
    {tp="edit";  name="edtFileName"; x1=21; y1=""; x2=55; hist=HIST_FILENAME},
    {tp="chbox"; name="cbxFileName"; x1=58; y1=""; text=M.MEnable4},
    {tp="sep"; },
    {tp="butt";  centergroup=1; text=M.MOk; default=1; },
    {tp="butt";  centergroup=1; text=M.MCancel; cancel=1; },
  }
  local dlg = sd.New(Items)
  local Pos, Elem = dlg:Indexes()
  ------------------------------------------------------------------------------
  local function LoadData()
    dlg:LoadData(aData)
    if not columntype then
      Elem.cbxOnlySel.val = false
      Elem.cbxOnlySel.disable = true
    end
    if not aData.cbxUse1 then Elem.cbxUse1.focus=true end -- work around a FAR bug
  end
  ------------------------------------------------------------------------------
  -- Handlers of dialog events --
  local function Check (hDlg, c1, ...)
    local enbl = hDlg:GetCheck(c1)
    for _, elem in ipairs {...} do hDlg:Enable(elem, enbl) end
  end

  function Items.proc (hDlg, msg, param1, param2)
    if msg == F.DN_INITDIALOG then
      Check(hDlg, Pos.cbxUse1, Pos.edtExpr1, Pos.cbxRev1, Pos.labExpr1, Pos.cbxCase1)
      Check(hDlg, Pos.cbxUse2, Pos.edtExpr2, Pos.cbxRev2, Pos.labExpr2, Pos.cbxCase2)
      Check(hDlg, Pos.cbxUse3, Pos.edtExpr3, Pos.cbxRev3, Pos.labExpr3, Pos.cbxCase3)
      Check(hDlg, Pos.cbxFileName, Pos.labFileName, Pos.edtFileName)
    elseif msg == F.DN_BTNCLICK then
      hDlg:EnableRedraw(0)
      if     param1 == Pos.cbxUse1     then Check(hDlg, Pos.cbxUse1, Pos.edtExpr1, Pos.cbxRev1, Pos.labExpr1, Pos.cbxCase1)
      elseif param1 == Pos.cbxUse2     then Check(hDlg, Pos.cbxUse2, Pos.edtExpr2, Pos.cbxRev2, Pos.labExpr2, Pos.cbxCase2)
      elseif param1 == Pos.cbxUse3     then Check(hDlg, Pos.cbxUse3, Pos.edtExpr3, Pos.cbxRev3, Pos.labExpr3, Pos.cbxCase3)
      elseif param1 == Pos.cbxFileName then Check(hDlg, Pos.cbxFileName, Pos.labFileName, Pos.edtFileName)
      elseif param1 == Pos.btnColPat   then hDlg:SetText(Pos.edtColPat, COLPAT_DEFAULT) end
      hDlg:EnableRedraw(1)
    end
  end
  ----------------------------------------------------------------------------
  LoadData()
  local out = dlg:Run()
  if out then
    dlg:SaveData(out, aData)
    return true
  end
end

return {
  SortDialog = SortDialog;
}
