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

// EditorGetString (EditorId, line_num)
//
//   line_num:  number of line in the Editor, a 1-based integer.
//
//   return:    StringText (as light userdata), StringLength.
//
static int EditorGetString (lua_State *L)
{
  intptr_t EditorId = luaL_optinteger(L, 1, CURRENT_EDITOR);
  intptr_t line_num = luaL_optinteger(L, 2, 0) - 1;
  struct EditorGetString egs;
  egs.StructSize = sizeof(egs);
  egs.StringNumber = line_num < -1 ? -1 : line_num;

  if (PSInfo->EditorControl(EditorId, ECTL_GETSTRING, 0, &egs))
  {
    lua_pushlightuserdata(L, (void*)egs.StringText);
    lua_pushnumber(L, egs.StringLength);
    return 2;
  }
  return lua_pushnil(L), 1;
}

int luaopen_highlight (lua_State *L)
{
  PSInfo = GetPluginStartupInfo();

  Api.StructSize = sizeof(Api);
  LF_GetLuafarAPI(&Api);

  lua_createtable(L, 0, 1);
  lua_pushcfunction(L, EditorGetString);
  lua_setfield(L, -2, "EditorGetString");
  lua_setglobal(L, "highlight");
  return 0;
}

intptr_t LUAPLUG ProcessEditorEventW (const struct ProcessEditorEventInfo *Info)
{
  intptr_t ret = 0;
  lua_State *L = GetLuaState();

  if (L && Api.GetExportFunction(L, "ProcessEditorEvent"))     //+1: Func
  {
    lua_pushinteger(L, Info->EditorID); //+2;
    lua_pushinteger(L, Info->Event);    //+3;

    switch (Info->Event)
    {
      case EE_CHANGE:
      {
        const struct EditorChange *ec = (const struct EditorChange*) Info->Param;
        lua_createtable(L, 0, 2);
        Api.PutNumToTable(L, "Type", ec->Type);
        Api.PutNumToTable(L, "StringNumber", (double)(ec->StringNumber+1));
        break;
      }
      case EE_SAVE:
      {
        struct EditorSaveFile *esf = (struct EditorSaveFile*)Info->Param;
        lua_createtable(L, 0, 3);
        Api.PutWStrToTable(L, "FileName", esf->FileName, -1);
        Api.PutWStrToTable(L, "FileEOL", esf->FileEOL, -1);
        Api.PutIntToTable(L, "CodePage", esf->CodePage);
        break;
      }
      default:
        lua_pushinteger(L, (intptr_t)Info->Param);
        break;
    }

    if(Api.pcall_msg(L, 3, 1) == 0)       //+1
    {
      if (lua_isnumber(L,-1)) ret = lua_tointeger(L,-1);

      lua_pop(L,1);
    }
  }

  return ret;
}
