# macro2lua Far Manager plugin: makefile.

# adjust the 3 lines below according to your configuration
PROJECT = macro2lua
path_plugin = .
COMMON_MAK = common.mak

MYOBJECTS = macro2lua.o
MYLUAOPEN_LIST = luaopen_macro2lua
MYCFLAGS = -I$(PATH_LUAFARSRC)
NO_MACRO_GENERATE = 1

EMBED_METHOD = luasrcdiet

bootscript = $(path_plugin)\$(PROJECT).lua
scripts    = $(path_plugin)\_globalinfo.lua
modules    = $(path_plugin)*macrosyn.lua

FAR_EXPORTS = OPEN

include $(COMMON_MAK)
