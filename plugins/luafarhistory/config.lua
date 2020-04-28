-- file created: 2010-03-16

local F = far.Flags
local dialog = require "far2.dialog"
local Cfg, M = ...

local Guid1 = win.Uuid("05d16094-0735-426c-a421-62dae2db6b1a")
local function ExecuteDialog (aData, aMsgTitle)
  local D = dialog.NewDialog()
  local offset = 5 + math.max(M.mBtnHighTextColor:len(), M.mBtnSelHighTextColor:len()) + 10
  D._            = {"DI_DOUBLEBOX", 3, 1,62,12,  0, 0,  0, 0,  aMsgTitle}
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

  D.sep                 = {"DI_TEXT",       -1, 7, 0, 0,  0, 0, 0,  {DIF_BOXCOLOR=1,DIF_SEPARATOR=1,DIF_CENTERTEXT=1}, M.mSepColors}
  D.btnHighTextColor    = {"DI_BUTTON",      5, 8, 0, 0,  0, 0, 0,  "DIF_BTNNOCLOSE", M.mBtnHighTextColor}
  D.labHighTextColor    = {"DI_TEXT",   offset, 8, 0, 0,  0, 0, 0,  0,  M.mTextSample}
  D.btnSelHighTextColor = {"DI_BUTTON",      5, 9, 0, 0,  0, 0, 0,  "DIF_BTNNOCLOSE", M.mBtnSelHighTextColor}
  D.labSelHighTextColor = {"DI_TEXT",   offset, 9, 0, 0,  0, 0, 0,  0,  M.mTextSample}

  D.sep          = {"DI_TEXT",     0,10, 0,  0,  0, 0,  0, {DIF_BOXCOLOR=1,DIF_SEPARATOR=1}, ""}
  D.btnOk        = {"DI_BUTTON",   0,11, 0,  0,  0, 0,  0, {DIF_CENTERGROUP=1, DIF_DEFAULTBUTTON=1}, M.mOk}
  D.btnCancel    = {"DI_BUTTON",   0,11, 0,  0,  0, 0,  0, "DIF_CENTERGROUP", M.mCancel}
  ------------------------------------------------------------------------------
  dialog.LoadData(D, aData)

  local hColor0 = aData.HighTextColor    or 0x3A
  local hColor1 = aData.SelHighTextColor or 0x0A

  local function DlgProc (hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == D.btnHighTextColor.id then
        local c = far.ColorDialog(hColor0)
        if c then hColor0 = c; hDlg:send(F.DM_REDRAW); end
      elseif param1 == D.btnSelHighTextColor.id then
        local c = far.ColorDialog(hColor1)
        if c then hColor1 = c; hDlg:send(F.DM_REDRAW); end
      end

    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == D.labHighTextColor.id then param2[1] = hColor0; return param2; end
      if param1 == D.labSelHighTextColor.id then param2[1] = hColor1; return param2; end
    end
  end

  local ret = far.Dialog (Guid1,-1,-1,66,14,"PluginConfig",D,nil,DlgProc)
  if ret == D.btnOk.id then
    dialog.SaveData(D, aData)
    aData.iSizeCmd  = tonumber(D.iSizeCmd.Data)
    aData.iSizeView = tonumber(D.iSizeView.Data)
    aData.iSizeFold = tonumber(D.iSizeFold.Data)
    aData.HighTextColor    = hColor0
    aData.SelHighTextColor = hColor1
    return true
  end
end

return ExecuteDialog(Cfg, M.mPluginTitle .. ": " .. M.mSettings)
