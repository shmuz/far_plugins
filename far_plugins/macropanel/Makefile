# ---- user's settings -------------------------------------------------------

ifeq ($(DIRBIT),64)
  TARGET = mpanel-x64.dll
else
  TARGET = mpanel.dll
endif

FARDIR = C:/farmanager

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

# ---- end of user's settings ------------------------------------------------

include $(FARDIR)\plugins\luamacro\luafar\luaplug.mak

# (end of Makefile)
