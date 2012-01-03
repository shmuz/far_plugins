local PluginDir = far.PluginStartupInfo().ModuleName:match(".+\\")
local dir = "scripts/examples/"
local HelpDir = PluginDir..dir

-- editor menu
AddToMenu ("e", ":sep:")
AddToMenu ("e", "Fill selection", "Ctrl+M", dir.."fill_selection")

-- panels menu
AddToMenu ("p", "Rename",      nil, dir.."lf_rename", "<"..HelpDir..">Rename")
AddToMenu ("p", "SelectingEx", nil, dir.."selectingEx")

AddToMenu ("evp", "Plugins control", nil, dir.."plugins")
AddToMenu ("evp", "Chess",           nil, dir.."chess")
