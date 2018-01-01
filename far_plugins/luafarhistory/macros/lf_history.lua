local LFHistory = "a745761d-42b5-4e67-83da-f07af367ae86"
local function LFH_exist() return Plugin.Exist(LFHistory) end
local function LFH_run(key) if Plugin.Menu(LFHistory) then Keys(key) end end

Macro {
  description="LuaFAR History: commands";
  area="Shell Info QView Tree"; key="AltF8";
  condition=LFH_exist; action=function() LFH_run"1" end;
}

Macro {
  description="LuaFAR History: view/edit";
  area="Shell Editor Viewer"; key="AltF11";
  condition=LFH_exist; action=function() LFH_run"2" end;
}

Macro {
  description="LuaFAR History: folders";
  area="Shell"; key="AltF12";
  condition=LFH_exist; action=function() LFH_run"3" end;
}

Macro {
  description="LuaFAR History: locate file";
  area="Shell"; key="CtrlSpace";
  condition=LFH_exist; action=function() LFH_run"5" end;
}
