function export.GetGlobalInfo()
  return {
    Version       = { #{VER_MAJOR}, #{VER_MINOR}, #{VER_MICRO}, 0 },
    MinFarVersion = #{MINFARVERSION},
    Guid          = win.Uuid("e2500d1c-d1d2-4c4c-91c0-6864f2aaf5e8"),
    Title         = "LuaFAR Temp. Panel",
    Description   = "A Lua clone of TmpPanel plugin",
    Author        = "Shmuel Zeigerman",
  }
end
