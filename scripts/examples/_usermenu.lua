local PluginDir = far.PluginStartupInfo().ModuleDir
local dir = "scripts/examples/"
local HelpDir = PluginDir..dir

-- editor menu
AddToMenu ("e", ":sep:")
AddCommand("InitColorizer", dir.."colorize", "init")
AddToMenu ("e", "Select colorizer", "Ctrl+Shift+A", dir.."colorize")
AddToMenu ("e", "Fill selection",   "Ctrl+M", dir.."fill_selection")
AddToMenu ("e", nil,                "Alt+Shift+I", dir.."shift_selection", true)
AddToMenu ("e", nil,                "Alt+Shift+U", dir.."shift_selection", false)

-- panels menu
AddToMenu ("p", "SelectingEx", nil, dir.."selectingEx")

AddToMenu ("evp", "Plugins control", nil, dir.."plugins")
AddToMenu ("evp", "Chess",           nil, dir.."chess")

-- cross in the editor
MakeResident(dir.."cross")
