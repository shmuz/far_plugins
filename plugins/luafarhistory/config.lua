-- file created: 2010-03-16

local F = far.Flags
local sd = require "far2.simpledialog"
local DlgSend = far.SendDlgMessage

local function ConfigDialog (aData, M, aDateFormats)
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

    { tp="sep";  text=M.mSepColors; centertext=1; ystep=2;                                          },
    { tp="butt"; text=M.mBtnHighTextColor;    btnnoclose=1; name="btnHighTextColor";                },
    { tp="text"; text=M.mTextSample; x1=offset; ystep=0;    name="labHighTextColor";    width=swid; },
    { tp="butt"; text=M.mBtnSelHighTextColor; btnnoclose=1; name="btnSelHighTextColor";             },
    { tp="text"; text=M.mTextSample; x1=offset; ystep=0;    name="labSelHighTextColor"; width=swid; },
    { tp="sep"; },

    { tp="text"; text=M.mDateFormat; },
    { tp="combobox"; name="iDateFormat"; dropdown=1; list={}; width=24; },
    { tp="chbox"; text=M.mKeepSelectedItem; name="bKeepSelectedItem"; x1=35; ystep=-1; },
    { tp="sep"; ystep=2; },

    { tp="butt"; text=M.mOk;     centergroup=1; default=1; },
    { tp="butt"; text=M.mCancel; centergroup=1; cancel=1;  },
  }
  ------------------------------------------------------------------------------
  local dlg = sd.New(Items)
  local Pos, Elem = dlg:Indexes()

  local time = os.time()
  for _,fmt in ipairs(aDateFormats) do
    local t = { Text = fmt and os.date(fmt, time) or M.mDontShowDates }
    table.insert(Elem.iDateFormat.list, t)
  end

  dlg:LoadData(aData)

  local hColor0 = aData.HighTextColor
  local hColor1 = aData.SelHighTextColor

  Items.proc = function (hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == Pos.btnHighTextColor then
        local c = far.ColorDialog(hColor0)
        if c then hColor0 = c; hDlg:Redraw(); end
      elseif param1 == Pos.btnSelHighTextColor then
        local c = far.ColorDialog(hColor1)
        if c then hColor1 = c; hDlg:Redraw(); end
      end

    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Pos.labHighTextColor then return hColor0; end
      if param1 == Pos.labSelHighTextColor then return hColor1; end
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
