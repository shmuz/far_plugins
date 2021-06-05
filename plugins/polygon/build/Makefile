# Makefile

# adjust the 3 lines below according to your configuration
PROJECT = polygon
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

MYOBJECTS = polygon.o

# Note: Far build >= 3.0.4364 required if -DRUN_LUAFAR_INIT is used
MYCFLAGS = -DRUN_LUAFAR_INIT

T_MESSAGE = $(path_plugin)\modules\string_rc.lua

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
  $(path_share)*far2\settings.lua        \
  $(path_share)*far2\simpledialog.lua

# Do not include COMPARE - it is in "polygon.c".
FAR_EXPORTS = \
  ANALYSE            \
  CLOSEPANEL         \
  CONFIGURE          \
  DELETEFILES        \
  FREEFINDDATA       \
  GETFINDDATA        \
  GETOPENPANELINFO   \
  OPEN               \
  PROCESSPANELEVENT  \
  PROCESSPANELINPUT  \
  SETDIRECTORY

TEMPL     = polygon_lang.templ
TEMPL_SCR = polygon_lang.lua
RCFILE    = $(PROJECT).rc
HELP      =

include $(COMMON_MAK)
