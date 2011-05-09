# LuaFAR for Editor: Makefile

#------------------------------------ SETTINGS TO BE CONFIGURED BY THE USER --
# 32 or 64-bit plugin
ARCH = -m32

# Location of LuaFAR base directory
PATH_LUAFAR = ..\..\..\luafar_unicode

# This file must be configured by the user
include $(PATH_LUAFAR)\config.mak
#------------------------------------ END OF USER'S SETTINGS -----------------

LUAC        = $(LUADLLPATH)\luac.exe
PATH_AUXIL  = $(PATH_LUAFAR)\auxil
PATH_LUAFARSRC = $(PATH_LUAFAR)\src
PATH_PLUGIN = ..\lf4ed
PATH_SCRIPT = ..\script
SCRIPTS     = luaplug.lua config.lua expression.lua wrap.lua
GEN_METHOD  =
MAKE_LANG   = $(LUAEXE) -epackage.path='../lua_share/?.lua' lf4ed_lang.lua

CC          = gcc
INC         = -I$(INC_LUA) -I$(INC_FAR)
CONFIG      = lf4ed.cfg

ifeq ($(ARCH),-m64)
  TRG1      = luaplug-x64.dll
  TRG2      = lf4ed-x64.dll
  RESTARGET = -F pe-x86-64
else
  TRG1      = luaplug.dll
  TRG2      = lf4ed.dll
  RESTARGET = -F pe-i386
endif

CFLAGS      = -O2 -Wall $(INC) $(ARCH) -D_export=
CFLAGS1     = $(CFLAGS) -DBUILD_STATIC $(EXPORTS)
CFLAGS2     = $(CFLAGS1) -DFUNC_OPENLIBS=luafar_openlibs

OBJ1        = luaplug1.o
OBJ2        = luaplug2.o linit.o lf4ed.o

LIBS1       = $(LUADLLPATH)\$(LUAFARDLL)
LIBS2       = $(LIBS1) $(LUADLLPATH)\$(LUADLLNAME).dll

MYLDFLAGS   = -Wl,--kill-at -shared -s $(ARCH)

EXPORTS = \
  -DEXPORT_CONFIGUREW           \
  -DEXPORT_EXITFARW             \
  -DEXPORT_OPENPLUGINW          \
  -DEXPORT_PROCESSEDITOREVENTW  \
  -DEXPORT_PROCESSEDITORINPUTW  \
  -DEXPORT_PROCESSVIEWEREVENTW  \
  -DEXPORT_PROCESSSYNCHROEVENTW

%.o : %.rc
	windres $< -o $@ $(RESTARGET)
#-----------------------------------------------------------------------------

embed: $(TRG2)
	copy /y $< $(PATH_PLUGIN)
	$(MAKE) auxilfiles
	cd $(PATH_PLUGIN) && $(MAKE_LANG)

noembed: $(TRG1)
	$(MAKE) cleanplug
	copy /y $< $(PATH_PLUGIN)
	copy /y $(PATH_SCRIPT)\*.lua $(PATH_PLUGIN)
	$(MAKE) auxilfiles
	cd $(PATH_PLUGIN) && $(MAKE_LANG)

$(TRG1): $(OBJ1) $(LIBS1)
	$(CC) -o $@ $^ $(MYLDFLAGS)

$(TRG2): $(OBJ2) $(LIBS2)
	$(CC) -o $@ $^ $(MYLDFLAGS)

# Since linit.c has changing prerequisites (sets of Lua files),
# that can not be specified in this makefile, it is better be
# rebuilt unconditionally; hence use of the double-colon rule.
linit.c::
	$(LUAEXE) -erequire(\'generate\')([[$(CONFIG)]],[[$@]],[[$(GEN_METHOD)]],[[$(LUAC)]])

luaplug1.o: $(PATH_LUAFARSRC)\luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS1)

luaplug2.o: $(PATH_LUAFARSRC)\luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS2)

auxilfiles: $(PATH_AUXIL)
	cd $(PATH_AUXIL) && $(MAKE)
	copy /y $(PATH_AUXIL)\farcolor.lua $(PATH_PLUGIN)
	copy /y $(PATH_AUXIL)\farkeys.lua $(PATH_PLUGIN)

cleanplug:
	cd $(PATH_PLUGIN) && del *.dll *.d $(SCRIPTS) farcolor.lua farkeys.lua

cleansrc:
	del *.o *.dll luac.out linit.c

clean:
	$(MAKE) cleanplug cleansrc

.PHONY: noembed embed auxilfiles clean cleanplug cleansrc

