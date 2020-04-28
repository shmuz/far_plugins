//---------------------------------------------------------------------------
#include <plugin.hpp>
#include <lua.h>
#include <luafar.h>

#ifndef FILE_ATTRIBUTE_NO_SCRUB_DATA
#define FILE_ATTRIBUTE_NO_SCRUB_DATA 0x20000
#endif

#ifdef _MSC_VER
#define LUAPLUG WINAPI
#else
#define LUAPLUG WINAPI __declspec(dllexport)
#endif

extern struct PluginStartupInfo* GetPluginStartupInfo();
extern lua_State* GetLuaState();

struct PluginStartupInfo *PSInfo;
LuafarAPI Api;
int FileTimeResolution = 1;

const char strFileFindHandle[] = "lfsearch.filefind_handle";

// This function was initially taken from Lua 5.0.2 (loadlib.c)
static void pusherrorcode(lua_State *L, int error)
{
  wchar_t buffer[256];
  const int BUFSZ = ARRAYSIZE(buffer);
  int num = FormatMessageW(FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM,
                           0, error, 0, buffer, BUFSZ, 0);

  if(num)
    Api.push_utf8_string(L, buffer, num);
  else
    lua_pushfstring(L, "system error %d\n", error);
}

static int SysErrorReturn(lua_State *L)
{
  int last_error = GetLastError();
  lua_pushnil(L);
  pusherrorcode(L, last_error);
  return 2;
}

// helper function
static double L64toDouble (unsigned low, unsigned high)
{
  double result = low;
  if(high)
  {
    LARGE_INTEGER large;
    large.LowPart = low;
    large.HighPart = high;
    result = large.QuadPart;
  }
  return result;
}

void PushAttrString(lua_State *L, int attr)
{
  char buf[32], *p = buf;
  if (attr & FILE_ATTRIBUTE_ARCHIVE)             *p++ = 'a';
  if (attr & FILE_ATTRIBUTE_COMPRESSED)          *p++ = 'c';
  if (attr & FILE_ATTRIBUTE_DIRECTORY)           *p++ = 'd';
  if (attr & FILE_ATTRIBUTE_REPARSE_POINT)       *p++ = 'e';
  if (attr & FILE_ATTRIBUTE_HIDDEN)              *p++ = 'h';
  if (attr & FILE_ATTRIBUTE_NOT_CONTENT_INDEXED) *p++ = 'i';
  if (attr & FILE_ATTRIBUTE_ENCRYPTED)           *p++ = 'n';
  if (attr & FILE_ATTRIBUTE_OFFLINE)             *p++ = 'o';
  if (attr & FILE_ATTRIBUTE_SPARSE_FILE)         *p++ = 'p';
  if (attr & FILE_ATTRIBUTE_READONLY)            *p++ = 'r';
  if (attr & FILE_ATTRIBUTE_SYSTEM)              *p++ = 's';
  if (attr & FILE_ATTRIBUTE_TEMPORARY)           *p++ = 't';
  if (attr & FILE_ATTRIBUTE_NO_SCRUB_DATA)       *p++ = 'u';
  if (attr & FILE_ATTRIBUTE_VIRTUAL)             *p++ = 'v';
  lua_pushlstring(L, buf, p-buf);
}

static void SetAttrWords(const char* str, DWORD* incl, DWORD* excl)
{
  *incl=0; *excl=0;
  for (; *str; str++) {
    char c = *str;
    if      (c == 'a')  *incl |= FILE_ATTRIBUTE_ARCHIVE;
    else if (c == 'c')  *incl |= FILE_ATTRIBUTE_COMPRESSED;
    else if (c == 'd')  *incl |= FILE_ATTRIBUTE_DIRECTORY;
    else if (c == 'e')  *incl |= FILE_ATTRIBUTE_REPARSE_POINT;
    else if (c == 'h')  *incl |= FILE_ATTRIBUTE_HIDDEN;
    else if (c == 'i')  *incl |= FILE_ATTRIBUTE_NOT_CONTENT_INDEXED;
    else if (c == 'n')  *incl |= FILE_ATTRIBUTE_ENCRYPTED;
    else if (c == 'o')  *incl |= FILE_ATTRIBUTE_OFFLINE;
    else if (c == 'p')  *incl |= FILE_ATTRIBUTE_SPARSE_FILE;
    else if (c == 'r')  *incl |= FILE_ATTRIBUTE_READONLY;
    else if (c == 's')  *incl |= FILE_ATTRIBUTE_SYSTEM;
    else if (c == 't')  *incl |= FILE_ATTRIBUTE_TEMPORARY;
    else if (c == 'u')  *incl |= FILE_ATTRIBUTE_NO_SCRUB_DATA;
    else if (c == 'v')  *incl |= FILE_ATTRIBUTE_VIRTUAL;

    else if (c == 'A')  *excl |= FILE_ATTRIBUTE_ARCHIVE;
    else if (c == 'C')  *excl |= FILE_ATTRIBUTE_COMPRESSED;
    else if (c == 'D')  *excl |= FILE_ATTRIBUTE_DIRECTORY;
    else if (c == 'E')  *excl |= FILE_ATTRIBUTE_REPARSE_POINT;
    else if (c == 'H')  *excl |= FILE_ATTRIBUTE_HIDDEN;
    else if (c == 'I')  *excl |= FILE_ATTRIBUTE_NOT_CONTENT_INDEXED;
    else if (c == 'N')  *excl |= FILE_ATTRIBUTE_ENCRYPTED;
    else if (c == 'O')  *excl |= FILE_ATTRIBUTE_OFFLINE;
    else if (c == 'P')  *excl |= FILE_ATTRIBUTE_SPARSE_FILE;
    else if (c == 'R')  *excl |= FILE_ATTRIBUTE_READONLY;
    else if (c == 'S')  *excl |= FILE_ATTRIBUTE_SYSTEM;
    else if (c == 'T')  *excl |= FILE_ATTRIBUTE_TEMPORARY;
    else if (c == 'U')  *excl |= FILE_ATTRIBUTE_NO_SCRUB_DATA;
    else if (c == 'V')  *excl |= FILE_ATTRIBUTE_VIRTUAL;
  }
}

