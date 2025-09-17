local files = {
  module = "lfh_message.lua";
  { filename = "lfh_eng.lng"; line1 = ".Language=English,English" },
  { filename = "lfh_rus.lng"; line1 = ".Language=Russian,Russian (Русский)" },
  { filename = "lfh_spa.lng"; line1 = ".Language=Spanish,Spanish (Español)" }
};

-- arg[1]     : output directory; may be nil;
-- arg[2,...] : template files; one file at least
require ("far2.makelang")(files, ...)
