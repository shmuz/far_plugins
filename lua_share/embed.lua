local bin2c = require "bin2c"

local function remove_ext(s)
  return (s:gsub("%.[^\\/.]+$", ""))
end

local function arrname(file)
  return file.boot and "boot" or remove_ext(file.name):gsub("[\\/.]", "_")
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

local function addfiles(target, files, method, luac)
  local strip = (method == "-strip") and require "lstrip51"
  luac = (luac or "luac") .. " -o luac.out -s "
  for _, f in ipairs(files) do
    local s
    local fullname = f.path .."\\".. f.name
    if method == "-plain" then
      local fp = assert(io.open(fullname))
      s = fp:read("*all")
      fp:close()
    elseif strip then
      s = assert(strip("fsk", fullname))
    else
      assert(0 == os.execute(luac .. fullname))
      local fp = assert(io.open("luac.out", "rb"))
      s = fp:read("*all")
      fp:close()
    end
    target:write("static ", bin2c(s, arrname(f)), "\n")
  end
end

local function create_linit (aScripts, aModules, aBinlibs)
  local tinsert = table.insert
  return linit:gsub("<$([^>]+)>",
    function(tag)
      local ret = {}
      --------------------------------------------------------------------------
      if tag == "declarations" then
        tinsert(ret, "/*---- forward declarations ----*/")
        for _,libname in ipairs(aBinlibs) do
          tinsert(ret, "int luaopen_" .. libname .. " (lua_State*);")
        end
        for _,v in ipairs(aScripts) do
          tinsert(ret, "int preload_" .. arrname(v) .. " (lua_State*);")
        end
        for _,v in ipairs(aModules) do
          tinsert(ret, "int preload_" .. arrname(v) .. " (lua_State*);")
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
          local requirename = remove_ext(v.name):gsub("[\\/]", ".")
          tinsert(ret, "  {\"" .. requirename .. "\", preload_" .. arrname(v) .. "},")
        end
      --------------------------------------------------------------------------
      elseif tag == "scripts" then
        tinsert(ret, "  /*-------- scripts --------*/")
        for _,v in ipairs(aScripts) do
          local name = arrname(v)
          tinsert(ret, "  {\"<" .. name .. "\", preload_" .. name .. "},")
        end
      end
      --------------------------------------------------------------------------
      tinsert(ret, "")
      return table.concat(ret, "\n")
    end)
end

local function add_preloads (target, files)
  local template = [[
int preload_%s (lua_State *L)
    { return preload(L, %s, sizeof(%s)); }
]]
  for _,v in ipairs(files) do
    local name = arrname(v)
    target:write(template:format(name, name, name))
  end
end

local function decode(target, arg, boot)
  local file = { boot=boot }
  file.path, file.name = arg:match("(.+)%*(.+)")
  if file.path == nil then error("bad argument: "..arg) end
  table.insert(target, file)
end

local function embed (target, method, luac, bootscript, ...)
  assert(bootscript, "syntax: embed(target, method, luac, bootscript [, files])")
  local scripts, modules, binlibs = {}, {}, {}
  decode(scripts, bootscript, true)
  local stage
  for _, arg in ipairs {...} do
    if arg:find("^%-[smb]$") then stage = arg
    elseif stage == "-s" then decode(scripts, arg, false)
    elseif stage == "-m" then decode(modules, arg, false)
    elseif stage == "-b" then table.insert(binlibs, arg)
    else error ("type of parameter not specified")
    end
  end

  local fp = assert(io.open(target, "w"))
  fp:write("/* This is a generated file. */\n\n")
  local linit = create_linit(scripts, modules, binlibs)
  fp:write(linit)
  fp:write(code)
  addfiles(fp, scripts, method, luac)
  addfiles(fp, modules, method, luac)
  add_preloads(fp, scripts)
  add_preloads(fp, modules)
  fp:close()
end

return embed
