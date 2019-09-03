-------------------------------------------------------------------------------
-- Requirements: Lua 5.1, FAR 3.0.
-------------------------------------------------------------------------------

-- CONFIGURATION : keep it at the file top !!
local Cfg = {
  ReloadDefaultScript = true, -- Default script will be recompiled and run every time
                              -- OpenPlugin/OpenFilePlugin are called: set true for
                              -- debugging, false for normal use;

  ReloadOnRequire = true, -- Reload lua libraries each time they are require()d:
                          -- set true for libraries debugging, false for normal use;

  UseStrict = true, -- Use require 'strict'
}

if far.FileTimeResolution then -- this function was introduced on Sep-03 2019
  far.FileTimeResolution(2) -- set 100ns file resolution
end

-- UPVALUES : keep them above all function definitions !!
local Utils      = require "far2.utils"
local LibHistory = require "far2.history"

local FirstRun = ... --> this works with Far >= 3.0.4425
if FirstRun then
  _Plugin = Utils.InitPlugin()
  _Plugin.History = LibHistory.newsettings(nil, "alldata")
  package.path = _Plugin.ModuleDir .. "?.lua;" .. package.path
end

local F = far.Flags
local History = _Plugin.History

local Env

local function Require (name)
  package.loaded[name] = nil
  return require (name)
end

function export.Open (From, Guid, Item)
  if From == F.OPEN_PLUGINSMENU then
    return Env:Open (From, Guid, Item)

  elseif From == F.OPEN_DISKMENU or From == F.OPEN_FINDLIST then
    return Env:NewPanel()

  else
    return Env:Open(From, Guid, Item)
  end
end

function export.Analyse (Data)
  return Env:Analyse (Data)
end

function export.GetPluginInfo()
  local Info = Env:GetPluginInfo()
  --Info.Flags.preload = true
  return Info
end

function export.Configure (Guid)
  return Env:Configure()
end

function export.ExitFAR()
  Env:ExitFAR()
  History.Data.Env = Env
  History:save()
end

local function InitUpvalues (_Plugin)
  if Cfg.UseStrict then require "strict" end
  Require = Cfg.ReloadOnRequire and Require or require
  -----------------------------------------------------------------------------
  far.ReloadDefaultScript = Cfg.ReloadDefaultScript
  -----------------------------------------------------------------------------
  local tp = Require "far2.tmppanel"
  _Plugin.tmppanel = _Plugin.tmppanel or tp
  Env = tp.NewEnv(_Plugin.Env or History:field("Env"))
  _Plugin.Env = Env
  tp.PutExportedFunctions(export)
  tp.Panel.AS_F9 = export.Configure
end

do
  InitUpvalues(_Plugin)
end