static void PutFileTimeToTable(lua_State *L, const char* key, FILETIME ft)
{
  LARGE_INTEGER li;
  li.LowPart = ft.dwLowDateTime;
  li.HighPart = ft.dwHighDateTime;
  if (FileTimeResolution == 2)
  {
    if (Api.bit64_pushuserdata == NULL)
      luaL_error(L, "attempt to call bit64_pushuserdata with old LuaFAR version");
    Api.bit64_pushuserdata(L, li.QuadPart); // will crash if called on Far build < 5550
    lua_setfield(L, -2, key);
  }
  else
    Api.PutNumToTable(L, key, (double)(li.QuadPart/10000));
}

// the table is on the stack top
static void find_filltable(lua_State *L, const WIN32_FIND_DATAW* fd)
{
  Api.PutWStrToTable(L, "FileName",  fd->cFileName, -1);
  Api.PutWStrToTable(L, "AlternateFileName", fd->cAlternateFileName, -1);

  lua_pushstring(L, "FileAttributes");
  PushAttrString(L, fd->dwFileAttributes);
  lua_settable(L, -3);

  Api.PutNumToTable(L, "FileSize", L64toDouble(fd->nFileSizeLow, fd->nFileSizeHigh));

  PutFileTimeToTable(L, "CreationTime",   fd->ftCreationTime);
  PutFileTimeToTable(L, "LastAccessTime", fd->ftLastAccessTime);
  PutFileTimeToTable(L, "LastWriteTime",  fd->ftLastWriteTime);
}

typedef struct {

  WIN32_FIND_DATAW fd;
  HANDLE handle;
  DWORD dwAttrIncl;
  DWORD dwAttrExcl;
  int first_search;
}    TFileFindRecord;

static BOOL FF_CheckAttributes(TFileFindRecord* ff) {
  return ((ff->fd.dwFileAttributes & ff->dwAttrIncl) == ff->dwAttrIncl) &&
         ((ff->fd.dwFileAttributes & ff->dwAttrExcl) == 0);
}

static BOOL FF_Initialize(TFileFindRecord* ff, const wchar_t* w_card, const char* attr) {
  ff->first_search = TRUE;
  SetAttrWords(attr, &ff->dwAttrIncl, &ff->dwAttrExcl);
  ff->handle = FindFirstFileW(w_card, &ff->fd);
  return ff->handle != INVALID_HANDLE_VALUE;
}

static BOOL FF_Finalize(TFileFindRecord* fd) {
  if (fd->handle != INVALID_HANDLE_VALUE) {
    if(!FindClose(fd->handle))
      return FALSE;
    fd->handle = INVALID_HANDLE_VALUE;
  }
  return TRUE;
}

static const WIN32_FIND_DATAW* FF_GetFindData(TFileFindRecord* ff) {
  return &ff->fd;
}

static BOOL FF_IsValid(TFileFindRecord* fd) {
  return fd->handle != INVALID_HANDLE_VALUE;
}

static BOOL FF_FindNext(TFileFindRecord* ff)
{
  if(ff->handle == INVALID_HANDLE_VALUE)
    return FALSE;

  if(ff->first_search) {
    ff->first_search = FALSE;
    if(FF_CheckAttributes(ff))
      return TRUE;
  }

  while(FindNextFileW(ff->handle, &ff->fd)) {
    if(FF_CheckAttributes(ff))
      return TRUE;
  }

  FindClose(ff->handle);
  ff->handle = INVALID_HANDLE_VALUE;
  return FALSE;
}

