local info = {
  Version       = { #{VER_MAJOR}, #{VER_MINOR}, #{VER_MICRO}, 0 },
  MinFarVersion = #{MINFARVERSION},
  Guid          = win.Uuid("F6138DC9-B1C4-40D8-AAF4-6B5CEC0F6C68"),
  Title         = "Highlight",
  Description   = "Syntax highlighter for editor",
  Author        = "Shmuel Zeigerman",
}

function export.GetGlobalInfo() return info; end
