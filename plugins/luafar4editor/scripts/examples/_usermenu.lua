local PluginDir = far.PluginStartupInfo().ModuleDir
local dir = "scripts/examples/"
local HelpDir = PluginDir..dir

-- editor menu
AddToMenuEx  ("e", ":sep:")
AddCommandEx ("InitColorizer", dir.."colorize", "init")

AddToMenuEx  ("e", "Select colorizer", "Ctrl+Shift+A", dir.."colorize")
AddToMenuEx  ("e", "Fill selection",   "Ctrl+M",       dir.."fill_selection")
AddToMenuEx  ("e", nil,                "Alt+Shift+I",  dir.."shift_selection", true)
AddToMenuEx  ("e", nil,                "Alt+Shift+U",  dir.."shift_selection", false)

-- panels menu
AddToMenuEx ("p", "SelectingEx", nil, dir.."selectingEx")

AddToMenuEx ("evp", "Plugins control", nil, dir.."plugins")
AddToMenuEx ("evp", "Chess",           nil, dir.."chess")

-- cross in the editor
MakeResident(dir.."cross")
