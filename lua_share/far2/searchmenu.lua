-- Original author: Maxim Gonchar.

local F = far.Flags
local band, bor, bxor, bnot = bit64.band, bit64.bor, bit64.bxor, bit64.bnot
local break_keys={}
local map_keys={}
local mark = {}

local function mapkey(key,sym)
    table.insert(break_keys,{mark,BreakKey=key})
    map_keys[key]=sym
end

mapkey('DELETE',  function(pattern) return '',pattern=='' end)
mapkey('BACK',    function(pattern) return pattern:sub(1,-2),(pattern=='') end)
mapkey('SPACE',   function(pattern) return pattern=='' and '' or pattern..' ', pattern=='' end)
mapkey('C+V',     function(pattern) return (pattern or '')..(far.PasteFromClipboard() or '') end)

for i=48,57 do mapkey(string.char(i),string.char(i)) end
for i=65,90 do mapkey(string.char(i),string.char(32+i)) end

mapkey('OEM_PERIOD', '.')
mapkey('OEM_COMMA',  ',')
mapkey('S+OEM_PERIOD', '>')
mapkey('S+OEM_COMMA',  '<')
mapkey('OEM_PLUS',   '=')
mapkey('S+OEM_PLUS', '+')
mapkey('OEM_MINUS',  '-')
mapkey('S+OEM_MINUS','_')
mapkey('OEM_1',      ';')
mapkey('S+OEM_1',    ':')
mapkey('OEM_2',      '/')
mapkey('S+OEM_2',    '?')
mapkey('OEM_3',      '`')
mapkey('S+OEM_3',    '~')
mapkey('OEM_4',      '[')
mapkey('S+OEM_4',    '{')
mapkey('OEM_5',      '\\')
mapkey('S+OEM_5',    '|')
mapkey('OEM_6',      ']')
mapkey('S+OEM_6',    '}')
mapkey('OEM_7',      "'")
mapkey('S+OEM_7',    '"')
mapkey('S+1',        '!')
mapkey('S+2',        '@')
mapkey('S+3',        '#')
mapkey('S+4',        '$')
mapkey('S+5',        '%')
mapkey('S+6',        '^')
mapkey('S+7',        '&')
mapkey('S+8',        '*')
mapkey('S+9',        '(')
mapkey('S+0',        ')')

local function create_break_keys(bkeys)
    if not bkeys then return break_keys,{} end
    local tb = {}
    local map_keys_ext={}
    for _,v in ipairs(break_keys) do tb[#tb+1]=v end
    for _,v in ipairs(bkeys) do
        tb[#tb+1]=v
        map_keys_ext[v.BreakKey]=v
    end
    return tb,map_keys_ext
end

local function check_item(pattern,text,SearchMethod,ShowAmpersand)
    if not text then return end
    local plain = SearchMethod=="plain" or nil
    if not ShowAmpersand then pattern = pattern:gsub("%&", "") end
    if SearchMethod == "dos" then
      pattern = pattern:gsub("%*+", "*")
          :gsub("[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]", "%%%1")
          :gsub("%%[?*]", {["%?"]=".", ["%*"]=".-"})
    end
    return far.LLowerBuf(text):find(pattern,1,plain)
end

local function hasShowAmpersand(flags)
    local tp = type(flags)
    local sa = "FMENU_SHOWAMPERSAND"
    if tp == "number" then return band(flags, F[sa]) ~= 0 end
    if tp == "string" then return flags == sa end
    if tp == "table" then return tp[sa] and true end
    return false
end

--- Make menu with possibility to filter
-- @param flags table
local function searchable_menu(flags,aitems,bkeys)
    local ShowAmpersand = hasShowAmpersand(flags.Flags)
    local CheckItem = flags.CheckItem or check_item
    local Menu = flags.Menu or far.Menu
    if #aitems==0 then
      return Menu(flags,aitems,bkeys)
    end
    local pattern = flags.Pattern or ''
    local title = flags.Title or "Menu"

    local break_keys,map_keys_ext = create_break_keys(bkeys)
    local map_k = map_keys
    if flags.Map then
        for k in pairs(flags.Map) do
            if not map_keys[k] then table.insert(break_keys,{mark,BreakKey=k}) end
        end
        map_k = setmetatable({},
            {__index=function(t,k) return flags.Map[k] or map_keys[k] end})
    end

    local globalindex = flags.SelectIndex or 1
    while true do
        local items=aitems
        flags.Title=title
        if pattern~='' then
            flags.Title = title..' ['..pattern..']'
            items={}
            local skipcheck=false
            for i,v in ipairs(aitems) do
                local w = { __index=v, __newindex=v, globalindex=i }
                setmetatable(w, w)
                if skipcheck then
                    table.insert(items, w)
                else
                    local ok, found, foundend = pcall(CheckItem, pattern,
                        v.SearchText or v.text, flags.SearchMethod,
                        ShowAmpersand)
                    if ok then
                        if found then
                            w.RectMenu = { TextMark = { found, foundend } }
                            table.insert(items, w)
                            if globalindex==i then flags.SelectIndex = #items end
                        else
                            if globalindex==i then flags.SelectIndex = nil end
                        end
                    else
                        table.insert(items, w)
                        skipcheck=true
                        flags.Title = flags.Title..'*'
                    end
                end
            end
        else
          flags.SelectIndex = globalindex
        end

        if #items==0 and not flags.AllowEmpty then
            pattern=pattern:sub(1,-2)
        else
            if #items>0 and not flags.SelectIndex then
                flags.SelectIndex = 1
                globalindex = items[1].globalindex
            end
            local key,item = Menu ( flags, items, break_keys )
            if not key then
                return key, item
            end
            if #items > 0 then globalindex = items[item].globalindex or item
            else globalindex = nil
            end
            if key[1]==mark then
                local symb = map_k[key.BreakKey]
                if type(symb)=='string' then
                    pattern = pattern..symb
                elseif type(symb)=='function' then
                    local ret
                    local ext_key=map_keys_ext[key.BreakKey]
                    pattern,ret = symb(pattern)
                    if ret and ext_key then
                        return ext_key, globalindex
                    end
                end
            else
                flags.Title, flags.Pattern = title, pattern
                return key, globalindex
            end
        end
    end
end

return searchable_menu
