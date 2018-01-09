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

intptr_t LUAPLUG ConvertChunk(const wchar_t *ChunkIn, wchar_t **ChunkOut) // возвращает TRUE/FALSE
{
  lua_State *L = GetLuaState();
  *ChunkOut = NULL;

  if (L && Api.GetExportFunction(L, "ConvertChunk"))     //+1: Func
  {
    Api.push_utf8_string(L, ChunkIn, -1);  //+2
    if(Api.pcall_msg(L, 1, 1) == 0)     //+1
    {
      if(lua_isstring(L, -1))
      {
        const wchar_t* p = Api.utf8_to_utf16(L, -1, NULL);
        if(p)
          *ChunkOut = _wcsdup(p);
      }
      lua_pop(L, 1);
    }
  }
  return *ChunkOut != NULL;
}

void LUAPLUG FreeChunk(wchar_t *ChunkOut)
{
  if(ChunkOut) free(ChunkOut);
}

int luaopen_macro2lua (lua_State *L)
{
  PSInfo = GetPluginStartupInfo();
  Api.StructSize = sizeof(Api);
  LF_GetLuafarAPI(&Api);
  return 0;
}
