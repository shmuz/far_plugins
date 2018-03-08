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
  $(path_plugin)\_globalinfo.lua \
  $(path_plugin)\editor.lua      \
  $(path_plugin)\exporter.lua    \
  $(path_plugin)\panel.lua       \
  $(path_plugin)\progress.lua    \
  $(path_plugin)\settings.lua    \
  $(path_plugin)\sqlite.lua      \
  $(path_plugin)\string_rc.lua

modules = \
  $(path_share)*far2\utils.lua   \
  $(path_share)*far2\history.lua \
  $(path_share)*serial.lua

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

TEMPL       =
TEMPL_SCR   =
RCFILE      = $(PROJECT).rc
HELP        =

include $(COMMON_MAK)
