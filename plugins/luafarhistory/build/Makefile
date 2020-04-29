# LuaFAR History: Makefile

# adjust the 3 lines below according to your configuration
PROJECT = lfhistory
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

T_MESSAGE = $(path_plugin)\lfh_message.lua

bootscript = $(path_plugin)\$(PROJECT).lua

scripts = \
  $(path_plugin)\_globalinfo.lua \
  $(path_plugin)\lfh_message.lua \
  $(path_plugin)\config.lua

modules = \
  $(path_share)*shmuz\serial.lua     \
  $(path_share)*far2\history.lua     \
  $(path_share)*far2\custommenu.lua  \
  $(path_share)*far2\dialog.lua      \
  $(path_share)*far2\utils.lua

FAR_EXPORTS = CONFIGURE OPEN

MYCFLAGS    = -DRUN_LUAFAR_INIT
TEMPL       = lfh_lang.templ
TEMPL_SCR   = lfh_lang.lua
RCFILE      = lfhistory.rc
HELP        = $(path_plugin)\lfh_eng.hlf $(path_plugin)\lfh_rus.hlf

include $(COMMON_MAK)
