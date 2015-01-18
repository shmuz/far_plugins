# ---- user's settings -------------------------------------------------------

ifeq ($(DIRBIT),64)
  TARGET = mpanel-x64.dll
else
  TARGET = mpanel.dll
endif

FARDIR = C:/farmanager/unicode_far
PATH_LUAFAR = $(FARDIR)/../plugins/luamacro/luafar

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

vpath %.h $(PATH_LUAFAR);$(FARDIR)/../plugins/common/unicode
vpath %.c $(PATH_LUAFAR)

include $(PATH_LUAFAR)\luaplug.mak

# (end of Makefile)
