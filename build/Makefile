# LuaFAR for Editor: Makefile

# adjust the line below according to your configuration
COMMON_MAK = ../../common.mak

ifeq ($(ARCH),-m64)
  TARGET_N = lf4ed-x64.dll
  TARGET_E = lf4ed_e-x64.dll
else
  TARGET_N = lf4ed.dll
  TARGET_E = lf4ed_e.dll
endif

TARGET_M = $(path_plugin)/lf4ed_message.lua
EMBED_METHOD = -strip

bootscript = $(path_plugin)*lf4ed.lua

scripts = \
  $(path_plugin)*_globalinfo.lua \
  $(path_plugin)*config.lua      \
  $(path_plugin)*expression.lua  \
  $(path_plugin)*wrap.lua

modules = \
  $(path_plugin)*sortdialog.lua     \
  $(path_plugin)*sortlines.lua      \
  $(path_share)*serial.lua          \
  $(path_share)*strict.lua          \
  $(path_share)*far2/history.lua    \
  $(path_share)*far2/dialog.lua     \
  $(path_share)*far2/utils.lua      \
  $(path_share)*far2/searchmenu.lua \
  $(path_share)*far2/makelang.lua

FAR_EXPORTS = \
  CONFIGURE           \
  EXITFAR             \
  OPEN                \
  PROCESSEDITOREVENT  \
  PROCESSEDITORINPUT  \
  PROCESSVIEWEREVENT

RCFILE    = lf4ed.rc
TEMPL     = lf4ed_lang.templ
TEMPL_SCR = lf4ed_lang.lua

include $(COMMON_MAK)
