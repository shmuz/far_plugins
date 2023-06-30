local info = {
  Version       = { #{VER_MAJOR}, #{VER_MINOR}, #{VER_MICRO}, 0 },
  MinFarVersion = #{MINFARVERSION},
  Guid          = win.Uuid("a745761d-42b5-4e67-83da-f07af367ae86"),
  Title         = "LuaFAR History",
  Description   = "History of commands, files and folders",
  Author        = "Shmuel Zeigerman",
}

function export.GetGlobalInfo() return info; end
