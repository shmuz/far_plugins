------------------------------------------------------------------------------
-- LuaFAR Search --
------------------------------------------------------------------------------

local Guid = "8E11EA75-0303-4374-AC60-D1E38F865449"

local NEW_VERSION do
  local handle = far.FindPlugin("PFM_GUID", win.Uuid(Guid))
  if not handle then return end
  local info = far.GetPluginInformation(handle)
  local v = info.GInfo.Version
  v = 1e6*v[1] + 1e3*v[2] + v[3]
  NEW_VERSION = v >= 3008000
end

local function LFS_Editor(...) Plugin.Call(Guid, "own", "editor", ...) end
local function LFS_Panels(...) Plugin.Call(Guid, "own", "panels", ...) end

Macro {
  description="LuaFAR Search: Editor Find";
  area="Editor"; key="F3";
  action = function()
    if NEW_VERSION then LFS_Editor "search"
    else Plugin.Menu(Guid); Keys("1")
    end
  end
}

Macro {
  description="LuaFAR Search: Editor Replace";
  area="Editor"; key="CtrlF3";
  action = function()
    if NEW_VERSION then LFS_Editor "replace"
    else Plugin.Menu(Guid); Keys("2")
    end
  end
}

Macro {
  description="LuaFAR Search: Editor Repeat";
  area="Editor"; key="ShiftF3";
  action = function()
    if NEW_VERSION then LFS_Editor "repeat"
    else Plugin.Menu(Guid); Keys("3")
    end
  end
}

if NEW_VERSION then
  Macro {
    description="LuaFAR Search: Editor Repeat reverse";
    area="Editor"; key="AltF3";
    action = function() LFS_Editor "repeat_rev" end
  }

  Macro {
    description="LuaFAR Search: Editor search word";
    area="Editor"; key="Alt6";
    action = function() LFS_Editor "searchword" end
  }

  Macro {
    description="LuaFAR Search: Editor search word reverse";
    area="Editor"; key="Alt5";
    action = function() LFS_Editor "searchword_rev" end
  }

  -- Uncomment this macro if it is needed.
  -- Macro {
  --   description="LuaFAR Search: Reset Highlight";
  --   area="Editor"; key="Alt7";
  --   action = function() LFS_Editor "resethighlight" end
  -- }

  Macro {
    description="LuaFAR Search: Toggle Highlight";
    area="Editor"; key="Alt7";
    action = function() LFS_Editor "togglehighlight" end
  }

  Macro {
    description="LuaFAR Search: Editor Multi-line replace";
    area="Editor"; key="CtrlShiftF3";
    action = function() LFS_Editor "mreplace" end
  }
end

Macro {
  description="LuaFAR Search: Panel Find";
  area="Shell QView Tree Info"; key="CtrlShiftF";
  action = function()
    if NEW_VERSION then LFS_Panels "search"
    else Plugin.Menu(Guid); Keys("1")
    end
  end
}

Macro {
  description="LuaFAR Search: Panel Replace";
  area="Shell QView Tree Info"; key="CtrlShiftG";
  action = function()
    if NEW_VERSION then LFS_Panels "replace"
    else Plugin.Menu(Guid); Keys("2")
    end
  end
}

if NEW_VERSION then
  Macro {
    description="LuaFAR Search: Panel Grep";
    area="Shell QView Tree Info"; key="CtrlShiftH";
    action = function() LFS_Panels "grep" end
  }

  Macro {
    description="LuaFAR Search: Panel Rename";
    area="Shell QView Tree Info"; key="CtrlShiftJ";
    action = function() LFS_Panels "rename" end
  }

  Macro {
    description="LuaFAR Search: Show Panel";
    area="Shell QView Tree Info"; key="CtrlShiftK";
    action = function() LFS_Panels "panel" end
  }

  -- This macro works best when "Show line numbers" Grep option is used.
  -- When this option is off the jump occurs to the beginning of the file.
  Macro {
    description="Jump from Grep results to file and position under cursor";
    area="Editor"; key="CtrlShiftG";
    action=function()
      local lnum = editor.GetString(nil,nil,3):match("^(%d+)[:%-]")
      local EI = editor.GetInfo()
      for n = EI.CurLine,1,-1 do
        local fname = editor.GetString(nil,n,3):match("^%[%d+%]%s+(.-) : %d+$")
        if fname then
          editor.Editor(fname,nil,nil,nil,nil,nil,
            {EF_NONMODAL=1,EF_IMMEDIATERETURN=1,EF_ENABLE_F6=1,EF_OPENMODE_USEEXISTING=1},
            lnum or 1, lnum and math.max(1, EI.CurPos-lnum:len()-1) or 1)
          break
        end
      end
    end;
  }
end
