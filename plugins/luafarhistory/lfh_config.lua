-- file created: 2010-03-16
-- luacheck: globals _Plugin

local F = far.Flags
local sd = require "far2.simpledialog"
local M  = require "lfh_message"
local main

local function Init(data)
  main = data
end

local function ConfigDialog ()
  local aData = _Plugin.Cfg
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
  for _,fmt in ipairs(main.DateFormats) do
    local t = { Text = fmt and os.date(fmt, time) or M.mDontShowDates }
    table.insert(Elem.iDateFormat.list, t)
  end

  dlg:LoadData(aData)
  Elem.iSizeCmd.val  = aData.commands.iSize
  Elem.iSizeView.val = aData.view.iSize
  Elem.iSizeFold.val = aData.folders.iSize

  local hColor0 = aData.HighTextColor
  local hColor1 = aData.SelHighTextColor

  Items.proc = function (hDlg, msg, param1, param2)
    if msg == F.DN_BTNCLICK then
      if param1 == Pos.btnHighTextColor then
        local c = far.ColorDialog(hColor0)
        if c then hColor0 = c; hDlg:send("DM_REDRAW"); end
      elseif param1 == Pos.btnSelHighTextColor then
        local c = far.ColorDialog(hColor1)
        if c then hColor1 = c; hDlg:send("DM_REDRAW"); end
      end

    elseif msg == F.DN_CTLCOLORDLGITEM then
      if param1 == Pos.labHighTextColor    then param2[1] = hColor0; return param2; end
      if param1 == Pos.labSelHighTextColor then param2[1] = hColor1; return param2; end
    end
  end

  local out = dlg:Run()
  if out then
    if tonumber(out.iSizeCmd)  then aData.commands.iSize = tonumber(out.iSizeCmd) end
    if tonumber(out.iSizeView) then aData.view.iSize     = tonumber(out.iSizeView) end
    if tonumber(out.iSizeFold) then aData.folders.iSize  = tonumber(out.iSizeFold) end
    out.iSizeCmd, out.iSizeView, out.iSizeFold = nil,nil,nil
    aData.HighTextColor    = hColor0
    aData.SelHighTextColor = hColor1
    dlg:SaveData(out, aData)
    main.SaveHistory()
  end
end

local function ExclusionDialog (aStr)
  local title = aStr=="" and M.mExcludeDlgTitleAdd or M.mExcludeDlgTitleEdit
  local Items = {
    guid = "4F55D7A5-0CAA-4533-A440-840553845DB0";
    help = "ExclusionDialog";
    { tp="dbox"; text=title;                               },
    { tp="text"; text=M.mExcludeDlgPrompt;                 },
    { tp="edit"; text=aStr; name="pattern";                },
    { tp="sep";                                            },
    { tp="butt"; text=M.mOk;     centergroup=1; default=1; },
    { tp="butt"; text=M.mCancel; centergroup=1; cancel=1;  },
  }

  local retvalue = nil
  Items.closeaction = function(_hDlg, _Par1, tOut)
    if tOut.pattern ~= "" and pcall(regex.new, tOut.pattern) then
      retvalue = tOut.pattern
    else
      far.Message(("%s: \"%s\"" ):format(M.mExcludeDlgError, tOut.pattern), M.mError, M.mOk, "w")
      return 0
    end
  end

  sd.New(Items):Run()
  return retvalue
end

local function ExclusionMenu (aData, aTitle)
  local exclude = aData.exclude
  local Props = { Title=aTitle; Bottom="Ins, Del, F4"; HelpTopic="ExclusionMenu"; }
  local Items = {}
  local Bkeys = "Ins Del F4"
  local modif = false

  for i,v in ipairs(exclude) do Items[i] = v end

  while true do
    local item, pos = far.Menu(Props, Items, Bkeys)
    if item then Props.SelectIndex = pos end

    if not item then
      if not modif then break end
      local R = far.Message(M.mExcludeDlgSaveQuery, M.mPluginTitle, ";YesNoCancel", "w")
      if R == 1 then
        aData.exclude = Items
        main.SaveHistory()
        break
      elseif R == 2 then
        break
      end

    elseif item.BreakKey == "Ins" then
      local txt = ExclusionDialog("")
      if txt then
        modif = true
        table.insert(Items, Items[pos] and pos or 1, { text=txt; })
      end

    elseif item.BreakKey == "Del" and Items[pos] then
      modif = true
      table.remove(Items, pos)
      if not Items[pos] then Props.SelectIndex = pos-1 end

    elseif (item.BreakKey == "F4" or item.BreakKey == nil) and Items[pos] then
      local txt = ExclusionDialog(Items[pos].text)
      if txt then
        modif = true
        Items[pos].text = txt
      end

    end
  end
end

local function ConfigMenu()
  local Props = { Title=M.mPluginTitle; HelpTopic="ConfigMenu"; }
  local Items = {
    { tag="general";  data=M.mGeneralSettings;                      },
    { separator=true;                                               },
    { tag="commands"; data=M.mMenuCommands .. ": " ..M.mExclusions; },
    { tag="view";     data=M.mMenuView     .. ": " ..M.mExclusions; },
    { tag="folders";  data=M.mMenuFolders  .. ": " ..M.mExclusions; },
  }
  local j = 1
  for _,v in ipairs(Items) do
    if v.separator==nil then
      v.text = ("&%d. %s"):format(j, v.data)
      j = j+1
    end
  end

  while true do
    local item,pos = far.Menu(Props,Items)
    if not item then break end
    Props.SelectIndex = pos
    if item.tag == "general" then
      ConfigDialog()
    else
      ExclusionMenu(_Plugin.Cfg[item.tag], item.data)
    end
  end
end

return {
  Init = Init;
  ConfigMenu = ConfigMenu;
}
