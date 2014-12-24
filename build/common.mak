#  Makefile for a FAR plugin containing embedded Lua modules and/or scripts.
#  The target embeds Lua scripts and has dependencies on Lua and LuaFAR DLLs.

#------------------------------------ SETTINGS TO BE CONFIGURED BY THE USER --
# 32 or 64-bit plugin
DIRBIT = 32

# Root work directory
WORKDIR = S:/progr/work
path_share = $(WORKDIR)/lua_share
path_run   = $(WORKDIR)/lua_run

# Location of FAR source directory
FARDIR = C:/farmanager

# Location of LuaFAR source directory
PATH_LUAFARSRC = $(FARDIR)/plugins/luamacro/luafar

# Include paths
INC_LUA = $(WORKDIR)/system/include/lua/5.1
INC_FAR = $(FARDIR)/plugins/common/unicode

# Location of executable files and DLLs
PATH_EXE  = C:/EXE$(DIRBIT)
LUAEXE    = $(PATH_EXE)/lua.exe
LUADLL    = $(PATH_EXE)/lua51.dll
LUAFARDLL = $(FARDIR)/unicode_far/Release.$(DIRBIT).gcc/luafar3.dll

ifeq ($(EMBED_METHOD),luajit)
  LUAC = $(PATH_EXE)/LuaJIT/luajit.exe
else
  LUAC = $(PATH_EXE)/luac.exe
endif
#------------------------------------ END OF USER'S SETTINGS -----------------

vpath %.c $(path_plugin)

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

ifndef LUAPLUG
LUAPLUG = $(PATH_LUAFARSRC)\luaplug.c
endif

LUAOPEN_EMBED = luaopen_embed
LUAOPEN_MAIN = luaopen_main

noembed: LUAOPEN_LIST = $(MYLUAOPEN_LIST)
embed:   LUAOPEN_LIST = $(LUAOPEN_EMBED) $(MYLUAOPEN_LIST)

GLOBINFO   = $(path_plugin)\_globalinfo.lua
C_EMBED    = $(T_NOEMBED)_embed.c
OBJ_EMBED  = $(T_NOEMBED)_embed.o
C_MAIN     = $(T_NOEMBED)_main.c
OBJ_MAIN   = $(T_NOEMBED)_main.o
OBJ_PLUG_N = $(T_NOEMBED)_plug.o
OBJ_PLUG_E = $(T_EMBED)_plug.o
OBJ_RC     = $(patsubst %.rc,%$(ARCH).o,$(RCFILE))

EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))

OBJ_N  = $(OBJ_PLUG_N) $(OBJ_MAIN) $(OBJ_RC) $(MYOBJECTS)
OBJ_E  = $(OBJ_PLUG_E) $(OBJ_MAIN) $(OBJ_RC) $(MYOBJECTS) $(OBJ_EMBED)
CFLAGS = -O2 -Wall -I$(INC_LUA) -I$(INC_FAR) $(ARCH) $(EXPORTS) $(MYCFLAGS) \
         -DFUNC_OPENLIBS=$(LUAOPEN_MAIN)

CC = gcc

LIBS    = $(LUADLL) $(LUAFARDLL)
LDFLAGS = -Wl,--kill-at -shared -s $(ARCH)

noembed: $(T_NOEMBED) $(T_MESSAGE) $(GLOBINFO) $(HELP)
embed:   $(T_EMBED) $(T_MESSAGE) $(GLOBINFO) $(HELP)
all:     noembed embed

$(T_NOEMBED): $(OBJ_N) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(T_EMBED): $(OBJ_E) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(T_MESSAGE): $(addprefix $(path_plugin)/,$(TEMPL))
	cd $(path_plugin) && $(LUAEXE) -epackage.path='$(path_share)/?.lua' $(TEMPL_SCR) $(TEMPL)

$(OBJ_PLUG_N): $(LUAPLUG)
	$(CC) -c $< -o $@ $(CFLAGS)

$(OBJ_PLUG_E): $(LUAPLUG)
	$(CC) -c $< -o $@ $(CFLAGS)

$(OBJ_RC): $(RCFILE) version.h
	windres $< -o $@ $(RESFLAGS)

$(C_EMBED): $(bootscript) $(scripts)
	$(LUAEXE) $(path_run)/embed.lua embed @target=$@ @method=$(EMBED_METHOD) @compiler=$(LUAC) \
    @bootscript=$(bootscript) @luaopen=$(LUAOPEN_EMBED) -scripts $(scripts) -modules $(modules)

$(C_MAIN):
	$(LUAEXE) $(path_run)/embed.lua openlibs @target=$@ @luaopen=$(LUAOPEN_MAIN) \
    -funclist $(LUAOPEN_LIST)

ifndef NO_MACRO_GENERATE
version.h $(GLOBINFO) $(HELP) : % : %.mcr define.lua
	$(LUAEXE) -erequire([[macro]])([[define.lua]],[[$<]],[[$@]])
endif

clean:
	del *.o *.dll luac.out luajitc.out $(C_EMBED) $(C_MAIN)
	del version.h

.PHONY: noembed embed clean all
