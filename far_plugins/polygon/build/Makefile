# Highlight: Makefile

# adjust the 3 lines below according to your configuration
PROJECT = polygon
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

MYCFLAGS = -I$(PATH_LUAFARSRC) -DRUN_LUAFAR_INIT
embed: MYCFLAGS = -I$(PATH_LUAFARSRC)

T_MESSAGE =
EMBED_METHOD = luasrcdiet

bootscript = $(path_plugin)\$(PROJECT).lua

scripts = \
  $(path_plugin)\_globalinfo.lua

modules = \
  $(path_plugin)*modules\editor.lua      \
  $(path_plugin)*modules\exporter.lua    \
  $(path_plugin)*modules\panel.lua       \
  $(path_plugin)*modules\progress.lua    \
  $(path_plugin)*modules\settings.lua    \
  $(path_plugin)*modules\sqlite.lua      \
  $(path_plugin)*modules\string_rc.lua   \
  $(path_plugin)*modules\utils.lua       \
  $(path_share)*far2\history.lua         \
  $(path_share)*serial.lua

FAR_EXPORTS = \
  ANALYSE            \
  CLOSEPANEL         \
  COMPARE            \
  CONFIGURE          \
  DELETEFILES        \
  FREEFINDDATA       \
  GETFINDDATA        \
  GETOPENPANELINFO   \
  OPEN               \
  PROCESSPANELEVENT  \
  PROCESSPANELINPUT  \
  SETDIRECTORY

TEMPL       =
TEMPL_SCR   =
RCFILE      = $(PROJECT).rc
HELP        =

include $(COMMON_MAK)
