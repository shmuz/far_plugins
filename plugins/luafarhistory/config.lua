-- file created: 2010-03-16

local F = far.Flags
local sd = require "far2.simpledialog"
local DlgSend = far.SendDlgMessage

local function ConfigDialog (aData, M)
  local offset = 5 + math.max(M.mBtnHighTextColor:len(), M.mBtnSelHighTextColor:len()) + 10
  local swid = M.mTextSample:len()
  local Items = {
    guid = "05d16094-0735-426c-a421-62dae2db6b1a";
    help = "PluginConfig";
    width = 66;
    { tp="dbox"; text=M.mPluginTitle..": "..M.mSettings; },

    { tp="text"; text=M.mMaxHistorySizes;                      },
    { tp="text"; text=M.mSizeCmd; x1=6;                        },
    { tp="fixedit"; x1=20; width=5; name="iSizeCmd"; ystep=0;  },
    { tp="text"; text=M.mSizeView; x1=6;                       },
    { tp="fixedit"; x1=20; width=5; name="iSizeView"; ystep=0; },
    { tp="text"; text=M.mSizeFold; x1=6;                       },
    { tp="fixedit"; x1=20; width=5; name="iSizeFold"; ystep=0; },

    { tp="text";  text=M.mWinProperties; x1=34; ystep=-3;        },
    { tp="chbox"; text=M.mDynResize;  x1=35; name="bDynResize";  },
    { tp="chbox"; text=M.mAutoCenter; x1=35; name="bAutoCenter"; },
    { tp="chbox"; text=M.mShowDates;  x1=35; name="bShowDates";  },

    { tp="sep";  text=M.mSepColors; centertext=1;                                                   },
    { tp="butt"; text=M.mBtnHighTextColor;    btnnoclose=1; name="btnHighTextColor";                },
    { tp="text"; text=M.mTextSample; x1=offset; ystep=0;    name="labHighTextColor";    width=swid; },
    { tp="butt"; text=M.mBtnSelHighTextColor; btnnoclose=1; name="btnSelHighTextColor";             },
    { tp="text"; text=M.mTextSample; x1=offset; ystep=0;    name="labSelHighTextColor"; width=swid; },
    { tp="sep"; },

    { tp="chbox"; text=M.mKeepSelectedItem; name="bKeepSelectedItem"; },

    { tp="butt"; text=M.mOk;     centergroup=1; default=1; ystep=2; },
    { tp="butt"; text=M.mCancel; centergroup=1; cancel=1;  },
  }
  ------------------------------------------------------------------------------
  local dlg = sd.New(Items)
  local Pos = dlg:Indexes()
  dlg:LoadData(aData)

  local hColor0 = aData.HighTextColor
  local hColor1 = aData.SelHighTextColor

  Items.proc = function (hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == Pos.btnHighTextColor then
        local c = far.ColorDialog(hColor0)
        if c then hColor0 = c; DlgSend(hDlg,F.DM_REDRAW); end
      elseif param1 == Pos.btnSelHighTextColor then
        local c = far.ColorDialog(hColor1)
        if c then hColor1 = c; DlgSend(hDlg,F.DM_REDRAW); end
      end

    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Pos.labHighTextColor    then param2[1] = hColor0; return param2; end
      if param1 == Pos.labSelHighTextColor then param2[1] = hColor1; return param2; end
    end
  end

  local out = dlg:Run()
  if out then
    dlg:SaveData(out, aData)
    aData.iSizeCmd  = tonumber(aData.iSizeCmd)
    aData.iSizeView = tonumber(aData.iSizeView)
    aData.iSizeFold = tonumber(aData.iSizeFold)
    aData.HighTextColor    = hColor0
    aData.SelHighTextColor = hColor1
    return true
  end
end

return ConfigDialog
