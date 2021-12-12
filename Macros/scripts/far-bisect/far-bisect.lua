--------------------------------------------------------------------------------
-- Started             : 2020-12-11
-- Author              : Shmuel Zeigerman
-- Action              : Search for Far build where some behavior has changed
-- Minimal Far version : 3.0.5186 (mf.AddExitHandler)
-- Far plugin          : LuaMacro
-- Dependencies        : (1) Lua modules far2.simpledialog, far2.settings
--                     : (2) LuaSec library (if the "Luasec" option is set)
--                     : (3) wget.exe (if the "Wget" option is set)
-- Dual usage possible : (1) as a macro (see MacroKey); (2) as a 'farbisect' module
--------------------------------------------------------------------------------
if not (mf and mf.AddExitHandler) then return end

-------- Settings --------------------------------------------------------------
local MacroKey        = "CtrlAltF1"
local SETTINGS_KEY    = "shmuz"
local SETTINGS_SUBKEY = "far-bisect"
local Title           = "Bisect Far builds"
local Info = {
  Author        = "Shmuel Zeigerman";
  Guid          = "EE9DF963-7024-41EA-9338-65FF9BDF551D";
  MinFarVersion = "3.0.5186"; -- (mf.AddExitHandler)
  Started       = "2020-12-11";
  Title         = Title;
}

local ThisDir = (...):match(".+\\")
local Opt = {}
do
  local fOpt, fOptMsg = loadfile(ThisDir.."far-bisect.cfg")
  if fOpt then
    setfenv(fOpt, Opt)()
    assert(Opt.FarArchives)
    assert(Opt.FarArchives.x86)
    assert(Opt.FarArchives.x64)
    assert(Opt.PlugArchives)
    assert(Opt.MacroArchive)
    assert(Opt.CustomArchive)
    assert(Opt.InstallDir)
    assert(Opt.Wget)
    assert(Opt.FarNightlyDir)
    assert(Opt.FarNightlyPage)
    Opt.InstallDir = Opt.InstallDir:gsub("%%(.-)%%", win.GetEnv)
  else
    far.Message(fOptMsg, Title, nil, "w"); return;
  end
end
-------- /Settings -------------------------------------------------------------

local ARCLITE = "65642111-AA69-4B84-B4B8-9249579EC4FA"
local FAR1_OFFSET = 3000 -- do not change - it is used in API
local AUTO_GOOD = 99     -- do not change - it is used in API
local Versions -- cache of "versions.cfg" - it's a big file; load only when it's really needed
local min, max = math.min, math.max

-- some Far builds
local START_FAR2              = 0     -- start of Far2/Far3 buildspace
local START_FAR3              = 1808  -- last Far2 build + 1
local START_LUAMACRO          = 2851  -- Lua, LuaFAR and LuaMacro become official parts of Far
local START_DEFAULT_FARCONFIG = 2917  -- Default.farconfig invented
local START_LUAFARSTABLE      = 3300  -- LuaFAR and Macro API become more or less stable
local START_LUAPREFIX         = 3880  -- command line prefix "lua:" instead of "macro:post"
local START_BIGREFACTOR_DONE  = 3924  -- completion of refactoring started in 3896

-- indexes into the dialog's combobox: must be consecutive and start with 1
local INDEX_FAR1, INDEX_FAR2, INDEX_FAR3,
      INDEX_LUAMACRO, INDEX_LUAFARSTABLE,
      INDEX_BIGREFACTOR = 1,2,3,4,5,6

local MinBuilds = {
  [INDEX_FAR1         ] = nil;
  [INDEX_FAR2         ] = START_FAR2;
  [INDEX_FAR3         ] = START_FAR3;
  [INDEX_LUAMACRO     ] = START_LUAMACRO;
  [INDEX_LUAFARSTABLE ] = START_LUAFARSTABLE;
  [INDEX_BIGREFACTOR  ] = START_BIGREFACTOR_DONE;
}

