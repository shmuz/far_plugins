local files = {
  module = "modules\\string_rc.lua";
  { filename = "polygon_en.lng"; line1 = ".Language=English,English" },
  { filename = "polygon_ru.lng"; line1 = ".Language=Russian,Russian (Русский)" },
};

-- arg[1]     : output directory; may be nil;
-- arg[2,...] : template files; one file at least
require ("far2.makelang")(files, ...)
