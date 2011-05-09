-- file created: 2008-12-18

local dialog = require "far2.dialog"
local M = require "lf4ed_message"

local function ExecuteDialog (aData)
  local D = dialog.NewDialog()
  D._                   = {"DI_DOUBLEBOX",3,1,42, 9, 0, 0, 0, 0, M.MPluginSettings}
  D.ReloadDefaultScript = {"DI_CHECKBOX", 6, 2,0,0,  0, 0, 0, 0, M.MReloadDefaultScript}
  D.RequireWithReload   = {"DI_CHECKBOX", 6, 3,0,0,  0, 0, 0, 0, M.MRequireWithReload}
  D.UseStrict           = {"DI_CHECKBOX", 6, 4,0,0,  0, 0, 0, 0, M.MUseStrict}
  D.UseSearchMenu       = {"DI_CHECKBOX", 6, 5,0,0,  0, 0, 0, 0, M.MUseSearchMenu}
  D.ReturnToMainMenu    = {"DI_CHECKBOX", 6, 6,0,0,  0, 0, 0, 0, M.MReturnToMainMenu}
  D.sep       = {"DI_TEXT",     0, 7, 0,0, 0, 0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, 0, ""}
  D.btnOk     = {"DI_BUTTON",   0, 8, 0,0, 0, 0, "DIF_CENTERGROUP", 1, M.MOk}
  D.btnCancel = {"DI_BUTTON",   0, 8, 0,0, 0, 0, "DIF_CENTERGROUP", 0, M.MCancel}
  ------------------------------------------------------------------------------
  dialog.LoadData(D, aData)
  local ret = far.Dialog (-1,-1,46,11,"PluginConfig",D)
  if ret == D.btnOk.id then
    dialog.SaveData(D, aData) 
    return true
  end
end

local Cfg = (...)[1]
return ExecuteDialog(Cfg)
