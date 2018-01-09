function export.GetGlobalInfo()
  return {
    Version       = { #{VER_MAJOR}, #{VER_MINOR}, #{VER_MICRO}, 0 },
    MinFarVersion = #{MINFARVERSION},
    Guid          = win.Uuid("8e11ea75-0303-4374-ac60-d1e38f865449"),
    Title         = "LuaFAR Search",
    Description   = "Plugin for search and replace",
    Author        = "Shmuel Zeigerman",
  }
end
