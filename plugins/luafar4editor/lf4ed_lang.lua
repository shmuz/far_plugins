local files = {
  module = "lf4ed_message.lua";
  { filename = "lf4ed_eng.lng"; line1 = ".Language=English,English" },
  { filename = "lf4ed_rus.lng"; line1 = ".Language=Russian,Russian (Русский)" },
};

-- arg[1]     : output directory; may be nil;
-- arg[2,...] : template files; one file at least
require ("far2.makelang")(files, ...)