local PLUG_LF4ED     = { ApiName="lf4ed";     Dir="lf4ed";     }
local PLUG_LFS       = { ApiName="lfs";       Dir="lfs";       }
local PLUG_LFH       = { ApiName="lfh";       Dir="lfh";       }
local PLUG_HIGHLIGHT = { ApiName="highlight"; Dir="highlight"; }
local PLUG_TEXTC0    = { ApiName="text_c0";   Dir="text_c0";   }

-- Plugins' GUIDs are needed to speak the same language with Versions module
local Plugins  = {
  [ win.Uuid("6F332978-08B8-4919-847A-EFBB6154C99A") ] = PLUG_LF4ED;
  [ win.Uuid("8E11EA75-0303-4374-AC60-D1E38F865449") ] = PLUG_LFS;
  [ win.Uuid("A745761D-42B5-4E67-83DA-F07AF367AE86") ] = PLUG_LFH;
  [ win.Uuid("F6138DC9-B1C4-40D8-AAF4-6B5CEC0F6C68") ] = PLUG_HIGHLIGHT;
  [ win.Uuid("5D4AAAB0-A245-48CA-BFF5-9AEF33E06B6F") ] = PLUG_TEXTC0;
}

local API = {
  ["automatic"] = "boolean";
  ["x64"      ] = "boolean";
  [PLUG_LF4ED    .ApiName] = "boolean";
  [PLUG_LFS      .ApiName] = "boolean";
  [PLUG_LFH      .ApiName] = "boolean";
  [PLUG_TEXTC0   .ApiName] = "boolean";
  [PLUG_HIGHLIGHT.ApiName] = "boolean";

  ["minbuild" ] = "number";
  ["maxbuild" ] = "number";
  ["goodbuild"] = "number";
  ["badbuild" ] = "number";

  ["cmdline"  ] = "string";
  ["macrocode"] = "string";
  ["custom"   ] = "string"; -- file name
  ["web"      ] = "string";

  ["farconfig"] = "boolstring"; -- if ==true then take the default file name
  ["macros"   ] = "boolstring"; -- +++
}

local function create_dialog_items()
  local c2 = 36 -- x1 for column 2
  return {
    {tp="dbox";  text=Title;                                                       },
    {tp="chbox"; text="&Automatic operation";                 name="automatic";    },
    {tp="text";  text="Builds:"; y1=""; x1=c2;                                     },
    {tp="rbutt"; text="x86";     y1=""; x1=c2+8; val=1;       name="x86";          },
    {tp="rbutt"; text="x64";     y1=""; x1=c2+16;             name="x64";          },
    {tp="text";  text="&Which builds to test:";                                    },
    {tp="combobox", dropdownlist=1,                           name="minbuild",
        list = { [INDEX_FAR1         ] = {Text="Far1 and above"};
                 [INDEX_FAR2         ] = {Text="Far2 and above"};
                 [INDEX_FAR3         ] = {Text="Far3 and above"};
                 [INDEX_LUAMACRO     ] = {Text=">= 3.0.2851 (LuaMacro)"};
                 [INDEX_LUAFARSTABLE ] = {Text=">= 3.0.3300 (LuaFAR stable)"};
                 [INDEX_BIGREFACTOR  ] = {Text=">= 3.0.3924 (Big Refactoring completed)"};
               };                                                                  },
    ------------------------------------------------------------------------------
    {tp="text";  text="&Command line arguments:";                                  },
    {tp="edit";  hist="far-bisect-cmdline"; uselasthistory=1; name="cmdline";      },
    {tp="text";  text="Command line &Macro code:";                                 },
    {tp="edit";  hist="far-bisect-macrocode"; uselasthistory=1; name="macrocode";  },
    ------------------------------------------------------------------------------
    {tp="sep";                                                                     },
    {tp="text";  text="Known &good build";                                         },
    {tp="fixedit"; y1=""; x1=22; x2=26; mask="99999";         name="goodbuild";    },
    {tp="text";  text="Known &bad  build";                                         },
    {tp="fixedit"; y1=""; x1=22; x2=26; mask="99999";         name="badbuild";     },
    {tp="text";  text="Internet:"; ystep=-1; x1=c2;                                },
    {tp="rbutt"; text="None";      ystep=0;  x1=c2+10; val=1; name="web_none";     },
    {tp="rbutt"; text="FFI";       ystep=0;  x1=c2+19;        name="web_ffi";      },
    {tp="rbutt"; text="Wget";                x1=c2+10;        name="web_wget";     },
    {tp="rbutt"; text="Luasec";    ystep=0;  x1=c2+19;        name="web_luasec";   },
    ------------------------------------------------------------------------------
    {tp="sep";   text="Install:";                                                  },
    {tp="chbox"; text="&1 Default.farconfig";                 name="farconfig";    },
    {tp="chbox"; text="&2 Macros";                            name="macros";       },
    {tp="chbox"; text="&3 Custom archive";                    name="custom";       },
    {tp="chbox"; text="&4 Text C0";                           name=PLUG_TEXTC0.ApiName;    },
    {tp="chbox"; text="&5 LF for Editor";    x1=c2; ystep=-3; name=PLUG_LF4ED.ApiName;     },
    {tp="chbox"; text="&6 LF Search";        x1="";           name=PLUG_LFS.ApiName;       },
    {tp="chbox"; text="&7 LF History";       x1="";           name=PLUG_LFH.ApiName;       },
    {tp="chbox"; text="&8 Highlight";        x1="";           name=PLUG_HIGHLIGHT.ApiName; },
    ------------------------------------------------------------------------------
    {tp="sep";                                                                     },
    {tp="butt"; centergroup=1; text="OK"; default=1;                               },
    {tp="butt"; centergroup=1; text="Cancel"; cancel=1;                            },
  }
