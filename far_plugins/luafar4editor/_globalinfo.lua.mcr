function export.GetGlobalInfo()
  return {
    Version       = { #{VER_MAJOR}, #{VER_MINOR}, #{VER_MICRO}, 0 },
    MinFarVersion = #{MINFARVERSION},
    Guid          = win.Uuid("6f332978-08b8-4919-847a-efbb6154c99a"),
    Title         = "LuaFAR for Editor",
    Description   = "A host for scripts and script packets",
    Author        = "Shmuel Zeigerman",
  }
end
