local bin2c = require "bin2c"

local linit = [[
/* This is a generated file. */

/*
** $Id: linit.c,v 1.14.1.1 2007/12/27 13:02:25 roberto Exp $
** Initialization of libraries for lua.c
** See Copyright Notice in lua.h
*/


#define linit_c
#define LUA_LIB

#include "lua.h"

#include "lualib.h"
#include "lauxlib.h"

<$declarations>

static const luaL_Reg lualibs[] = {
<$binmodules>
<$modules>
<$scripts>
  {NULL, NULL}
};

/*
  1. Makefile: add -DFUNC_OPENLIBS=luafar_openlibs to compilation flags
  2. Plugin (GetGlobalInfoW): call LF_InitLuaState1(L,FUNC_OPENLIBS)
  3. LuaFAR (LF_InitLuaState1): call FUNC_OPENLIBS unless it is NULL
*/
LUALIB_API int luafar_openlibs (lua_State *L) {
  const luaL_Reg *lib = lualibs;
  for (; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }
  return 0;
}

/*
  This loader is shared by all added scripts and modules.
  Particular script is selected by upvalues.
*/
static int loader (lua_State *L) {
  void *arr = lua_touserdata(L, lua_upvalueindex(1));
  size_t arrsize = lua_tointeger(L, lua_upvalueindex(2));
  const char *name = lua_tostring(L,1);
  if (0 == luaL_loadbuffer(L, arr, arrsize, name)) {
    if (*name != '<') {  /* it's a module */
      lua_pushvalue(L,1);
      lua_call(L,1,1);
    }
    return 1;
  }
  return 0;
}

/*
  Place a loader for given script or module into package.preload
*/
static int preload (lua_State *L, char *arr, size_t arrsize) {
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  lua_pushlightuserdata(L, arr);
  lua_pushinteger(L, arrsize);
  lua_pushcclosure(L, loader, 2);
  lua_setfield(L, -2, lua_tostring(L,1));
  lua_pop(L,2);
  return 0;
}

]]

local function remove_ext(s)
  return (s:gsub("%.[^\\/.]+$", ""))
end

local function readfile (filename, mode)
  local fp = assert(io.open(filename, mode))
  local s = fp:read("*all")
  fp:close()
  return s
end

local function addfiles(target, files, method, compiler)
  local diet, diet_arg
  if method == "strip" or method == "luasrcdiet" then
    diet = require "luasrcdiet"
    diet_arg = { "-o", "luac.out", "--noopt-emptylines", "--quiet" }
    table.insert(diet_arg, method=="strip" and "--noopt-locals" or "--opt-locals")
    table.insert(diet_arg, jit and "--noopt-binequiv" or "--opt-binequiv")
  end
  for _, f in ipairs(files) do
    local s
    if method == "strip" or method == "luasrcdiet" then
      diet(f.fullname, unpack(diet_arg))
      s = readfile("luac.out", "rb")
    elseif method == "luac" then
      assert(0==os.execute((compiler or "luac").." -o luac.out -s "..f.fullname))
      s = readfile("luac.out", "rb")
    elseif method == "luajit" then
      assert(0==os.execute((compiler or "luajit").." -b -t raw -s "..f.fullname.." luajitc.out"))
      s = readfile("luajitc.out", "rb")
    else -- "plain"
      s = readfile(f.fullname)
    end
    target:write("static ", bin2c(s, f.arrayname), "\n")
  end
end

local function create_linit (aScripts, aModules, aBinlibs)
  local tinsert = table.insert
  local result = linit:gsub("<$([^>]+)>",
    function(tag)
      local ret = {}
      --------------------------------------------------------------------------
      if tag == "declarations" then
        tinsert(ret, "/*---- forward declarations ----*/")
        for _,libname in ipairs(aBinlibs) do
          tinsert(ret, "int luaopen_" .. libname .. " (lua_State*);")
        end
        for _,v in ipairs(aScripts) do
          tinsert(ret, "static int preload_" .. v.arrayname .. " (lua_State*);")
        end
        for _,v in ipairs(aModules) do
          tinsert(ret, "static int preload_" .. v.arrayname .. " (lua_State*);")
        end
      --------------------------------------------------------------------------
      elseif tag == "binmodules" and #aBinlibs > 0 then
        tinsert(ret, "  /*------ bin.modules ------*/")
        for _,libname in ipairs(aBinlibs) do
          tinsert(ret, ('  {"%s", luaopen_%s},'):format(libname, libname))
        end
      --------------------------------------------------------------------------
      elseif tag == "modules" then
        tinsert(ret, "  /*-------- modules --------*/")
        for _,v in ipairs(aModules) do
          tinsert(ret, "  {\"" .. v.requirename .. "\", preload_" .. v.arrayname .. "},")
        end
      --------------------------------------------------------------------------
      elseif tag == "scripts" then
        tinsert(ret, "  /*-------- scripts --------*/")
        for _,v in ipairs(aScripts) do
          tinsert(ret, "  {\"<" .. v.requirename .. "\", preload_" .. v.arrayname .. "},")
        end
      end
      --------------------------------------------------------------------------
      tinsert(ret, "")
      return table.concat(ret, "\n")
    end)
  return result
end

local function add_preloads (target, files)
  local template = [[
static int preload_%s (lua_State *L)
    { return preload(L, %s, sizeof(%s)); }
]]
  for _,v in ipairs(files) do
    local name = v.arrayname
    target:write(template:format(name, name, name))
  end
end

--- Preprocess a file specification.
-- @target: Output array (table).
-- @arg:    File name containing path (string).
--          The function splits it into path and name.
--          If it should be split at a point other than the last (back)slash, use an asterisk to specify where.
-- @boot:   Whether `arg` is the boot script (boolean).
local function preprocess(target, arg, boot)
  local path, name = arg:match("(.+)%*(.+)")
  if path == nil then path, name = arg:match("(.+)[/\\](.+)") end
  if path == nil then error("Bad argument: "..arg) end
  table.insert(target,
    { fullname    = path.."\\"..name,
      arrayname   = boot and "boot" or remove_ext(name):gsub("[\\/.]", "_"),
      requirename = boot and "boot" or remove_ext(name):gsub("[\\/]", ".")
    })
end

--------------------------------------------------------------------------------
--- Embed Lua scripts into a C-file.
-- @target:     Name of the output file
-- @method:     Either of "plain" (default), "strip", "luasrcdiet", "luac", "luajit"
-- @compiler:   Compiler file name (used with "luac" and "luajit" methods)
-- @bootscript: Boot script name
-- @tscripts:   Array of scripts names (optional)
-- @tmodules:   Array of modules names (optional)
-- @tbinlibs:   Array of binary libraries names (optional)
--------------------------------------------------------------------------------
local function embed (target, method, compiler, bootscript, tscripts, tmodules, tbinlibs)
  assert(bootscript, "Syntax: embed(target, method, compiler, bootscript, tscripts, tmodules, tbinlibs)")
  local scripts, modules, binlibs = {}, {}, tbinlibs or {}
  preprocess(scripts, bootscript, true)
  for _, arg in ipairs(tscripts or {}) do preprocess(scripts, arg, false) end
  for _, arg in ipairs(tmodules or {}) do preprocess(modules, arg, false) end

  local fp = assert(io.open(target, "w"))
  fp:write(create_linit(scripts, modules, binlibs))
  addfiles(fp, scripts, method, compiler)
  addfiles(fp, modules, method, compiler)
  add_preloads(fp, scripts)
  add_preloads(fp, modules)
  fp:close()
end

return embed