end

local function get_data_from_dialog()
  local sdialog = require "far2.simpledialog"
  local libSettings = require "far2.settings"
  local items = create_dialog_items()
  items.width = 70

  -- set initial dialog values from those saved previously
  local data = libSettings.mload(SETTINGS_KEY, SETTINGS_SUBKEY) or {}
  for _,item in ipairs(items) do
    if item.name and data[item.name]~=nil then
      item.val = data[item.name]
    end
  end

  -- call the dialog
  local out = sdialog.Run(items)
  if out then
    -- first save the resulting dialog values
    out.Info = Info
    libSettings.msave(SETTINGS_KEY, SETTINGS_SUBKEY, out)
    -- then post-process: convert some dialog values into expected forms
    out.minbuild = MinBuilds[out.minbuild]
    out.farconfig = out.farconfig and ThisDir.."Default.farconfig"
    out.macros    = out.macros    and ThisDir..Opt.MacroArchive
    out.custom    = out.custom    and ThisDir..Opt.CustomArchive
    out.cmdline   = out.cmdline:match("^%s*(.-)%s*$")
    out.macrocode = out.macrocode:match("^%s*(.-)%s*$")

    local nGood, nBad = tonumber(out.goodbuild), tonumber(out.badbuild)
    out.goodbuild = out.goodbuild:find("^0") and math.min(nGood-FAR1_OFFSET,-1) or nGood
    out.badbuild  = out.badbuild:find("^0")  and math.min(nBad-FAR1_OFFSET,-1)  or nBad
    out.web = out.web_ffi and "ffi" or out.web_wget and "wget" or out.web_luasec and "luasec" or "none"
  end
  return out
end

local function get_far_ver(build)
  return build < 0 and 1 or build <= 1807 and 2 or 3
end

-- @buildlist : list of builds; must be already sorted by ascending build number
-- @build1 : one of the range borders
-- @build2 : another range border
local function find_next_build (buildlist, build1, build2)
  local lower, upper = min(build1,build2), max(build1,build2)
  if (upper - lower) < 2 then return false end
  local middle = (lower + upper) / 2
  local imin,imax
  for i,build in ipairs(buildlist) do
    if build > lower then
      if build < middle then
        imin = i
      elseif build == middle then
        return i
      else
        if build < upper then imax=i; end
        break
      end
    end
  end
  if imin and imax then
    return middle-buildlist[imin] < buildlist[imax]-middle and imin or imax
  else
    return imin or imax
  end
