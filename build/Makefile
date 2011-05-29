# LuaFAR for Editor: Makefile

#------------------------------------ SETTINGS TO BE CONFIGURED BY THE USER --
# 32 or 64-bit plugin
ARCH = -m32

# Location of LuaFAR base directory
PATH_LUAFAR = ..\..\..\luafar_unicode

# Location of Lua modules
PATH_SHARE = ..\lua_share

# This file must be configured by the user
include $(PATH_LUAFAR)\config.mak
#------------------------------------ END OF USER'S SETTINGS -----------------

PATH_PLUGIN = ..
PATH_SHARE_ABS = $(abspath $(PATH_SHARE))

bootscript = $(PATH_PLUGIN)*luaplug.lua

scripts = \
  $(PATH_PLUGIN)*_globalinfo.lua \
  $(PATH_PLUGIN)*config.lua      \
  $(PATH_PLUGIN)*expression.lua  \
  $(PATH_PLUGIN)*wrap.lua

modules = \
  $(PATH_PLUGIN)*sortdialog.lua     \
  $(PATH_PLUGIN)*sortlines.lua      \
  $(PATH_SHARE)*serial.lua          \
  $(PATH_SHARE)*strict.lua          \
  $(PATH_SHARE)*far2\history.lua    \
  $(PATH_SHARE)*far2\dialog.lua     \
  $(PATH_SHARE)*far2\utils.lua      \
  $(PATH_SHARE)*far2\searchmenu.lua \
  $(PATH_SHARE)*far2\makelang.lua

comma:= ,
empty:=
space:= $(empty) $(empty)

scripts2 = [[-s]],$(addsuffix ]],$(addprefix [[,$(scripts)))
modules2 = [[-m]],$(addsuffix ]],$(addprefix [[,$(modules)))

bootscript3 = [[$(bootscript)]]
scripts3    = $(subst $(space),$(comma),$(scripts2))
modules3    = $(subst $(space),$(comma),$(modules2))

bootscript4 = $(subst *,\,$(bootscript))
scripts4    = $(subst *,\,$(scripts))
modules4    = $(subst *,\,$(modules))

LUAC        = $(LUADLLPATH)\luac.exe
PATH_LUAFARSRC = $(PATH_LUAFAR)\src
GEN_METHOD  = -strip
MAKE_LANG   = $(LUAEXE) -epackage.path='$(PATH_SHARE_ABS)/?.lua' lf4ed_lang.lua

CC          = gcc
INC         = -I$(INC_LUA) -I$(INC_FAR)

ifeq ($(ARCH),-m64)
  TRG1      = luaplug-x64.dll
  TRG2      = lf4ed-x64.dll
  RESTARGET = -F pe-x86-64
else
  TRG1      = luaplug.dll
  TRG2      = lf4ed.dll
  RESTARGET = -F pe-i386
endif

CFLAGS      = -O2 -Wall $(INC) $(ARCH)
CFLAGS1     = $(CFLAGS) -DBUILD_STATIC $(EXPORTS)
CFLAGS2     = $(CFLAGS1) -DFUNC_OPENLIBS=luafar_openlibs

OBJ1        = luaplug1.o
OBJ2        = luaplug2.o linit.o lf4ed.o

LIBS1       = $(LUADLLPATH)\$(LUAFARDLL)
LIBS2       = $(LIBS1) $(LUADLLPATH)\$(LUADLLNAME).dll

MYLDFLAGS   = -Wl,--kill-at -shared -s $(ARCH)

EXPORTS = \
  -DEXPORT_CONFIGURE           \
  -DEXPORT_EXITFAR             \
  -DEXPORT_OPEN                \
  -DEXPORT_PROCESSEDITOREVENT  \
  -DEXPORT_PROCESSEDITORINPUT  \
  -DEXPORT_PROCESSVIEWEREVENT

%.o : %.rc
	windres $< -o $@ $(RESTARGET)
#-----------------------------------------------------------------------------

noembed: $(TRG1)
	cd $(PATH_PLUGIN) && $(MAKE_LANG)
#	copy /y $< $(PATH_PLUGIN)

embed: $(TRG2)
	cd $(PATH_PLUGIN) && $(MAKE_LANG)
#	copy /y $< $(PATH_PLUGIN)

$(TRG1): $(OBJ1) $(LIBS1)
	$(CC) -o $@ $^ $(MYLDFLAGS)

$(TRG2): $(OBJ2) $(LIBS2)
	$(CC) -o $@ $^ $(MYLDFLAGS)

linit.c: $(bootscript4) $(scripts4) $(modules4)
	$(LUAEXE) -erequire(\'generate\')([[$@]],[[$(GEN_METHOD)]],[[$(LUAC)]],$(bootscript3),$(scripts3),$(modules3))

luaplug1.o: $(PATH_LUAFARSRC)\luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS1)

luaplug2.o: $(PATH_LUAFARSRC)\luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS2)

clean:
	del *.o *.dll luac.out linit.c

.PHONY: noembed embed clean

