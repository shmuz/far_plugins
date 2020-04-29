# LuaFAR TmpPanel: Makefile

# adjust the 3 lines below according to your configuration
PROJECT = lftmppanel
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

T_MESSAGE = $(path_plugin)\tmpp_message.lua

bootscript = $(path_plugin)\$(PROJECT).lua

scripts = $(path_plugin)\_globalinfo.lua

modules = \
  $(path_plugin)*tmpp_message.lua  \
  $(path_share)*shmuz\serial.lua   \
  $(path_share)*strict.lua         \
  $(path_share)*far2\history.lua   \
  $(path_share)*far2\tmppanel.lua  \
  $(path_share)*far2\dialog.lua    \
  $(path_share)*far2\utils.lua

FAR_EXPORTS = \
  ANALYSE           \
  CLOSEANALYSE      \
  CLOSEPANEL        \
  CONFIGURE         \
  EXITFAR           \
  GETFINDDATA       \
  GETOPENPANELINFO  \
  OPEN              \
  PROCESSPANELEVENT \
  PROCESSPANELINPUT \
  PUTFILES          \
  SETDIRECTORY      \
  SETFINDLIST

MYCFLAGS  = -DRUN_LUAFAR_INIT
TEMPL     = tmpp_lang.templ
TEMPL_SCR = tmpp_lang.lua
RCFILE    = tmppanel.rc
HELP      = $(path_plugin)\LuaTmpEng.hlf $(path_plugin)\LuaTmpRus.hlf

include $(COMMON_MAK)