// lua stack index of 1 is assumed
static TFileFindRecord* getFileFindHandle(lua_State *L)
{
  return (TFileFindRecord*)luaL_checkudata(L, 1, strFileFindHandle);
}

// lua stack index of 1 is assumed
static TFileFindRecord* checkFileFindHandle(lua_State *L)
{
  TFileFindRecord* Rec = (TFileFindRecord*)luaL_checkudata(L, 1, strFileFindHandle);
  if(!FF_IsValid(Rec))
    luaL_error(L, "operation on closed filefind handle");
  return Rec;
}

// the userdatum is assumed to be on the stack top
static int gc_FileFind(lua_State *L)
{
  TFileFindRecord* Rec = getFileFindHandle(L);
  FF_Finalize(Rec);
  return 0;
}

//
// Returns a table with file data followed by a search handle userdatum (if success),
// or nil followed by error string (if failure).
//
static int su_FindFirst(lua_State *L)
{
  const wchar_t* w_card = Api.check_utf8_string(L, 1, NULL);
  const char* attr = luaL_optstring(L, 2, ""); // default attributes: any

  TFileFindRecord* pRec = (TFileFindRecord*)lua_newuserdata(L, sizeof(TFileFindRecord));
  if(!FF_Initialize(pRec, w_card, attr) || !FF_FindNext(pRec))
    return SysErrorReturn(L);

  luaL_getmetatable(L, strFileFindHandle);
  lua_setmetatable(L,-2);

  lua_newtable(L); // create a table for data
  find_filltable(L, FF_GetFindData(pRec));
  lua_pushvalue(L,-2);
  return 2; // the table and the userdatum are on the stack
}

static int su_FindNext(lua_State *L)
{
  TFileFindRecord* pRec = checkFileFindHandle(L);
  if(FF_FindNext(pRec)) {
    lua_newtable(L); // create a table for data
    find_filltable(L, FF_GetFindData(pRec));
    return 1;
  }
  return SysErrorReturn(L);
}

static int su_FindClose(lua_State *L)
{
  TFileFindRecord* Rec = getFileFindHandle(L);
  if (FF_Finalize(Rec))
    return lua_pushboolean(L, 1), 1;
  return SysErrorReturn(L);
}

static int get_next_file(lua_State *L)
{
  if(lua_toboolean(L, lua_upvalueindex(1))) {
    /* 1-st call; data already in place */
    lua_pushboolean(L,0);
    lua_replace(L, lua_upvalueindex(1));  //ud,tb
    lua_insert(L,-2);                     //tb,ud
    return 2;
  }
  if(su_FindNext(L) == 1)
    lua_pushvalue(L,1);
  return 2; //tb,ud or nil,str
}

static int su_Files(lua_State *L)
{
  su_FindFirst(L);        //tb,ud
  lua_insert(L,-2);       //ud,tb
  lua_pushboolean(L,1);
  lua_pushcclosure(L, get_next_file, 1); //ud,tb,fn
  lua_insert(L,-3);       //fn,ud,tb
  return 3;
}

static int _FileTimeResolution(lua_State *L)
{
  int old = FileTimeResolution;
  int res = luaL_checkinteger(L, 1);
  FileTimeResolution = (res == 2) ? 2 : 1;
  lua_pushinteger(L, old);
  return 1;
}

static const luaL_Reg su_funcs[] = {
  {"FindFirst",         su_FindFirst},         //unicode
  {"FindNext",          su_FindNext},          //unicode
  {"FindClose",         su_FindClose},         //unicode
  {"Files",             su_Files},             //unicode
  {"FileTimeResolution", _FileTimeResolution},
  {NULL, NULL}
};

static void createmeta(lua_State *L, const char *name)
{
  luaL_newmetatable(L, name);   /* create new metatable */
  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);         /* push metatable */
  lua_rawset(L, -3);            /* metatable.__index = metatable */
}

static const luaL_Reg FileFindHandle_funcs[] = {
  {"FindNext",          su_FindNext},
  {"FindClose",         su_FindClose},
  {"__gc",              gc_FileFind},
  {NULL, NULL}
};

int luaopen_lfsearch (lua_State *L)
{
  PSInfo = GetPluginStartupInfo();

  Api.StructSize = sizeof(Api);
  LF_GetLuafarAPI(&Api);

  createmeta(L, strFileFindHandle);
  luaL_register(L, NULL, FileFindHandle_funcs);
  lua_pop(L, 1);
  luaL_register(L, "_finder", su_funcs);
  lua_pop(L, 1);
  return 0;
}
