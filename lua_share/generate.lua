local bin2c = require "bin2c"

local function arrname(tb, i)
  return tb.bootindex==i and "boot" or tb[i].name:gsub("[\\/]", "_"):sub(1,-5)
end

local function requirename(tb, i)
  return tb[i].name:gsub("[\\/]", "."):sub(1,-5)
end

local linit = [[
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


LUALIB_API int luafar_openlibs (lua_State *L) {
  const luaL_Reg *lib = lualibs;
  for (; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }
  return 0;
}

]]

local code = [[
int loader (lua_State *L) {
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

int preload (lua_State *L, char *arr, size_t arrsize) {
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

local function addfiles(aLuafiles, target, method, luac)
  local strip = (method == "-strip") and require "lstrip51"
  for i, f in ipairs(aLuafiles) do
    local s
    local fullname = f.path .."\\".. f.name
    if method == "-plain" then
      local fp = assert(io.open(fullname))
      s = fp:read("*all")
      fp:close()
    elseif strip then
      s = assert(strip("fsk", fullname))
    else
      assert(0 == os.execute((luac or "luac") .. " -o luac.out -s " .. fullname))
      local fp = assert(io.open("luac.out", "rb"))
      s = fp:read("*all")
      fp:close()
    end
    s = "static " .. bin2c(s, arrname(aLuafiles, i))
    target:write(s, "\n")
  end
end

local function create_linit (aLuafiles, aBinlibs)
  return function(tag)
    local ret = ""
    if tag == "declarations" then
      ret = "/*---- forward declarations ----*/\n"
      for _,libname in ipairs(aBinlibs) do
        ret = ret .. "int luaopen_" .. libname .. " (lua_State*);\n"
      end
      for i = 1, #aLuafiles do
        ret = ret .. "int preload_" .. arrname(aLuafiles,i) .. " (lua_State*);\n"
      end
    elseif tag == "binmodules" and #aBinlibs > 0 then
      ret = "  /*------ bin.modules ------*/\n"
      for _,libname in ipairs(aBinlibs) do
        ret = ret .. ('  {"%s", luaopen_%s},\n'):format(libname, libname)
      end
    elseif tag == "modules" then
      ret = "  /*-------- modules --------*/\n"
      for i,v in ipairs(aLuafiles) do
        if v.module then
          ret = ret .. "  {\"" .. requirename(aLuafiles,i) .. "\", preload_" ..
            arrname(aLuafiles,i) .. "},\n"
        end
      end
    elseif tag == "scripts" then
      ret = "  /*-------- scripts --------*/\n"
      for i,v in ipairs(aLuafiles) do
        if v.script then
          local name = arrname(aLuafiles,i)
          ret = ret .. "  {\"<" .. name .. "\", preload_" .. name .. "},\n"
        end
      end
    end
    return ret
  end
end

local function generate (target, method, luac, bootscript, ...)
  assert(bootscript, "syntax: generate.lua <target> <method> <luac> <bootscript> [files]")
  local args = {...}
  local function decode(arg, tbl)
    tbl.path, tbl.name = arg:match("(.+)%*(.+)")
    if tbl.path == nil then error("bad argument: "..arg) end
    return tbl
  end
  local luafiles = { bootindex=1, decode(bootscript, {script=true}) }
  local binlibs = {}
  local stage
  for _, arg in ipairs(args) do
    if     arg == "-s" then stage = "scripts"
    elseif arg == "-m" then stage = "modules"
    elseif arg == "-b" then stage = "binaries"
    elseif stage == "scripts"  then table.insert(luafiles, decode(arg, {script=true}))
    elseif stage == "modules"  then table.insert(luafiles, decode(arg, {module=true}))
    elseif stage == "binaries" then table.insert(binlibs, arg)
    else error ("type of parameter not specified")
    end
  end

  local fp = assert(io.open(target, "w"))
  --------------------------------------------------------------
  fp:write("/* This is a generated file. */\n\n")
  linit = linit:gsub("<$([^>]+)>", create_linit(luafiles, binlibs))
  fp:write(linit)
  fp:write(code)
  addfiles(luafiles, fp, method, luac)
  for i = 1, #luafiles do
    local name = arrname(luafiles, i)
    fp:write(string.format([[
int preload_%s (lua_State *L)
    { return preload(L, %s, sizeof(%s)); }
]], name, name, name))
  end
  --------------------------------------------------------------
  fp:close()
end

return generate
