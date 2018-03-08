# ---- user's settings -------------------------------------------------------

ifeq ($(DIRBIT),64)
  TARGET = polygon-x64.dll
else
  TARGET = polygon.dll
endif

FARDIR = $(CROOT)\work\farmanager
PATH = $(GCC$(DIRBIT))
MYLDFLAGS = -L$(CROOT)\Programs\Far3-$(DIRBIT)bit

# Run "%FARPROFILE%\luafar_init.lua" on start-up:
MYCFLAGS = -DRUN_LUAFAR_INIT

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

# ---- end of user's settings ------------------------------------------------

include $(FARDIR)\plugins\luamacro\luafar\luaplug.mak

# (end of Makefile)