end

local function uninstall(dir)
  far.RecursiveSearch(dir, "*",
    function(item,fullpath)
      if item.FileAttributes:find("d") then
        if item.FileName ~= ".." then
          uninstall(fullpath)
          win.RemoveDir(fullpath)
        end
      else
        win.DeleteFile(fullpath)
      end
    end)
end

local function unpack_archive(archive, install_path)
  return Plugin.Command(ARCLITE, ("x \"%s\" \"%s\""):format(archive,install_path))
end

local function unpack_item(archive, install_path, item)
  return Plugin.Command(ARCLITE, ("e \"%s\" -out:\"%s\" \"%s\""):format(archive,install_path,item))
end

local archive_patterns = { -- must be in lower case
  x86 = { "far175b(%d+)%.x86.-%.7z$",
          "far[23]0b(%d+)%.x86.-%.7z$",
          "far%.x86%.3%.0%.(%d+).-%.7z$" };
  x64 = {};
}
for i,v in ipairs(archive_patterns.x86) do
  archive_patterns.x64[i] = v:gsub("x86","x64")
end

local function get_far_build_num(filename, arch)
  local name = filename:lower()
  if name:find("pdb") then return; end
  for _,patt in ipairs(archive_patterns[arch]) do
    local build = name:match(patt)
    if build then
      build = tonumber(build)
      if name:match("far175b") then build = build-FAR1_OFFSET; end
      return build
    end
  end
end

local function make_far_str(build)
  local ver = get_far_ver(build)
  return ver==1 and "1.75."..(build+FAR1_OFFSET) or
         ver==2 and "2.0."..build or
                    "3.0."..build
end

local function show_result(b1, b2)
  local first = b1.build < b2.build and b1 or b2
  local second = first==b1 and b2 or b1
  local str1, str2 = make_far_str(first.build), make_far_str(second.build)
  local msg = ("Far %s is %s\nFar %s is %s"):format(str1, first.state, str2, second.state)
  if far.Message(msg, Title, "OK;Copy", "l") == 2 then
    far.CopyToClipboard(msg.."\n")
  end
end

local function assess_build(farstr)
  local sdialog = require "far2.simpledialog"
  local items = {
    width=40;
    {tp="dbox"; text=farstr;                                              },
    {tp="text"; text="What about that build?"; centertext=1;              },
    {tp="sep";                                                            },
    {tp="butt"; text="&Good";   centergroup=1; default=1; Name="good";    },
    {tp="butt"; text="&Bad";    centergroup=1;            Name="bad";     },
    {tp="butt"; text="&Ignore"; centergroup=1;            Name="unknown"; },
    {tp="butt"; text="&Repeat"; centergroup=1; ystep=1;   Name="repeat";  },
    {tp="butt"; text="&Cancel"; centergroup=1; cancel=1;                  },
  }
  while true do
    local out,pos = sdialog.Run(items)
    if out then
      return items[pos].Name
    elseif 1 == far.Message("Are you sure to quit the script?", Title, "&Yes;&No", "w") then
      mf.exit()
    end
  end
end

local State = {
  -- use "m+uppercase" convention to prevent clash with dialog item names
  mArchiveMap      = nil;
  mInstallDirDirty = nil;
  mInstallSubDir   = nil;
  -- dialog item names
  automatic        = nil;
  badbuild         = nil;
  cmdline          = nil;
  custom           = nil;
  farconfig        = nil;
  goodbuild        = nil;
  macrocode        = nil;
  macros           = nil;
  maxbuild         = nil;
  minbuild         = nil;
  web              = nil;
  x64              = nil;
}
local State_mt = {__index=State}

