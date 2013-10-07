-- file created: 2010-03-16

local dialog = require "far2.dialog"
local M = require "lfh_message"

local Guid1 = win.Uuid("05d16094-0735-426c-a421-62dae2db6b1a")
local function ExecuteDialog (aData, aMsgTitle)
  local D = dialog.NewDialog()
  D._            = {"DI_DOUBLEBOX", 3, 1,62, 9,  0, 0,  0, 0,  aMsgTitle}
  D.lab          = {"DI_TEXT",      5, 2, 0, 0,  0, 0,  0, 0,  M.mMaxHistorySizes}
  D.lab          = {"DI_TEXT",      6, 3, 0, 0,  0, 0,  0, 0,  M.mSizeCmd}
  D.iSizeCmd     = {"DI_FIXEDIT",  20, 3,24, 0,  0, 0,  0, 0,  ""}
  D.lab          = {"DI_TEXT",      6, 4, 0, 0,  0, 0,  0, 0,  M.mSizeView}
  D.iSizeView    = {"DI_FIXEDIT",  20, 4,24, 0,  0, 0,  0, 0,  ""}
  D.lab          = {"DI_TEXT",      6, 5, 0, 0,  0, 0,  0, 0,  M.mSizeFold}
  D.iSizeFold    = {"DI_FIXEDIT",  20, 5,24, 0,  0, 0,  0, 0,  ""}

  D.lab          = {"DI_TEXT",     34,2,  0, 0,  0, 0,  0, 0, M.mWinProperties}
  D.bDynResize   = {"DI_CHECKBOX", 35,3,  0, 0,  0, 0,  0, 0, M.mDynResize}
  D.bAutoCenter  = {"DI_CHECKBOX", 35,4,  0, 0,  0, 0,  0, 0, M.mAutoCenter}

  D.sep          = {"DI_TEXT",     0, 7, 0,  0,  0, 0,  0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  D.btnOk        = {"DI_BUTTON",   0, 8, 0,  0,  0, 0,  0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.mOk}
  D.btnCancel    = {"DI_BUTTON",   0, 8, 0,  0,  0, 0,  0, "DIF_CENTERGROUP", M.mCancel}
  ------------------------------------------------------------------------------
  dialog.LoadData(D, aData)
  local ret = far.Dialog (Guid1,-1,-1,66,11,"PluginConfig",D)
  if ret == D.btnOk.id then
    dialog.SaveData(D, aData)
    aData.iSizeCmd  = tonumber(D.iSizeCmd.Data)
    aData.iSizeView = tonumber(D.iSizeView.Data)
    aData.iSizeFold = tonumber(D.iSizeFold.Data)
    return true
  end
end

local Cfg = ...
return ExecuteDialog(Cfg, M.mPluginTitle .. ": " .. M.mSettings)
