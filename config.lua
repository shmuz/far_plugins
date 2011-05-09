-- file created: 2008-12-18

local dialog = require "far2.dialog"
local M = require "lf4ed_message"

local ExGuid = win.Uuid("e534a678-47e7-4a1b-8b6d-c34a10b75992")

local function ExecuteDialog (aData)
  local D = dialog.NewDialog()
  D._                   = {"DI_DOUBLEBOX",3, 1,42, 8, 0, 0, 0, 0, M.MPluginSettings}
  D.ReloadDefaultScript = {"DI_CHECKBOX", 6, 2,0,  0, 0, 0, 0, 0, M.MReloadDefaultScript}
  D.RequireWithReload   = {"DI_CHECKBOX", 6, 3,0,  0, 0, 0, 0, 0, M.MRequireWithReload}
  D.UseStrict           = {"DI_CHECKBOX", 6, 4,0,  0, 0, 0, 0, 0, M.MUseStrict}
  D.ReturnToMainMenu    = {"DI_CHECKBOX", 6, 5,0,  0, 0, 0, 0, 0, M.MReturnToMainMenu}
  D.sep                 = {"DI_TEXT",     0, 6, 0, 0, 0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  D.btnOk               = {"DI_BUTTON",   0, 7, 0, 0, 0, 0, 0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.MOk}
  D.btnCancel           = {"DI_BUTTON",   0, 7, 0, 0, 0, 0, 0, "DIF_CENTERGROUP", M.MCancel}
  ------------------------------------------------------------------------------
  dialog.LoadData(D, aData)
  local ret = far.Dialog (ExGuid,-1,-1,46,10,"PluginConfig",D)
  if ret == D.btnOk.id then
    dialog.SaveData(D, aData)
    return true
  end
end

local Cfg = (...)[1]
return ExecuteDialog(Cfg)
