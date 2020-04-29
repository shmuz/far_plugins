# Highlight: Makefile

# adjust the 3 lines below according to your configuration
PROJECT = mpanel
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

MYCFLAGS = -I$(PATH_LUAFARSRC) -DRUN_LUAFAR_INIT
embed: MYCFLAGS = -I$(PATH_LUAFARSRC)

T_MESSAGE =

bootscript = $(path_plugin)\$(PROJECT).lua

scripts = \
  $(path_plugin)\_globalinfo.lua

modules =

FAR_EXPORTS = \
  CLOSEPANEL        \
  COMPARE           \
  CONFIGURE         \
  EXITFAR           \
  GETFILES          \
  GETFINDDATA       \
  GETOPENPANELINFO  \
  OPEN              \
  PROCESSPANELEVENT \
  PROCESSPANELINPUT

TEMPL       =
TEMPL_SCR   =
RCFILE      = $(PROJECT).rc
HELP        =

include $(COMMON_MAK)