local function CreateState(data)
  Versions = Versions or dofile(ThisDir.."versions.cfg")
  local self = setmetatable({}, State_mt)
  for name,tp in pairs(API) do -- only names listed in API are accepted
    local value = data[name]
    if     tp=="boolean" then self[name] = value and true
    elseif tp=="number"  then self[name] = tonumber(value)
    elseif tp=="string"  then self[name] = (type(value)=="string") and value
    elseif tp=="boolstring" and value then
      if type(value)=="string" then self[name] = value
      elseif name=="farconfig" then self[name] = ThisDir.."Default.farconfig"
      elseif name=="macros"    then self[name] = ThisDir..Opt.MacroArchive
      end
    end
  end

  if self.web == "wget" then
    if not win.GetFileAttr(Opt.Wget) then
      self.web = "none"
      far.Message(Opt.Wget.." not found.\nOnly local archives will be used.", Title, nil, "w")
    end
  elseif self.web == "luasec" then
    if not pcall(require, "ssl.https") then
      self.web = "none"
      far.Message("LuaSec not found.\nOnly local archives will be used.", Title, nil, "w")
    end
  end
  return self
end

function State:Download(url, dir)
  local ret = false
  if self.web == "ffi" then
    far.Message(url, "Downloading...", "")
    local ffi = require "ffi"
    ffi.cdef [[ HRESULT URLDownloadToFileW(void* pCaller, const wchar_t* szURL,
                const wchar_t* szFileName, DWORD dwReserved, void* lpfnCB); ]]
    local lib = assert( ffi.load("Urlmon.dll") )
    local file = url:match("[^/]+$")
    if not dir:find("\\$") then dir = dir.."\\" end
    url = win.Utf8ToUtf16(url)  .. "\0"
    file = win.Utf8ToUtf16(dir..file) .. "\0"
    ret = 0==lib.URLDownloadToFileW(nil, ffi.cast("wchar_t*",url), ffi.cast("wchar_t*",file), 0, nil)
  elseif self.web == "wget" then
    far.Message(url, "Downloading...", "")
    ret = 0==win.system(("%s %s -P %s 2>nul"):format(Opt.Wget, url, dir))
  elseif self.web == "luasec" then
    far.Message(url, "Downloading...", "")
    local https = require("ssl.https")
    local body, code = https.request(url)
    if body and code==200 then
      local fname = url:match("[^/]+$")
      if not dir:find("\\$") then dir = dir.."\\" end
      local fp = io.open(dir..fname, "wb")
      if fp then
        fp:write(body); fp:close(); ret = true
      end
    end
  end
  far.AdvControl("ACTL_REDRAWALL")
  return ret
end

function State:install_archive(archive, install_path, farstr)
  if archive:match("^https:") then
    local path = install_path:match(".+[/\\]")
    if not self:Download(archive, path) then
      return
    end
    archive = path .. archive:match("[^\\/]+$")
  end
  far.Message("Installing Far "..farstr..". Please wait.", Title, "")
  return unpack_archive(archive, install_path)
end

