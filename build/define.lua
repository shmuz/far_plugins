-- Definitions

PLUGINVERSION = { 3, 0, 2 }
MINFARVERSION = "{ 3, 0, 0, 2460 }"
MINLUAFARVERSION = "{ 3, 0, 5 }"

-- Derivative values --

local v = PLUGINVERSION
VER_MAJOR, VER_MINOR, VER_MICRO = v[1], v[2], v[3]
VER_STRING = v[1].."."..v[2].."."..v[3]
