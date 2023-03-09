-- Definitions
VER_MAJOR = "1"
VER_MINOR = "8"
VER_MICRO = "0"

-- Far >= 3.0.4364 required if -DRUN_LUAFAR_INIT is used
-- Far >= 3.0.4401 required if more than 10 DB table columns must be supported
-- Far >= 3.0.5416: sortings by CtrlF3/F4/etc. work; related to LuaFAR build 691: versions >= 1.7.0 aren't affected
MINFARVERSION = "{ 3, 0, 0, 4401 }"

COPYRIGHT = "Shmuel Zeigerman, 2018-2023"

-- Derivative values --
VER_STRING = VER_MAJOR.."."..VER_MINOR.."."..VER_MICRO
