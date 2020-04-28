# Highlight: Makefile

# adjust the 3 lines below according to your configuration
PROJECT = highlight
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

MYOBJECTS = highlight.o
MYLUAOPEN_LIST = luaopen_highlight

MYCFLAGS = -I$(PATH_LUAFARSRC) -DRUN_LUAFAR_INIT
embed: MYCFLAGS = -I$(PATH_LUAFARSRC)

T_MESSAGE =
EMBED_METHOD = luasrcdiet

bootscript = $(path_plugin)\$(PROJECT).lua

scripts = \
  $(path_plugin)\_globalinfo.lua

modules = \
  $(path_share)*shmuz\serial.lua     \
  $(path_share)*far2\history.lua     \
  $(path_share)*far2\dialog.lua

# Do not include PROCESSEDITOREVENT - it is in "highlight.c".
FAR_EXPORTS = OPEN

TEMPL       =
TEMPL_SCR   =
RCFILE      = highlight.rc
HELP        =

include $(COMMON_MAK)
