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
  InitSetting(hPlugin,   "foreign_keys",  true)
  InitSetting(hPlugin,   "user_modules",  false)

  InitSetting(hExporter, "format",        "csv")
  InitSetting(hExporter, "multiline",     true)

  return data
end

function settings.configure()
  data = data or settings.load()
  local plugdata = data:getfield("plugin") -- plugin-level data
  local PM = plugdata.add_to_menu  and 1 or 0
  local UM = plugdata.user_modules and 1 or 0
  local FK = plugdata.foreign_keys and 1 or 0

  local dlg_items = {
    --[[01]]  {"DI_DOUBLEBOX", 3,1,46,9,  0, 0,0,0, M.ps_title },
    --[[02]]  {"DI_CHECKBOX",  5,2,46,2,  PM,0,0,0, M.ps_cfg_add_pm },
    --[[03]]  {"DI_TEXT",      5,3,13,3,  0, 0,0,0, M.ps_cfg_prefix },
    --[[04]]  {"DI_EDIT",     14,3,44,3,  0, 0,0,0, plugdata.prefix },
    --[[05]]  {"DI_TEXT",      5,4, 5,4,  0, 0,0,F.DIF_BOXCOLOR+F.DIF_SEPARATOR, "" },
    --[[06]]  {"DI_CHECKBOX",  5,5,46,5,  UM,0,0,0, M.ps_cfg_user_modules },
    --[[07]]  {"DI_CHECKBOX",  5,6,46,6,  FK,0,0,0, M.ps_cfg_foreign_keys },
    --[[08]]  {"DI_TEXT",      5,7, 5,7,  0, 0,0,F.DIF_BOXCOLOR+F.DIF_SEPARATOR, "" },
    --[[09]]  {"DI_BUTTON",    5,8,46,8,  0, 0,0,F.DIF_CENTERGROUP+F.DIF_DEFAULTBUTTON, M.ps_save },
    --[[10]]  {"DI_BUTTON",    5,8,46,8,  0, 0,0,F.DIF_CENTERGROUP, M.ps_cancel },
  }
  local edtPrefix = 4
  local btnAddToMenu, btnUserModules, btnForeignKeys, btnCancel = 2, 6, 7, 10

  local guid = win.Uuid("A8968CEC-B1A3-45C0-AB8C-B39DB7C96B38")
  local rc = far.Dialog(guid,-1,-1,50,11,"ConfigDialog",dlg_items)
  if rc >= 1 and rc ~= btnCancel then
    plugdata.prefix       = dlg_items[edtPrefix     ][10]
    plugdata.add_to_menu  = dlg_items[btnAddToMenu  ][ 6] ~= 0
    plugdata.user_modules = dlg_items[btnUserModules][ 6] ~= 0
    plugdata.foreign_keys = dlg_items[btnForeignKeys][ 6] ~= 0
    data:save()
  end
end

function settings.save()
  if data then data:save() end
end

return settings
