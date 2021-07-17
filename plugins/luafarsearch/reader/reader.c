// started: 2012-02-05
#include <lua.h>
#include <lauxlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Lua versions: 5.1 to 5.4 */
#if LUA_VERSION_NUM > 501
  #define luaL_register(L,n,l)	(luaL_setfuncs(L,l,0))
#endif

#define CHUNK 0x4000 // 16 Kib

const char ReaderType[] = "LFSearch.ChunkReader";

typedef struct {
  FILE *fp;       // FILE object
  size_t overlap; // number of CHUNKs in overlap (this value does not change after initialization)
  size_t top;     // number of CHUNKs currently read
  char *data;     // allocated memory buffer
} TReader;

int NewReader (lua_State *L)
{
  TReader* ud = (TReader*)lua_newuserdata(L, sizeof(TReader));
  memset(ud, 0, sizeof(TReader));
  ud->overlap = luaL_checkinteger(L, 1) / 2 / CHUNK;
  if (ud->overlap == 0) ud->overlap = 1;
  ud->data = malloc(ud->overlap * 2 * CHUNK);
  if (ud->data == NULL) return 0;
  luaL_getmetatable(L, ReaderType);
  lua_setmetatable(L, -2);
  return 1;
}

TReader* GetReader (lua_State *L, int pos)
{
  return (TReader*) luaL_checkudata(L, pos, ReaderType);
}

TReader* CheckReader (lua_State *L, int pos)
{
  TReader* ud = luaL_checkudata(L, pos, ReaderType);
  if (ud->data == NULL) luaL_argerror(L, pos, "attempt to access a deleted reader");
  return ud;
}

TReader* CheckReaderWithFile (lua_State *L, int pos)
{
  TReader* ud = CheckReader(L, pos);
  if (ud->fp == NULL) luaL_argerror(L, pos, "attempt to access a closed reader file");
  return ud;
}

int Reader_getnextchunk (lua_State *L)
{
  TReader *ud = CheckReaderWithFile(L, 1);
  size_t M = ud->overlap;
  size_t N = M * 2;
  size_t top = ud->top;
  size_t tail = 0;
  int firstread = (0 == ftello64(ud->fp));

  if (feof(ud->fp) || ferror(ud->fp))
    return 0;
  if (top == N) {
    memcpy(ud->data, ud->data + M*CHUNK, M*CHUNK);
    top = M; ud->top = M;
  }
  while (top < N) {
    tail = fread(ud->data + top*CHUNK, 1, CHUNK, ud->fp);
    if (tail == CHUNK) {
      tail = 0;
      ++top;
    }
    else
      break;
  }
  if (top == ud->top && tail == 0)
  {
    if (firstread)
      { lua_pushstring(L, ""); return 1; }
    else
      return 0;
  }
  ud->top = top;
  lua_pushlstring(L, ud->data, ud->top * CHUNK + tail);
  return 1;
}

int Reader_delete (lua_State *L)
{
  TReader *ud = GetReader(L, 1);
  if (ud->fp) {
    fclose(ud->fp);
    ud->fp = NULL;
  }
  if (ud->data) {
    free(ud->data);
    ud->data = NULL;
  }
  return 0;
}

int Reader_ftell (lua_State *L)
{
  TReader *ud = CheckReaderWithFile(L, 1);
  lua_pushnumber(L, ftello64(ud->fp));
  return 1;
}

int Reader_closefile (lua_State *L)
{
  int ret = 0;
  TReader *ud = CheckReader(L, 1);
  if (ud->fp) {
    ret = fclose(ud->fp);
    ud->fp = NULL;
  }
  lua_pushinteger(L, ret);
  return 1;
}

int Reader_openfile (lua_State *L)
{
  int ret = 0;
  TReader *ud = CheckReader(L, 1);

  (void)luaL_checkstring(L, 2);
  lua_pushvalue(L, 2);
  lua_pushliteral(L, "\0");
  lua_concat(L, 2);

  FILE *fp = _wfopen((const wchar_t*)lua_tostring(L, -1), L"rb");
  if (fp) {
    if (ud->fp) fclose(ud->fp);
    ud->fp = fp;
    ud->top = 0;
    ret = 1;
  }
  lua_pushboolean(L, ret);
  return 1;
}

int Reader_getsize (lua_State *L)
{
  TReader *ud = CheckReader(L, 1);
  lua_pushnumber(L, ud->overlap * 2 * CHUNK);
  return 1;
}

const luaL_Reg funcs[] = {
  { "new", NewReader },
  { NULL, NULL }
};

const luaL_Reg methods[] = {
  { "__gc",      Reader_delete },
  { "closefile", Reader_closefile },
  { "delete",    Reader_delete },
  { "ftell",     Reader_ftell },
  { "openfile",  Reader_openfile },
  { "get_next_overlapped_chunk", Reader_getnextchunk },
  { "getsize",   Reader_getsize },
  { NULL, NULL }
};

int luaopen_reader (lua_State *L)
{
  luaL_newmetatable(L, ReaderType);

  luaL_register(L, NULL, methods);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");

  luaL_register(L, NULL, funcs);
  return 1;
}
