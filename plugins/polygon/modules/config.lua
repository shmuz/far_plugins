-- coding: UTF-8

local DIRSEP = string.sub(package.config, 1, 1)
local OS_WIN = (DIRSEP == "\\")
local SETTINGS_KEY = OS_WIN and "root" or nil

local settings = require "far2.settings"
local sdialog  = require "far2.simpledialog"
local M        = require "modules.string_rc"

local Data
local mod = {} -- this module
setmetatable(mod, { __index=function(t,k) error("invalid index: "..tostring(k)) end; }) -- catch typos

local function InitSetting (tbl, key, val)
  if tbl[key] == nil then tbl[key]=val end
end

-- persistent settings' keys
mod.PREFIX=                "prefix"
mod.ADD_TO_MENU=           "add_to_menu"
mod.CONFIRM_CLOSE=         "confirm_close"
mod.MULTIDB_MODE=          "multidb_mode"
mod.COMMON_USER_MODULES=   "common_user_modules"
mod.INDIVID_USER_MODULES=  "individ_user_modules"
mod.EXTENSIONS=            "extensions"
mod.IGNORE_FOREIGN_KEYS=   "ignore_foreign_keys"
mod.EXCL_MASKS=            "excl_masks"

function mod.load()
  Data = Data or {}
  Data.plugin   = settings.mload(SETTINGS_KEY, "plugin") or {}
  Data.exporter = settings.mload(SETTINGS_KEY, "exporter") or {}

  InitSetting(Data.plugin,  mod.PREFIX,               "polygon")
  InitSetting(Data.plugin,  mod.ADD_TO_MENU,          false)
  InitSetting(Data.plugin,  mod.CONFIRM_CLOSE,        false)
  InitSetting(Data.plugin,  mod.MULTIDB_MODE,         false)
  InitSetting(Data.plugin,  mod.COMMON_USER_MODULES,  false)
  InitSetting(Data.plugin,  mod.INDIVID_USER_MODULES, false)
  InitSetting(Data.plugin,  mod.EXTENSIONS,           false)
  InitSetting(Data.plugin,  mod.IGNORE_FOREIGN_KEYS,  false)

  InitSetting(Data.exporter, "format",        "csv")
  InitSetting(Data.exporter, "multiline",     true)

  return Data
end

function mod.showdialog()
  Data = Data or mod.load()
  local Pdata = Data.plugin
  local Items = {
    guid = "A8968CEC-B1A3-45C0-AB8C-B39DB7C96B38";
    help = "ConfigDialog";
    width = 60;
    { tp="dbox";  text=M.title                                                     },
    { tp="chbox"; text=M.cfg_add_pm;                name=mod.ADD_TO_MENU;          },
    { tp="chbox"; text=M.cfg_confirm_close;         name=mod.CONFIRM_CLOSE;        },
    { tp="chbox"; text=M.cfg_multidb_mode;          name=mod.MULTIDB_MODE;         },
    { tp="text";  text=M.cfg_prefix;                                               },
    { tp="edit";                                    name=mod.PREFIX;               },
    { tp="text";  text=M.cfg_excl_masks;                                           },
    { tp="edit";                                    name=mod.EXCL_MASKS;           },
    { tp="sep";                                                                    },
    { tp="chbox"; text=M.cfg_common_user_modules;   name=mod.COMMON_USER_MODULES;  },
    { tp="chbox"; text=M.cfg_individ_user_modules;  name=mod.INDIVID_USER_MODULES; },
    { tp="chbox"; text=M.cfg_extensions;            name=mod.EXTENSIONS;           },
    { tp="chbox"; text=M.cfg_ignore_foreign_keys;   name=mod.IGNORE_FOREIGN_KEYS;  },
    { tp="sep";                                                                    },
    { tp="butt";  text=M.save;   centergroup=1; default=1;                         },
    { tp="butt";  text=M.cancel; centergroup=1; cancel=1;                          },
  }

  -- initialize the dialog
  for _,v in ipairs(Items) do
    v.val = v.name and Pdata[v.name]
  end
  -- run the dialog
  local rc = sdialog.New(Items):Run()
  -- save the dialog data
  if rc then
    for k,v in pairs(rc) do Pdata[k] = v; end
    settings.msave(SETTINGS_KEY, "plugin", Pdata)
  end
end

function mod.save()
  if Data then
    settings.msave(SETTINGS_KEY, "plugin", Data.plugin)
    settings.msave(SETTINGS_KEY, "exporter", Data.exporter)
  end
end

return mod
