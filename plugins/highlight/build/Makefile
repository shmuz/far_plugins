# Highlight: Makefile

# adjust the 3 lines below according to your configuration
PROJECT = highlight
path_plugin = ..
COMMON_MAK = $(path_plugin)\..\common.mak

T_MESSAGE =

bootscript = $(path_plugin)\$(PROJECT).lua

scripts = \
  $(path_plugin)\_globalinfo.lua

modules = \
  $(path_share)*far2\settings.lua     \
  $(path_share)*far2\simpledialog.lua

FAR_EXPORTS = OPEN PROCESSEDITOREVENT

TEMPL       =
TEMPL_SCR   =
RCFILE      = highlight.rc
HELP        =

include $(COMMON_MAK)
