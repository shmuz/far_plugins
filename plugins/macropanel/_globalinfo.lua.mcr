function export.GetGlobalInfo()
  return {
    Version       = { #{VER_MAJOR}, #{VER_MINOR}, #{VER_MICRO}, 0 };
    MinFarVersion = #{MINFARVERSION};
    Guid          = win.Uuid("10F1979B-668A-4681-9879-3A789B143493");
    Title         = "Macro Panel";
    Description   = "Panel-mode macro browser";
    Author        = "Shmuel Zeigerman";
    ----
    StartDate     = "2013-10-30";
    Dependencies  = "";
  }
end
