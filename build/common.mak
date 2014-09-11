#  Makefile for a FAR plugin containing embedded Lua modules and/or scripts.
#  The target embeds Lua scripts and has dependencies on Lua and LuaFAR DLLs.

#------------------------------------ SETTINGS TO BE CONFIGURED BY THE USER --
# 32 or 64-bit plugin
DIRBIT = 32

# Root work directory
WORKDIR = S:\progr\work
path_share = $(WORKDIR)/lua_share

# Location of FAR source directory
FARDIR = C:\farmanager\unicode_far

# Location of LuaFAR source directory
PATH_LUAFARSRC = $(FARDIR)/../plugins/luamacro/luafar

# Include paths
INC_LUA = $(WORKDIR)/system/include/lua/5.1
INC_FAR = $(FARDIR)/../plugins/common/unicode

# Location of executable files and DLLs
PATH_EXE  = c:/exe$(DIRBIT)
LUAEXE    = $(PATH_EXE)/lua.exe
LUADLL    = $(PATH_EXE)/lua51.dll
LUAFARDLL = $(FARDIR)\Release.$(DIRBIT).gcc/luafar3.dll

ifeq ($(EMBED_METHOD),luajit)
  LUAC = $(PATH_EXE)/LuaJIT/luajit.exe
else
  LUAC = $(PATH_EXE)/luac.exe
endif
#------------------------------------ END OF USER'S SETTINGS -----------------

ARCH = -m$(DIRBIT)

ifeq ($(DIRBIT),64)
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

scripts2 = $(addsuffix ]],$(addprefix [[,$(scripts)))
modules2 = $(addsuffix ]],$(addprefix [[,$(modules)))

bootscript3 = [[$(bootscript)]]
scripts3    = $(subst $(space),$(comma),$(scripts2))
modules3    = $(subst $(space),$(comma),$(modules2))

bootscript4 = $(subst *,\,$(bootscript))
scripts4    = $(subst *,\,$(scripts))
modules4    = $(subst *,\,$(modules))

ifndef LUAPLUG
LUAPLUG     = $(PATH_LUAFARSRC)\luaplug.c
endif

GLOBINFO    = $(path_plugin)\_globalinfo.lua
C_INIT      = $(T_EMBED)_init.c
OBJ_INIT    = $(T_EMBED)_init.o
OBJ_PLUG_N  = $(T_NOEMBED)_plug.o
OBJ_PLUG_E  = $(T_EMBED)_plug.o
OBJ_RC      = $(patsubst %.rc,%$(ARCH).o,$(RCFILE))

EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))

OBJ_N    = $(OBJ_PLUG_N) $(OBJ_RC)
OBJ_E    = $(OBJ_INIT) $(OBJ_PLUG_E) $(OBJ_RC)
CFLAGS   = -O2 -Wall -I$(INC_LUA) -I$(INC_FAR) $(ARCH) $(EXPORTS) $(MYCFLAGS)
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
	$(LUAEXE) -e "require('embed')\
	  ([[$@]], [[$(EMBED_METHOD)]], [[$(LUAC)]],\
	  $(bootscript3), {$(scripts3)}, {$(modules3)})"

ifndef NO_MACRO_GENERATE
version.h release.mak $(GLOBINFO) $(HELP) : % : %.mcr define.lua
	$(LUAEXE) -erequire([[macro]])([[define.lua]],[[$<]],[[$@]])
endif

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
