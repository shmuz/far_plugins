#  Makefile for a FAR plugin containing embedded Lua modules and/or scripts.
#  The target embeds Lua scripts and has dependencies on Lua and LuaFAR DLLs.

#------------------------------------ SETTINGS TO BE CONFIGURED BY THE USER --
# 32 or 64-bit plugin
ARCH = -m32

# Root work directory
WORKDIR = s:/progr/work
path_share = $(WORKDIR)/lua_share
path_plugin = ..

# Location of LuaFAR source directory
PATH_LUAFARSRC = $(WORKDIR)/luafar/luafar_unicode/src

# Include paths
INC_LUA = $(WORKDIR)/system/include
INC_FAR = $(WORKDIR)/system/include/far/unicode

# Location of executable files and DLLs
ifeq ($(ARCH),-m64)
  PATH_EXE = c:/exe64
else
  PATH_EXE = c:/exe
endif

LUAEXE = $(PATH_EXE)/lua.exe
LUAC   = $(PATH_EXE)/luac.exe
LUADLL = $(PATH_EXE)/lua5.1.dll
LUAFARDLL = $(PATH_EXE)/luafar3.dll
#------------------------------------ END OF USER'S SETTINGS -----------------

ifeq ($(ARCH),-m64)
  RESFLAGS = -F pe-x86-64
else
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

bootscript4 = $(subst *,/,$(bootscript))
scripts4    = $(subst *,/,$(scripts))
modules4    = $(subst *,/,$(modules))

LUAPLUG     = $(PATH_LUAFARSRC)/luaplug.c
C_INIT      = $(TARGET_E)_init.c
OBJ_INIT    = $(TARGET_E)_init.o
OBJ_PLUG_N  = $(TARGET_N)_plug.o
OBJ_PLUG_E  = $(TARGET_E)_plug.o
OBJ_RC      = $(patsubst %.rc,%.o,$(RCFILE))

EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))

OBJ_N    = $(OBJ_PLUG_N) $(OBJ_RC)
OBJ_E    = $(OBJ_INIT) $(OBJ_PLUG_E) $(OBJ_RC)
CFLAGS   = -O2 -Wall -I$(INC_LUA) -I$(INC_FAR) $(ARCH) $(EXPORTS)
CFLAGS_E = $(CFLAGS) -DFUNC_OPENLIBS=luafar_openlibs

CC = gcc

LIBS    = $(LUADLL) $(LUAFARDLL)
LDFLAGS = -Wl,--kill-at -shared -s $(ARCH)

noembed: $(TARGET_N) $(TARGET_M)
embed:   $(TARGET_E) $(TARGET_M)
all:     noembed embed

%.o : %.rc
	windres $< -o $@ $(RESFLAGS)

$(TARGET_N): $(OBJ_N) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(TARGET_E): $(OBJ_E) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(TARGET_M): $(addprefix $(path_plugin)/,$(TEMPL))
	cd $(path_plugin) && $(LUAEXE) -epackage.path='$(path_share_abs)/?.lua' $(TEMPL_SCR) $(TEMPL)

$(OBJ_PLUG_N): $(LUAPLUG)
	$(CC) -c $< -o $@ $(CFLAGS)

$(OBJ_PLUG_E): $(LUAPLUG)
	$(CC) -c $< -o $@ $(CFLAGS_E)

$(C_INIT): $(bootscript4) $(scripts4) $(modules4)
	$(LUAEXE) -erequire(\'embed\')([[$@]],[[$(EMBED_METHOD)]],[[$(LUAC)]],$(bootscript3),$(scripts3),$(modules3))

clean:
	del *.o *.dll luac.out $(C_INIT)

.PHONY: noembed embed clean all
