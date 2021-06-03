local info = {
  Version       = { #{VER_MAJOR}, #{VER_MINOR}, #{VER_MICRO}, 0 },
  MinFarVersion = #{MINFARVERSION},
  Guid          = win.Uuid("D4BC5EA7-8229-4FFE-AAC1-5A4F51A0986A"),
  Title         = "Polygon",
  Description   = "Plugin for viewing and editing SQLite3 database files",
  Author        = "Shmuel Zeigerman",
}

function export.GetGlobalInfo() return info; end
