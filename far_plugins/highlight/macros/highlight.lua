------------------------------------------------------------------------------
-- Highlight --
------------------------------------------------------------------------------

local Guid = "F6138DC9-B1C4-40D8-AAF4-6B5CEC0F6C68"
local function Exist() return Plugin.Exist(Guid) end

Macro {
  description="Highlight: Select Syntax menu";
  area="Editor"; key="CtrlShift8"; condition=Exist;
  action = function() Plugin.Call(Guid, "own", "SelectSyntax") end;
}

Macro {
  description="Highlight: Highlight Extra";
  area="Editor"; key="CtrlShift9"; condition=Exist;
  action = function() Plugin.Call(Guid, "own", "HighlightExtra") end;
}

Macro {
  description="Highlight: Settings dialog";
  area="Editor"; key="CtrlShift0"; condition=Exist;
  action = function() Plugin.Call(Guid, "own", "Settings") end;
}
