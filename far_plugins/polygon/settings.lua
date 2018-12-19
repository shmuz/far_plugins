  -- settings.lua

local history = require "far2.history"
local data

local Params = ...
local M = Params.M
local F = far.Flags

local function InitSetting (tbl, key, val)
  if tbl[key] == nil then tbl[key]=val end
end

local settings = {}

function settings.load()
  data = history.newsettings(nil, "root")
  local hPlugin   = data:field("plugin")
  local hExporter = data:field("exporter")

  InitSetting(hPlugin,   "prefix",        "polygon")
  InitSetting(hPlugin,   "add_to_menu",   false)
  InitSetting(hPlugin,   "user_modules",  false)
  InitSetting(hPlugin,   "extensions",    false)
  InitSetting(hPlugin,   "foreign_keys",  true)
  InitSetting(hPlugin,   "no_secur_warn", false)

  InitSetting(hExporter, "format",        "csv")
  InitSetting(hExporter, "multiline",     true)

  return data
end

function settings.configure()
  data = data or settings.load()
  local plugdata = data:getfield("plugin") -- plugin-level data
  local PM = plugdata.add_to_menu   and 1 or 0
  local UM = plugdata.user_modules  and 1 or 0
  local EX = plugdata.extensions    and 1 or 0
  local FK = plugdata.foreign_keys  and 0 or 1 -- must be inverted
  local SW = plugdata.no_secur_warn and 1 or 0

  local dlg_items = {
    --[[01]]  {"DI_DOUBLEBOX", 3, 1,49,11,  0, 0,0,0, M.ps_title },
    --[[02]]  {"DI_CHECKBOX",  5, 2,49, 2,  PM,0,0,0, M.ps_cfg_add_pm },
    --[[03]]  {"DI_TEXT",      5, 3,13, 3,  0, 0,0,0, M.ps_cfg_prefix },
    --[[04]]  {"DI_EDIT",     14, 3,47, 3,  0, 0,0,0, plugdata.prefix },
    --[[05]]  {"DI_TEXT",      5, 4, 5, 4,  0, 0,0,F.DIF_BOXCOLOR+F.DIF_SEPARATOR, "" },
    --[[06]]  {"DI_CHECKBOX",  5, 5,47, 5,  UM,0,0,0, M.ps_cfg_user_modules },
    --[[07]]  {"DI_CHECKBOX",  5, 6,47, 6,  EX,0,0,0, M.ps_cfg_extensions },
    --[[08]]  {"DI_CHECKBOX",  5, 7,47, 7,  FK,0,0,0, M.ps_cfg_no_foreign_keys },
    --[[09]]  {"DI_CHECKBOX",  5, 8,47, 8,  SW,0,0,0, M.ps_cfg_no_secur_warn },
    --[[10]]  {"DI_TEXT",      5, 9, 5, 9,  0, 0,0,F.DIF_BOXCOLOR+F.DIF_SEPARATOR, "" },
    --[[11]]  {"DI_BUTTON",    5,10,47,10,  0, 0,0,F.DIF_CENTERGROUP+F.DIF_DEFAULTBUTTON, M.ps_save },
    --[[12]]  {"DI_BUTTON",    5,10,47,10,  0, 0,0,F.DIF_CENTERGROUP, M.ps_cancel },
  }
  local edtPrefix = 4
  local cbxAddToMenu, cbxUserModules, cbxExtensions = 2, 6, 7
  local cbxNoForeignKeys, cbxNoSecurWarn, btnCancel = 8, 9, 12

  local guid = win.Uuid("A8968CEC-B1A3-45C0-AB8C-B39DB7C96B38")
  local rc = far.Dialog(guid,-1,-1,53,13,"ConfigDialog",dlg_items)
  if rc >= 1 and rc ~= btnCancel then
    plugdata.prefix        = dlg_items[edtPrefix       ][10]
    plugdata.add_to_menu   = dlg_items[cbxAddToMenu    ][ 6] ~= 0
    plugdata.user_modules  = dlg_items[cbxUserModules  ][ 6] ~= 0
    plugdata.extensions    = dlg_items[cbxExtensions   ][ 6] ~= 0
    plugdata.foreign_keys  = dlg_items[cbxNoForeignKeys][ 6] == 0 -- must be inverted
    plugdata.no_secur_warn = dlg_items[cbxNoSecurWarn  ][ 6] ~= 0
    data:save()
  end
end

function settings.save()
  if data then data:save() end
end

return settings
