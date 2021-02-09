-- coding: UTF-8

local history = require "far2.settings"
local sdialog = require "far2.simpledialog"
local M       = require "modules.string_rc"

local Data
local mod = {} -- this module

local function InitSetting (tbl, key, val)
  if tbl[key] == nil then tbl[key]=val end
end

function mod.load()
  Data = Data or {}
  Data.plugin   = history.mload("root", "plugin") or {}
  Data.exporter = history.mload("root", "exporter") or {}

  InitSetting(Data.plugin,   "prefix",        "polygon")
  InitSetting(Data.plugin,   "add_to_menu",   false)
  InitSetting(Data.plugin,   "confirm_close", false)
  InitSetting(Data.plugin,   "multidb_mode",  false)
  InitSetting(Data.plugin,   "user_modules",  false)
  InitSetting(Data.plugin,   "extensions",    false)
  InitSetting(Data.plugin,   "foreign_keys",  true)

  InitSetting(Data.exporter, "format",        "csv")
  InitSetting(Data.exporter, "multiline",     true)

  return Data
end

function mod.configure()
  Data = Data or mod.load()
  local Pdata = Data.plugin
  local Items = {
    guid = "A8968CEC-B1A3-45C0-AB8C-B39DB7C96B38";
    help = "ConfigDialog";
    width = 53;
    { tp="dbox";  text=M.title },
    { tp="cbox";  text=M.cfg_add_pm;           name="add_to_menu";   },
    { tp="cbox";  text=M.cfg_confirm_close;    name="confirm_close"; },
    { tp="cbox";  text=M.cfg_multidb_mode;     name="multidb_mode";  },
    { tp="text";  text=M.cfg_prefix;                                 },
    { tp="edit";  ystep=0; x1=14;              name="prefix";        },
    { tp="sep";                                                      },
    { tp="cbox";  text=M.cfg_user_modules;     name="user_modules";  },
    { tp="cbox";  text=M.cfg_extensions;       name="extensions";    },
    { tp="cbox";  text=M.cfg_no_foreign_keys;  name="foreign_keys";  },
    { tp="sep";                                                      },
    { tp="butt";  text=M.save;   centergroup=1; defaultbutton=1;     },
    { tp="butt";  text=M.cancel; centergroup=1; cancel=1;            },
  }

  -- initialize the dialog
  local _, Elem = sdialog.Indexes(Items)
  for _,v in ipairs(Items) do v.val = v.name and Pdata[v.name]; end
  Elem.foreign_keys.val = not Elem.foreign_keys.val -- must be inverted
  -- run the dialog
  local rc = sdialog.Run(Items)
  -- save the dialog data
  if rc then
    for k,v in pairs(rc) do Pdata[k] = v; end
    Pdata.foreign_keys = not Pdata.foreign_keys -- must be inverted
    history.msave("root", "plugin", Pdata)
  end
end

function mod.save()
  if Data then
    history.msave("root", "plugin", Data.plugin)
    history.msave("root", "exporter", Data.exporter)
  end
end

return mod
