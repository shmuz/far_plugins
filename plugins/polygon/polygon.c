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

// !!! PRIVATE API from LuaFAR's exported.c
void PushPluginTable(lua_State* L, HANDLE hPlugin)
{
  lua_pushlightuserdata(L, hPlugin);       // for LuaFAR builds >= 721
  lua_rawget(L, LUA_REGISTRYINDEX);
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    lua_pushinteger(L, (intptr_t)hPlugin); // for LuaFAR builds < 721
    lua_rawget(L, LUA_REGISTRYINDEX);
  }
}

// !!! PRIVATE API from exported.c
void PushPluginObject(lua_State* L, HANDLE hPlugin)
{
  PushPluginTable(L, hPlugin);
  if (lua_istable(L, -1)) {
    lua_getfield(L, -1, "Panel_Object"); // for LuaFAR builds >= 746
    if (!lua_istable(L, -1)) {
      lua_pop(L, 1);
      lua_getfield(L, -1, "Object");     // for LuaFAR builds < 746
    }
  }
  else
    lua_pushnil(L);
  lua_remove(L, -2);
}

intptr_t LUAPLUG CompareW(const struct CompareInfo *Info)
{
  intptr_t ret = 0, index;
  lua_State *L = GetLuaState();

  PushPluginObject(L, Info->hPanel); //+1
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 0;
  }
  lua_getfield(L, -1, "sort_callback");          //+2
  lua_pushvalue(L, -2);                          //+3
  lua_pushinteger(L, Info->Mode);                //+4
  lua_call(L, 2, 1);                             //+2
  index = lua_tointeger(L, -1);
  lua_pop(L, 2);                                 //+0
  if (index < 1) // index < 1 is treated as the return value (either 0 or -2)
    return index;
  else {
    --index;
    ret = CompareStringW(LOCALE_USER_DEFAULT, NORM_IGNORECASE | SORT_STRINGSORT,
      Info->Item1->CustomColumnData[index], -1, Info->Item2->CustomColumnData[index], -1);
    return ret==0 ? 0 : ret-2;
  }
}
