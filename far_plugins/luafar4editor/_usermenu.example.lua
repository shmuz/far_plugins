-- This is an example of "user menu file".
-- To make it active, rename it to _usermenu.lua, then either restart Far,
-- or run "Reload User File" from the plugin's configuration menu.
-- *** For more details, see the plugin's manual ***

-- Assign shortcuts to the plugin's built-in utilities.
-- Assigning shortcuts is possible only in Editor.
AddToMenu ("e", true, "Alt+1", 1)
AddToMenu ("e", true, "Alt+2", 2)
AddToMenu ("e", true, "Alt+3", 3)
AddToMenu ("e", true, "Alt+4", 4)
AddToMenu ("e", true, "Alt+5", 5)
AddToMenu ("e", true, "Alt+6", 6)
AddToMenu ("e", true, "Alt+7", 7)

-- Utility for viewing and editing Lua variables.
AddToMenu ("evp", "Table View", nil, function() require"far2.tableview"("_G") end)

-- Add a menu item to the plugin menus in Editor, Viewer and Panels ("evp").
-- Activating this menu item will execute a script, specified in the 4-th
-- argument (.lua extension should be omitted).
AddToMenu ("evp", "Hello, Lua", nil, "scripts/examples/hello")

-- Add another user menu file from the "scripts" subtree.
AddUserFile ("scripts/examples/_usermenu.lua")
