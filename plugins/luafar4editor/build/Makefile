# LuaFAR for Editor: Makefile

# adjust the 3 lines below according to your configuration
PROJECT = lf4ed
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

T_MESSAGE = $(path_plugin)\lf4ed_message.lua

bootscript = $(path_plugin)\$(PROJECT).lua

scripts = \
  $(path_plugin)\_globalinfo.lua \
  $(path_plugin)\config.lua      \
  $(path_plugin)\expression.lua  \
  $(path_plugin)\wrap.lua        \
  $(path_share)*far2\tableview.lua

modules = \
  $(path_plugin)*sortdialog.lua     \
  $(path_plugin)*sortlines.lua      \
  $(path_share)*shmuz\serial.lua    \
  $(path_share)*strict.lua          \
  $(path_share)*far2\dialog.lua     \
  $(path_share)*far2\history.lua    \
  $(path_share)*far2\keynames.lua   \
  $(path_share)*far2\makelang.lua   \
  $(path_share)*far2\message.lua    \
  $(path_share)*far2\searchmenu.lua \
  $(path_share)*far2\utils.lua

FAR_EXPORTS = \
  CONFIGURE           \
  EXITFAR             \
  OPEN                \
  PROCESSEDITOREVENT  \
  PROCESSEDITORINPUT  \
  PROCESSVIEWEREVENT

MYCFLAGS  = -DRUN_LUAFAR_INIT
RCFILE    = lf4ed.rc
TEMPL     = lf4ed_lang.templ
TEMPL_SCR = lf4ed_lang.lua
HELP      = $(path_plugin)\lf4ed_eng.hlf $(path_plugin)\lf4ed_rus.hlf

include $(COMMON_MAK)
