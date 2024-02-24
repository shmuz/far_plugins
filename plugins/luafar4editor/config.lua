-- file created: 2008-12-18

local sd = require "far2.simpledialog"
local M = require "lf4ed_message"
local F = far.Flags

local function ExecuteDialog (aData)
  local Items = {
    width=46;
    help="PluginConfig";
    guid="E534A678-47E7-4A1B-8B6D-C34A10B75992";

    {tp="dbox";  text=M.MPluginSettings;},
    {tp="chbox"; text=M.MReloadDefaultScript;     name="ReloadDefaultScript"; },
    {tp="chbox"; text=M.MRequireWithReload;       name="RequireWithReload";   },
    {tp="chbox"; text=M.MReturnToMainMenu;        name="ReturnToMainMenu";    },
    {tp="sep";                                                                },
    {tp="butt";  text=M.MOk;     default=1; centergroup=1;                    },
    {tp="butt";  text=M.MCancel; cancel=1;  centergroup=1;                    },
  }
  ------------------------------------------------------------------------------
  local dlg = sd.New(Items)
  dlg:LoadData(aData)
  local out = dlg:Run()
  if out then
    dlg:SaveData(out, aData)
    return true
  end
end

local data = (...)[1]
return ExecuteDialog(data)
