function export.GetGlobalInfo()
  return {
    Version       = { 0, 8, 0, 0 },
    MinFarVersion = { 3, 0, 0, 4164 },
    Guid          = win.Uuid("50b1abe5-91ba-478c-be2d-64366a81d47c"),
    Title         = "Macro2Lua converter",
    Description   = "Converter from macro language to Lua",
    Author        = "Shmuel Zeigerman",
    -----------------------------------------------------------------
    --MinLuafarVersion = { 3, 1, 0 },
  }
end
