local files = {
  module = "tmpp_message.lua";
  { filename = "tmpp_eng.lng"; line1 = ".Language=English,English" },
  { filename = "tmpp_rus.lng"; line1 = ".Language=Russian,Russian (Русский)" },
};

-- arg[1]     : output directory; may be nil;
-- arg[2,...] : template files; one file at least
require ("far2.makelang")(files, ...)
