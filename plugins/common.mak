#  Makefile for a FAR plugin containing embedded Lua modules and/or scripts.
#  The target embeds Lua scripts and has dependencies on Lua and LuaFAR DLLs.

ifneq ($(CROOT),C:\Shmuel_Home)

#---------------------------- SETTINGS TO BE CONFIGURED BY THE USER ----------
  # 32 or 64-bit plugin; override from command line if needed
  DIRBIT = 32

  # Root work directory - relative to plugins' "build" directories
  rootpath = $(abspath ../../..)

  # Location of Far Manager source directory
  farsource = C:/farmanager

  # Location of Far Manager installations for 32 and 64 bits
  farhome = C:/Far3-$(DIRBIT)bit

  # Lua 5.1 interpreter (any bitness; if not on PATH specify the full path)
  LUA = lua.exe
#---------------------------- END OF USER'S SETTINGS -------------------------

else
  DIRBIT    = 32
  rootpath  = $(abspath ../../../..)
  farsource = $(CROOT)/work/farmanager
  farhome   = $(CROOT)/Programs/Far3-$(DIRBIT)bit
  LUA       = lua.exe
  ifeq ($(EMBED_METHOD),luajit)
    LUAC = $(CROOT)/Programs/Exe$(DIRBIT)/LuaJIT/luajit.exe
  else ifeq ($(EMBED_METHOD),luac)
    LUAC = $(CROOT)/Programs/Exe$(DIRBIT)/luac.exe
  endif
#---------------------------- END OF Shmuel's SETTINGS -----------------------
endif

ifndef EMBED_METHOD
EMBED_METHOD = luasrcdiet
endif

# Location of LuaFAR source directory
PATH_LUAFARSRC = $(farsource)/plugins/luamacro/luafar

# Include paths
INC_LUA = $(farsource)/plugins/luamacro/luasdk/include
INC_FAR = $(farsource)/plugins/common/unicode
INCLUDE = -I$(INC_LUA) -I$(INC_FAR) -I$(PATH_LUAFARSRC)

# Location of DLLs
LUADLL    = $(farhome)/lua51.dll
LUAFARDLL = $(farhome)/luafar3.dll

path_share = $(rootpath)/lua_share
path_run   = $(rootpath)/lua_run

# Lua interpreter (any bitness)
LUAEXE = $(LUA) -epackage.path=[[$(path_share)/?.lua]]

vpath %.c $(path_plugin)

ifeq ($(DIRBIT),64)
  ARCH = -m64
  T_NOEMBED = $(OUTDIR)/$(PROJECT)-x64.dll
  T_EMBED = $(OUTDIR)/$(PROJECT)_e-x64.dll
  RESFLAGS = -F pe-x86-64
else
  ARCH = -m32
  T_NOEMBED = $(OUTDIR)/$(PROJECT).dll
  T_EMBED = $(OUTDIR)/$(PROJECT)_e.dll
  RESFLAGS = -F pe-i386
endif

ifdef EMBED
  OUTDIR = Out$(DIRBIT)_embed
  LUAOPEN_LIST = $(LUAOPEN_EMBED) $(MYLUAOPEN_LIST)
  TARGETS = $(T_EMBED) $(T_MESSAGE) $(GLOBINFO) $(HELP)
else
  OUTDIR = Out$(DIRBIT)
  LUAOPEN_LIST = $(MYLUAOPEN_LIST)
  TARGETS = $(T_NOEMBED) $(T_MESSAGE) $(GLOBINFO) $(HELP)
endif

MYOBJECTS_D = $(MYOBJECTS:%.o=$(OUTDIR)/%.o)

ifndef LUAPLUG
LUAPLUG = $(PATH_LUAFARSRC)\luaplug.c
endif

LUAOPEN_EMBED = luaopen_embed
LUAOPEN_MAIN = luaopen_main

GLOBINFO   = $(path_plugin)/_globalinfo.lua
C_EMBED    = $(OUTDIR)/$(PROJECT)_embed.c
OBJ_EMBED  = $(OUTDIR)/$(PROJECT)_embed.o
C_MAIN     = $(OUTDIR)/$(PROJECT)_main.c
OBJ_MAIN   = $(OUTDIR)/$(PROJECT)_main.o
OBJ_PLUG   = $(OUTDIR)/$(PROJECT)_plug.o
OBJ_RC     = $(OUTDIR)/$(RCFILE:%.rc=%-rc.o)
VERSION_H  = $(OUTDIR)/version.h

EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))

OBJ_N  = $(OBJ_PLUG) $(OBJ_MAIN) $(OBJ_RC) $(MYOBJECTS_D)
OBJ_E  = $(OBJ_N) $(OBJ_EMBED)
CFLAGS = -O2 -Wall $(INCLUDE) $(ARCH) $(EXPORTS) -DFUNC_OPENLIBS=$(LUAOPEN_MAIN) $(MYCFLAGS)

CC = gcc

LIBS    = $(LUADLL) $(LUAFARDLL)
LDFLAGS = -Wl,--kill-at -shared -s $(ARCH) -static-libgcc

all:     $(OUTDIR) $(TARGETS)
help:    $(HELP)

$(OUTDIR)/%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(T_NOEMBED): $(OBJ_N) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(T_EMBED): $(OBJ_E) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(T_MESSAGE): FORCE
	cd $(path_plugin) && $(LUAEXE) $(TEMPL_SCR) $(TEMPL)

$(OBJ_PLUG): $(LUAPLUG)
	$(CC) -c $< -o $@ $(CFLAGS)

$(OBJ_RC): $(RCFILE) $(VERSION_H)
	copy $(RCFILE) $(OUTDIR)
	windres $(OUTDIR)/$(RCFILE) -o $@ $(RESFLAGS)

$(C_EMBED): $(T_MESSAGE)
ifndef NO_MACRO_GENERATE
	$(MAKE) -B $(VERSION_H) $(GLOBINFO)
endif
	$(LUAEXE) $(path_run)/embed.lua embed @target=$@ @method=$(EMBED_METHOD) @compiler=$(LUAC) \
    @bootscript=$(bootscript) @luaopen=$(LUAOPEN_EMBED) -scripts $(scripts) -modules $(modules)

$(C_MAIN):
	$(LUAEXE) $(path_run)/embed.lua openlibs @target=$@ @luaopen=$(LUAOPEN_MAIN) \
    -funclist $(LUAOPEN_LIST)

ifndef NO_MACRO_GENERATE
$(GLOBINFO) $(HELP) : % : %.mcr define.lua
	$(LUAEXE) -erequire([[shmuz.macro]])([[define.lua]],[[$<]],[[$@]])

$(VERSION_H) : version.h.mcr define.lua
	$(LUAEXE) -erequire([[shmuz.macro]])([[define.lua]],[[$<]],[[$@]])
endif

$(OUTDIR):
	mkdir $@

clean:
	rmdir /s /q $(OUTDIR)
	if exist luac.out del luac.out

.PHONY: clean all help FORCE
