#  Makefile for a FAR plugin containing embedded Lua modules and/or scripts.
#  The target embeds Lua scripts and has dependencies on Lua and LuaFAR DLLs.

#------------------------------------ SETTINGS TO BE CONFIGURED BY THE USER --
# 32 or 64-bit plugin
ARCH = -m32

# Root work directory
WORKDIR = s:/progr/work
path_share = $(WORKDIR)/lua_share

# Location of LuaFAR source directory
PATH_LUAFARSRC = $(WORKDIR)/luafar/luafar_unicode/src

# Include paths
INC_LUA = $(WORKDIR)/system/include
INC_FAR = $(WORKDIR)/system/include/far/unicode

# Location of executable files and DLLs
ifeq ($(ARCH),-m64)
  PATH_EXE = c:/exe64
else
  PATH_EXE = c:/exe32
endif

LUAEXE = $(PATH_EXE)/lua.exe
LUADLL = $(PATH_EXE)/lua5.1.dll
LUAFARDLL = $(PATH_EXE)/luafar3.dll

ifeq ($(EMBED_METHOD),luajit)
  LUAC = $(PATH_EXE)/luajit.exe
else
  LUAC = $(PATH_EXE)/luac.exe
endif
#------------------------------------ END OF USER'S SETTINGS -----------------

ifeq ($(ARCH),-m64)
  T_NOEMBED = $(PROJECT)-x64.dll
  T_EMBED = $(PROJECT)_e-x64.dll
  RESFLAGS = -F pe-x86-64
else
  T_NOEMBED = $(PROJECT).dll
  T_EMBED = $(PROJECT)_e.dll
  RESFLAGS = -F pe-i386
endif

path_share_abs = $(abspath $(path_share))

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

GLOBINFO    = $(path_plugin)\_globalinfo.lua
LUAPLUG     = $(PATH_LUAFARSRC)\luaplug.c
C_INIT      = $(T_EMBED)_init.c
OBJ_INIT    = $(T_EMBED)_init.o
OBJ_PLUG_N  = $(T_NOEMBED)_plug.o
OBJ_PLUG_E  = $(T_EMBED)_plug.o
OBJ_RC      = $(patsubst %.rc,%$(ARCH).o,$(RCFILE))

EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))

OBJ_N    = $(OBJ_PLUG_N) $(OBJ_RC)
OBJ_E    = $(OBJ_INIT) $(OBJ_PLUG_E) $(OBJ_RC)
CFLAGS   = -O2 -Wall -I$(INC_LUA) -I$(INC_FAR) $(ARCH) $(EXPORTS)
CFLAGS_E = $(CFLAGS) -DFUNC_OPENLIBS=luafar_openlibs

CC = gcc

LIBS    = $(LUADLL) $(LUAFARDLL)
LDFLAGS = -Wl,--kill-at -shared -s $(ARCH)

noembed: $(T_NOEMBED) $(T_MESSAGE) $(GLOBINFO) $(HELP)
embed:   $(T_EMBED) $(T_MESSAGE) $(HELP)
all:     noembed embed

$(T_NOEMBED): $(OBJ_N) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(T_EMBED): $(OBJ_E) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(T_MESSAGE): $(addprefix $(path_plugin)/,$(TEMPL))
	cd $(path_plugin) && $(LUAEXE) -epackage.path='$(path_share_abs)/?.lua' $(TEMPL_SCR) $(TEMPL)

$(OBJ_PLUG_N): $(LUAPLUG)
	$(CC) -c $< -o $@ $(CFLAGS)

$(OBJ_PLUG_E): $(LUAPLUG)
	$(CC) -c $< -o $@ $(CFLAGS_E)

$(OBJ_RC): $(RCFILE) version.h
	windres $< -o $@ $(RESFLAGS)

$(C_INIT): $(bootscript4) $(scripts4) $(modules4)
	$(LUAEXE) -erequire(\'embed\')([[$@]],[[$(EMBED_METHOD)]],[[$(LUAC)]],$(bootscript3),$(scripts3),$(modules3))

version.h release.mak $(GLOBINFO) $(HELP) : % : %.mcr define.lua
	$(LUAEXE) -erequire([[macro]])([[define.lua]],[[$<]],[[$@]])

### Release section ##########################################################
release: release.mak
	$(MAKE) -f$< all

srelease: release.mak
	$(MAKE) -f$< src

brelease: release.mak
	$(MAKE) -f$< bin

##############################################################################

clean:
	del *.o *.dll luac.out luajitc.out $(C_INIT)
	del release.mak version.h

.PHONY: noembed embed clean all release srelease brelease
