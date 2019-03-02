  -- settings.lua

local History = require "far2.history"
local Data

local Params = ...
local M = Params.M
local F = far.Flags

local function InitSetting (tbl, key, val)
  if tbl[key] == nil then tbl[key]=val end
end

local settings = {}

function settings.load()
  Data = History.newsettings(nil, "root")
  local hPlugin   = Data:field("plugin")
  local hExporter = Data:field("exporter")

  InitSetting(hPlugin,   "prefix",        "polygon")
  InitSetting(hPlugin,   "add_to_menu",   false)
  InitSetting(hPlugin,   "confirm_close", false)
  InitSetting(hPlugin,   "multidb_mode",  false)
  InitSetting(hPlugin,   "user_modules",  false)
  InitSetting(hPlugin,   "extensions",    false)
  InitSetting(hPlugin,   "foreign_keys",  true)

  InitSetting(hExporter, "format",        "csv")
  InitSetting(hExporter, "multiline",     true)

  return Data
end

function settings.configure()
  Data = Data or settings.load()
  local plugdata = Data:getfield("plugin") -- plugin-level Data
  local B_CC = plugdata.confirm_close and 1 or 0
  local B_EX = plugdata.extensions    and 1 or 0
  local B_FK = plugdata.foreign_keys  and 0 or 1 -- must be inverted
  local B_MD = plugdata.multidb_mode  and 1 or 0
  local B_PM = plugdata.add_to_menu   and 1 or 0
  local B_UM = plugdata.user_modules  and 1 or 0

  local dlg_items = {
    --[[01]]  {"DI_DOUBLEBOX", 3, 1,49,12,  0,   0,0,0, M.ps_title },
    --[[02]]  {"DI_CHECKBOX",  5, 2,49, 2,  B_PM,0,0,0, M.ps_cfg_add_pm },
    --[[03]]  {"DI_CHECKBOX",  5, 3,49, 3,  B_CC,0,0,0, M.ps_cfg_confirm_close },
    --[[04]]  {"DI_CHECKBOX",  5, 4,49, 4,  B_MD,0,0,0, M.ps_cfg_multidb_mode },
    --[[05]]  {"DI_TEXT",      5, 5,13, 5,  0,   0,0,0, M.ps_cfg_prefix },
    --[[06]]  {"DI_EDIT",     14, 5,47, 5,  0,   0,0,0, plugdata.prefix },
    --[[07]]  {"DI_TEXT",      5, 6, 5, 6,  0,   0,0,F.DIF_BOXCOLOR+F.DIF_SEPARATOR, "" },
    --[[08]]  {"DI_CHECKBOX",  5, 7,47, 7,  B_UM,0,0,0, M.ps_cfg_user_modules },
    --[[09]]  {"DI_CHECKBOX",  5, 8,47, 8,  B_EX,0,0,0, M.ps_cfg_extensions },
    --[[10]]  {"DI_CHECKBOX",  5, 9,47, 9,  B_FK,0,0,0, M.ps_cfg_no_foreign_keys },
    --[[11]]  {"DI_TEXT",      5,10, 5,10,  0,   0,0,F.DIF_BOXCOLOR+F.DIF_SEPARATOR, "" },
    --[[12]]  {"DI_BUTTON",    5,11,47,11,  0,   0,0,F.DIF_CENTERGROUP+F.DIF_DEFAULTBUTTON, M.ps_save },
    --[[13]]  {"DI_BUTTON",    5,11,47,11,  0,   0,0,F.DIF_CENTERGROUP, M.ps_cancel },
  }
  local cbxAddToMenu, cbxConfirmClose, cbxMultiDb   = 2, 3, 4
  local edtPrefix, cbxUserModules, cbxExtensions    = 6, 8, 9
  local cbxNoForeignKeys, btnCancel = 10, 13

  local guid = win.Uuid("A8968CEC-B1A3-45C0-AB8C-B39DB7C96B38")
  local rc = far.Dialog(guid,-1,-1,53,14,"ConfigDialog",dlg_items)
  if rc >= 1 and rc ~= btnCancel then
    plugdata.prefix        = dlg_items[edtPrefix       ][10]
    plugdata.add_to_menu   = dlg_items[cbxAddToMenu    ][ 6] ~= 0
    plugdata.confirm_close = dlg_items[cbxConfirmClose ][ 6] ~= 0
    plugdata.multidb_mode  = dlg_items[cbxMultiDb      ][ 6] ~= 0
    plugdata.user_modules  = dlg_items[cbxUserModules  ][ 6] ~= 0
    plugdata.extensions    = dlg_items[cbxExtensions   ][ 6] ~= 0
    plugdata.foreign_keys  = dlg_items[cbxNoForeignKeys][ 6] == 0 -- must be inverted
    Data:save()
  end
end

function settings.save()
  if Data then Data:save() end
end

return settings
