//---------------------------------------------------------------------------
#include <plugin.hpp>
#include <lua.h>
#include <luafar.h>

#ifdef _MSC_VER
#define LUAPLUG WINAPI
#else
#define LUAPLUG WINAPI __declspec(dllexport)
#endif

extern struct PluginStartupInfo* GetPluginStartupInfo();
extern lua_State* GetLuaState();

struct PluginStartupInfo *PSInfo;
LuafarAPI Api;

enum { CMP_ALPHA=0, CMP_INT=1, CMP_FLOAT=2, };

struct {
  int valid;
  intptr_t index;
  intptr_t mode;
} SortParams;

intptr_t LUAPLUG CompareW(const struct CompareInfo *Info)
{
  intptr_t index, ret;

  if (!SortParams.valid)
  {
    // This is the first CompareW() call in the current sort operation.
    // Retrieve parameters from the Lua script and set SortParams.valid=1 to ensure
    // the parameters are retrieved only once for the current sort operation.
    intptr_t encoded = LF_Compare(GetLuaState(), Info);
    SortParams.index = (intptr_t)(encoded & 0xFF) - 2;
    SortParams.mode = (encoded >> 8);
    SortParams.valid = 1;
  }
  index = SortParams.index;
  if (index < 1) // index < 1 is treated as the return value (either 0 or -2)
  {
    return index;
  }
  else
  {
    const wchar_t *str1 = Info->Item1->CustomColumnData[--index];
    const wchar_t *str2 = Info->Item2->CustomColumnData[index];
    long long i1, i2;
    double d1, d2;
    switch(SortParams.mode)
    {
      case CMP_INT:
        if (swscanf(str1, L"%lld", &i1) && swscanf(str2, L"%lld", &i2) && i1 != i2)
          return i1<i2 ? -1 : 1;
        break;
      case CMP_FLOAT:
        if (swscanf(str1, L"%lf", &d1) && swscanf(str2, L"%lf", &d2) && d1 != d2)
          return d1<d2 ? -1 : 1;
        break;
    }
    ret = CompareStringW(LOCALE_USER_DEFAULT, NORM_IGNORECASE | SORT_STRINGSORT, str1, -1, str2, -1);
    return ret==0 ? 0 : ret-2;
  }
}

// This function is called whenever ProcessPanelEvent(FE_REDRAW) comes from Far.
// The idea is that FE_REDRAW is always called after sort operation is finished
// but is never called in the middle of a sort operation.
static int ResetSort(lua_State *L)
{
  (void) L;
  SortParams.valid = 0;
  return 0;
}

int luaopen_polygon (lua_State *L)
{
  lua_pushcfunction(L, ResetSort);
  lua_setglobal(L, "polygon_ResetSort");
  return 0;
}