function State:Install(build)
  self.mInstallDirDirty = true
  local farver = get_far_ver(build)
  local farstr = make_far_str(build)

  -- install Far (always)
  local install_path = self.mInstallSubDir.."\\"..farstr
  if not self:install_archive(self.mArchiveMap[build], install_path, farstr) then
    far.Message("Installation of Far "..farstr.." failed", Title, nil, "w")
    mf.exit()
  end

  -- install Far.exe.ini
  if farver == 3 then
    local fp = io.open(install_path.."\\Far.exe.ini", "w")
    fp:write("[General]\nUseSystemProfiles=0\n")
    fp:close()
  end

  -- install Default.farconfig
  if self.farconfig then
    if build >= START_DEFAULT_FARCONFIG then
      local fname = self.farconfig:find("^%a:") and self.farconfig or ThisDir..self.farconfig
      assert(win.GetFileAttr(fname), "farconfig not found")
      win.CopyFile(fname, install_path.."\\Default.farconfig")
    end
  end

  -- install macros
  if self.macros then
    if build >= START_LUAFARSTABLE then
      local fname = self.macros:find("^%a:") and self.macros or ThisDir..self.macros
      assert(win.GetFileAttr(fname), "macro-archive not found")
      unpack_archive(fname,  install_path.."\\Profile\\Macros")
    end
  end

  -- install custom archive
  if self.custom then
    local fname = self.custom:find("^%a:") and self.custom or ThisDir..self.custom
    assert(win.GetFileAttr(fname), "custom archive not found")
    unpack_archive(fname, install_path)
  end

  -- install LuaFAR plugins
  local mbuild = build<0 and build+FAR1_OFFSET or build
  local paths = Versions.GetPluginsForFarBuild(Opt.PlugArchives, farver, mbuild, self.x64)
  local lua_binaries = ThisDir.."lua-binaries.7z"
  local lua_bin_dir = self.x64 and "x64" or "x86"
  for guid,archive in pairs(paths) do
    if guid ~= "luafar" then
      local plugin = Plugins[guid]
      if plugin and self[plugin.ApiName] then
        local plug_path = install_path .."\\Plugins\\"..plugin.Dir

        -- Install the plugin (this action comes first as it creates the plug_path directory)
        unpack_archive(archive, plug_path)

        -- Install Lua
        if build < START_LUAMACRO then
          unpack_item(lua_binaries, plug_path, lua_bin_dir.."\\lua5*1.dll")
        end

        -- Install LuaFAR
        if farver == 1 then
          unpack_item(lua_binaries, plug_path, lua_bin_dir.."\\luafar.dll")
        elseif farver == 2 then
          unpack_item(lua_binaries, plug_path, lua_bin_dir.."\\luafarw.dll")
        elseif build < START_LUAMACRO and paths.luafar then
          local item = "win"..(self.x64 and "64" or "32").."_bin\\luafar3.dll"
          unpack_item(paths.luafar, plug_path, item)
        end
      end
    end
  end
  return install_path
end

function State:Test_build(build)
  local install_path = self:Install(build)
  local farstr = "Far "..make_far_str(build)
  -- compose command line for Far.exe
  local cmdline = self.cmdline or ""
  if self.macrocode and self.macrocode:find("%S") then
    if build >= 1515 then -- Mantis#0001338: Префикс в параметрах ком.строки
      local macrocode = (build < START_LUAPREFIX and "macro:post " or "lua:")..self.macrocode
      cmdline = ('%s "%s"'):format(cmdline, macrocode)
    end
  end
  if cmdline:find("^%S") then cmdline = " "..cmdline; end
  cmdline = ("cd %s && Far.exe%s"):format(install_path, cmdline)
  -- /compose command line for Far.exe
  while true do
    panel.GetUserScreen()
    local ret = win.system(cmdline) -- don't use os.execute here
    panel.SetUserScreen()
    if self.automatic then
      return ret==AUTO_GOOD and "good" or "bad"
    else
      ret = assess_build(farstr)
      if ret ~= "repeat" then return ret; end
    end
  end
end

function State:RemoveTemporaryBuilds()
  if self.mInstallDirDirty then
    if 1==far.Message("Remove all temporary Far builds?", Title, "Yes;No") then
      far.Message("Removing temporary builds. Please wait.", Title, "")
      uninstall(self.mInstallSubDir)
      far.AdvControl("ACTL_REDRAWALL")
    end
  end
end

function State:Make_Local_Build_List(arch)
  self.mArchiveMap = {}
  local buildlist = {}
  for _,path in ipairs(Opt.FarArchives[arch]) do
    far.RecursiveSearch(path, "*",
      function(item, fullpath)
        local build = get_far_build_num(item.FileName, arch)
        if build and (not self.minbuild or build >= self.minbuild)
                 and (not self.maxbuild or build <= self.maxbuild)
        then
          table.insert(buildlist, build)
          self.mArchiveMap[build] = fullpath
        end
      end)
  end
  if buildlist[1] == nil then
    far.Message("No Far builds are found.", Title, nil, "w")
    mf.exit()
  end
  return buildlist
end

