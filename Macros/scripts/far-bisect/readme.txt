// coding:UTF-8
1. The main dialog
===================

  ╔═══════ Bisect Far builds ════════╗
  ║ (•) x86  ( ) x64                 ║ Installations to test: x86 (32 bit) or x64 (64 bit).

  ║ [x] Automatic operation          ║ The script will not ask the user whether the build was "good"
                                       or "bad". If Far.exe returned 99 (farbisect.AUTO_GOOD) to OS
                                       then the build was "good", otherwise "bad".

  ║ Which builds to test:            ║ Select which Far builds should be tested. Several options
  ║ ................................↓║ are available.

  ║ Command line arguments:          ║ Command line for running Far.exe without Far.exe itself
  ║ ................................↓║ (it is inserted by the script).

  ║ Command line Macro code:         ║ Command line Macro code - neither "lua:" nor double quotes
  ║ ................................↓║ around are needed (they are inserted by the script).

  ╟──────────────────────────────────╢
  ║ Known good build .....           ║ Known good build (e.g. 3456). May be left empty (see Note 1).
  ║ Known bad  build .....           ║ Known  bad build (e.g. 4567). May be left empty (see Note 1).

  ║ Internet                         ║ Use/don't use Internet for downloading Far builds.
  ║ (•) None ( ) Wget ( ) Luasec     ║ Don't use / Use wget.exe / Use LuaSec library

  ╟──── Install: ────────────────────╢
  ║ [x] 1 Default.farconfig          ║ Copy file Default.farconfig to the tested %FARHOME% directory.
  ║ [x] 2 Macros                     ║ Unpack Opt.MacroArchive to the tested %FARPROFILE%\Macros directory.
  ║ [x] 3 Custom archive             ║ Unpack Opt.CustomArchive to the tested %FARHOME% directory.

  ║ [x] 4 Text C0                    ║ Install this plugin (if it's available for a given Far build).
  ║ [x] 5 LF for Editor              ║ Ditto.
  ║ [x] 6 LF Search                  ║ Ditto.
  ║ [x] 7 LF History                 ║ Ditto.
  ║ [x] 8 Highlight                  ║ Ditto.
  ╟──────────────────────────────────╢
  ║        { OK } [ Cancel ]         ║
  ╚══════════════════════════════════╝

This dialog sets parameters for the subsequent operation.
Other parameters (that change rarely) are kept in the file far-bisect.cfg.

Note 1: To specify Far1.75 build number start it with 0, e.g. 02634 means Far 1.75.2634.
        Otherwise Far2/Far3 build number is assumed.

2. Non-dialog mode
===================
local farbisect = require "farbisect"
farbisect.Main(<params>)
  params: table; all fields are optional; default for booleans is false;
  {
    x64       -- boolean
    automatic -- boolean
    text_c0   -- boolean
    lf4ed     -- boolean
    lfs       -- boolean
    lfh       -- boolean
    highlight -- boolean

    minbuild  -- number (note 2). Meaning: do not test builds less than that.
    maxbuild  -- number (note 2). Meaning: do not test builds greater than that.
    goodbuild -- number (note 2). Meaning: this build is known as "good".
    badbuild  -- number (note 2). Meaning: this build is known as "bad".

    cmdline   -- string
    macrocode -- string (the script encloses this string in double quotes)
    farconfig -- string/boolean - filename (use true for a default filename)
    macros    -- string/boolean - filename (use true for a default filename)
    custom    -- string - filename
  }

Note 2:
  Far2.0 and Far3.0 builds should be specified as is, e.g. Far3.0.5000 should be specified as 5000.
  Far1.75 builds should be specified as <build>-3000, e.g Far1.75.2634 should be specified as (2634-3000).
  This number (3000) is referenced as farbisect.FAR1_OFFSET.
