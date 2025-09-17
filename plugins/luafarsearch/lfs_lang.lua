local files = {
  module = "lfs_message.lua";
  { filename = "lfs_eng.lng"; line1 = ".Language=English,English" },
  { filename = "lfs_rus.lng"; line1 = ".Language=Russian,Russian (Русский)" },
  { filename = "lfs_spa.lng"; line1 = ".Language=Spanish,Spanish (Español)" }
};

-- arg[1]     : output directory; may be nil;
-- arg[2,...] : template files; one file at least
require ("far2.makelang")(files, ...)