function State:Make_Web_Build_List(arch)
  local fname = Opt.InstallDir.."\\"..Opt.FarNightlyPage:match("[^/]+$")
  win.DeleteFile(fname) -- prevent wget from creating files with suffixes
  if not self:Download(Opt.FarNightlyPage, Opt.InstallDir) then return end

  local fp = io.open(fname)
  if not fp then return end
  local page = fp:read("*all")
  fp:close()

  local dates, map = {}, {}
  local patt = (arch=="x86") and
    "(Far30b(%d+)%.x86%.(%d+)%.7z)" or
    "(Far30b(%d+)%.x64%.(%d+)%.7z)"
  patt = patt.."</a>"
  for name, build, date in page:gmatch(patt) do
    build = tonumber(build)
    if not dates[build] or dates[build] > date then
      map[build] = name
      dates[build] = date
    end
  end
  return map
end

function State:MakeBuildList(arch)
  local buildlist = self:Make_Local_Build_List(arch)
  if self.web ~= "none" then
    local map = self:Make_Web_Build_List(arch)
    for build,name in pairs(map) do
      if not self.mArchiveMap[build] then
        self.mArchiveMap[build] = Opt.FarNightlyDir .. name
        table.insert(buildlist, build)
      end
    end
  end
  table.sort(buildlist)
  return buildlist
end

function State:Main()
  local arch = self.x64 and "x64" or "x86"
  self.mInstallSubDir = Opt.InstallDir.."\\"..arch
  mf.AddExitHandler(function() self:RemoveTemporaryBuilds() end)

  local buildlist = self:MakeBuildList(arch)
  local goodbuild, badbuild = self.goodbuild, self.badbuild
  local b1, b2 = {}, {}

  -- first initializing b1 then b2
  if goodbuild and badbuild then
    b1.build, b1.state = goodbuild, "good"
    b2.build, b2.state = badbuild, "bad"
  elseif goodbuild then
    b1.build, b1.state = goodbuild, "good"
  elseif badbuild then
    b1.build, b1.state = badbuild, "bad"
  else -- find a build with known state
    local lowbuild, highbuild = buildlist[1], buildlist[#buildlist]
    while true do
      local index = find_next_build(buildlist, lowbuild-1, highbuild+1)
      if index then
        b1.build = buildlist[index]
        b1.state = self:Test_build(b1.build)
        if b1.state == "unknown" then table.remove(buildlist, index)
        else break
        end
      else
        error("Cannot find a build with known state")
      end
    end
  end

  if not b2.build then
    while true do
      local lowbuild, highbuild = buildlist[1], buildlist[#buildlist]
      local index = (b1.build <= lowbuild) and #buildlist or (b1.build >= highbuild) and 1
      if index then
        -- b2 is on a border opposite from b1: one test is enough
        b2.build = buildlist[index]
        b2.state = self:Test_build(b2.build)
      else
        -- b1 is inside the range: 1 or 2 tests are needed for b2
        index = b1.build-lowbuild < highbuild-b1.build and #buildlist or 1
        b2.build = buildlist[index]
        b2.state = self:Test_build(b2.build)
        if b2.state == b1.state then
          -- the first test was unsuccessful
          index = index==1 and #buildlist or 1
          b2.build = buildlist[index]
          b2.state = self:Test_build(b2.build)
        end
      end
      if b2.state == "unknown" then table.remove(buildlist, index)
      else break
      end
    end
    if b2.state == b1.state then
      error(("The edge builds have the same state ('%s')"):format(b1.state))
    end
  end

  -- search loop
  while true do
    local index = find_next_build(buildlist, b1.build, b2.build)
    if not index then break; end
    local build = buildlist[index]
    local state = self:Test_build(build)
    if state == "unknown" then
      table.remove(buildlist, index)
    else
      local item = b1.state==state and b1 or b2
      item.build, item.state = build, state
    end
  end

  if self.mInstallDirDirty then
    show_result(b1, b2)
  else
    far.Message("No tests done\n(probably no builds are available in the given range)", Title)
  end
end

Macro {
  description=Title;
  area="Shell"; key=MacroKey;
  action=function()
    local data = get_data_from_dialog()
    if data then CreateState(data):Main(); end
  end;
}

package.loaded["farbisect"] = {
  FAR1_OFFSET = FAR1_OFFSET;
  AUTO_GOOD = AUTO_GOOD;
  Main = function(data) mf.postmacro(function() CreateState(data):Main() end) end;
}
