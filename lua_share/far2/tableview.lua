-- Encoding: UTF-8
-- Original author: Maxim Gonchar
-- Modifications by: Shmuel Zeigerman
--[[---------------------------------------------------------------------------
TODO:
1. Если вызванная пользователем функция возвращает одну или несколько таблиц,
   надо иметь возможность "заходить" и в эти таблицы ("Lua Explorer" умеет).
2. Для правильного показа значений "properties" надо перед их считыванием
   закрывать диалог (закрывать, а не прятать), а затем переоткрывать.
--]]---------------------------------------------------------------------------
local Stack={}
local StackMeta={__index=Stack}
local function NewStack() return setmetatable({},StackMeta); end
function Stack:size() return #self; end
function Stack:peek() return self[#self]; end
function Stack:push(val) self[#self+1]=val; end
function Stack:pop() local val=self[#self]; self[#self]=nil; return val; end
-------------------------------------------------------------------------------
local function ShowResults(title, ...)
  local nargs = select("#", ...)
  local props = {
    Title=title,
    Bottom=nargs==0 and "No results" or nargs==1 and "1 result" or nargs.." results",
  }
  local items={}
  for k=1,nargs do
    local val = select(k, ...)
    items[k] = { text=("%d. %-16s %s"):format(k, type(val), tostring(val)) }
  end
  return far.Menu(props,items)
end
-------------------------------------------------------------------------------

local far2dialog=require 'far2.dialog'
local F=far.Flags
local history=NewStack()
local opts={
  textheight=16,--30,
  textwidth=50,--60,
  keywidth=24,--30,
  nmax=3
}
local dialog
local dlgArguments
local keys={}
local macroCheck = {
  [Area or 1]=1, [APanel or 1]=1, [PPanel or 1]=1, [CmdLine or 1]=1,
  [Dlg or 1]=1, [Drv or 1]=1, [Editor or 1]=1, [Far or 1]=1, [Help or 1]=1,
  [Menu or 1]=1, [Mouse or 1]=1, [Object or 1]=1, [Viewer or 1]=1,
}

local function dlgProc(handle,msg,p1,p2)
  if msg == F.DN_CONTROLINPUT then
    local func = nil
    if p2.EventType == F.KEY_EVENT then
      local name = far.InputRecordToName(p2)
      if name == "CtrlAltF" or name == "RAlt" then return true end -- suppress ListBox filtering.
      func = keys[name]
    elseif p2.EventType == F.MOUSE_EVENT then
      if p1 == dialog.list.id then
        if p2.EventFlags == F.DOUBLE_CLICK then
          func = keys.Enter
        elseif bit64.band(p2.ButtonState, F.RIGHTMOST_BUTTON_PRESSED) ~= 0 then
          func = keys.BS
        end
      end
    end
    if func then
      return func(handle, p1)
    end
  end
end

local function init()
  opts.valuewidth=opts.textwidth-opts.keywidth+2-opts.nmax
  opts.height=opts.textheight+5
  opts.width=opts.textwidth+23-opts.nmax
  opts.fmt=('%%%ii║ %%1.1s │ %%-%i.%is║ %%1.1s │ %%-%i.%is'):format(
    opts.nmax, opts.keywidth, opts.keywidth, opts.valuewidth, opts.valuewidth)

  dialog=far2dialog.NewDialog()
  dialog.box  = { "DI_DOUBLEBOX",    3, 1, 0, 0,    0,0,0,0,    "Table View" }
  dialog.path = { "DI_EDIT",         5, 2, 0, 0,    0,0,0,0,    "" }
  dialog.list = { "DI_LISTBOX",      4, 3, 0, 0,    0,0,0,0,    "" }

  local Id = win.Uuid("76fec618-17b3-4dc0-b966-6073a589034f")
  dlgArguments={Id, -1, -1, opts.width+6, opts.height+6, nil, dialog, nil, dlgProc}
end

local editable = {
 string=tostring,
 number=tonumber,
 boolean=function(a) return a~='false' and a~='nil' end
}
local function editValue(value, title)
  local tp=type(value)
  if not editable[tp] then
    far.Message("Field of type '"..tp.."' is not editable")
    return
  end
  local result=far.InputBox(nil, title, nil, nil, tostring(value))
  if result then return true, editable[tp](result); end
end

local function repr(a)
  if type(a)=='table'  then
    local str='table'
    if next(a)==nil then
      str=str..': empty'
    elseif #a>0 then
      str=str..': n='..#a
    end
    if getmetatable(a) then
      str=str..' (MT)'
    end
    return str
  end
  return tostring(a)
end

local mtnames={
__add='+',
__sub='-',
__mul='*',
__div='/',
__mod='%',
__pow='^',
__unm='~',
__len='#',
__concat='..',
__eq='==',
__lt='<',
__le='<=',
__index='[]',
__newindex='[!]',
__call='()',
__tostring="''",
__gc="&",
__mode="?",
__metatable="@"
}
local function gettitle(list)
  local title=("Elements: %i"):format(#list)
  local mt=(getmetatable(list.table))
  if type(mt)=="table" then
    local mts={' ('}
    for k,v in pairs(mt) do
      if mtnames[k] then
        table.insert(mts, mtnames[k])
      end
    end
    table.insert(mts, ')')
    title=title..table.concat(mts)
  end
  return title
end

local function tblToList(aTable)
  local list={}
  for k, v in pairs(aTable) do
    table.insert(list, { key=k, value=v } )
  end
  if macroCheck[aTable] and aTable.properties then
    for k, v in pairs(aTable.properties) do
      table.insert(list, { key=k, value=v() } )
    end
  end
  table.sort(list, function(a,b) return tostring(a.key)<tostring(b.key) end)
  for i, v in ipairs(list) do
    v.Text=opts.fmt:format(i, type(v.key), repr(v.key), type(v.value), repr(v.value))
    v.id=i
  end
  list.table=aTable
  return list
end

local function PathToTable(aPath)
  local func,msg = loadstring(("return %s"):format(aPath))
  if func then
    local ok,val = pcall(func)
    if ok then
      if type(val)=="table" then return val end
      return nil,'Table expected, got '..type(val)
    else
      return nil,val
    end
  else
    return nil,msg
  end
end

local function loadTable(aPath, aTable)
  local tbl,err = aTable,nil
  if aPath and not aTable then
    tbl,err = PathToTable(aPath)
    if not tbl then
      far.Message(err, 'Error', nil, 'w'); return
    end
  end
  local list=tblToList(tbl)
  local nlen=#tostring(#list)
  if nlen>opts.nmax then
    opts.nmax=nlen
    init()
    list=tblToList(tbl)
  end

  if history:size()==0 then
    history:push{path=aPath, list=list}
  end

  dialog.path.Data=aPath and tostring(aPath) or '<internal>'
  dialog.list.ListItems=list
  dialog.list.Data=gettitle(list)
  dialog.list.Title=dialog.list.Data

  dialog.box.X2=opts.width+2
  dialog.list.X2=opts.textwidth+24-opts.nmax
  dialog.path.X2=opts.textwidth+23-opts.nmax
  dialog.box.Y2=opts.height
  dialog.list.Y2=opts.textheight+4

  dlgArguments[5]=opts.height+2 -- "Y2" parameter
end

local function UpdateList(handle, pos)
  far.SendDlgMessage(handle, F.DM_LISTSET, dialog.list.id, dialog.list.ListItems)
  far.SendDlgMessage(handle, F.DM_LISTSETTITLES, dialog.list.id, dialog.list)
  if pos then
    far.SendDlgMessage(handle, F.DM_LISTSETCURPOS, dialog.list.id, pos)
  end
end

local function UpdatePath(handle)
  far.SendDlgMessage(handle, F.DM_SETTEXT, dialog.path.id, dialog.path.Data)
end

local function callFunction(func,arglist)
  local getArgList = assert(loadstring("return "..arglist))
  ShowResults("Function call results", func(getArgList()))
end

keys.Enter = function(handle, p1)
  local path,val
  if p1==dialog.path.id then
    path=far.SendDlgMessage(handle, F.DM_GETTEXT, dialog.path.id)
    dialog.path.Data=path
    history:peek().pos=history:peek().pos or {}
  elseif p1==dialog.list.id then
    local listinfo=far.SendDlgMessage(handle, F.DM_LISTINFO, dialog.list.id)
    if listinfo.ItemsNumber==0 then
      return true
    end
    local itemn=listinfo.SelectPos
    history:peek().pos=listinfo
    local list=dialog.list.ListItems
    local item=list[itemn]
    val=list.table[item.key]

    if type(val)=='function' then
      local arglist=far.InputBox(nil, ("Arguments to '%s'"):format(tostring(item.key)), "", "Function arguments")
      if arglist then
        local ok, msg = pcall(callFunction, val, arglist)
        if not ok then far.Message(msg, "Error", nil, "w") end
        loadTable(dialog.path.Data, dialog.list.table)
        UpdateList(handle, listinfo)
      end
      return true
    elseif type(val)~='table' then
      keys.F4(handle,p1)
      return true
    end

    if type(item.key)=='string' then
      path=dialog.path.Data..'.'..item.key
    else
      path=dialog.path.Data..'['..item.key..']'
    end
    dialog.path.Data=path
  end
  val = val or PathToTable(path)
  if val then
    history:push{path=path, list=tblToList(val)}
    loadTable(path,val)
    UpdatePath(handle)
    UpdateList(handle, nil)
  end
  return true
end
keys.NumEnter=keys.Enter

keys.BS = function(handle, p1)
  if p1~=dialog.list.id then return end
  if history:size()<2 then
    return true
  end
  history:pop()
  local hist=history:peek()
  local list=tblToList(hist.list.table)
  dialog.list.ListItems=list
  dialog.list.Title=gettitle(list)
  dialog.path.Data=hist.path
  UpdatePath(handle)
  UpdateList(handle, hist.pos)
  return true
end

keys.Ins = function(handle, p1)
  if p1~=dialog.list.id then return end
  local ok,keytype=editValue('string', 'Enter key type:')
  if not ok then return end
  if not editable[keytype] then
    far.Message('Not editable type: '..tostring(keytype))
    return
  end
  local ok,key=editValue(keytype=='string' and '' or keytype=='number' and 0 or keytype=='boolean', 'Enter key:')
  if not ok or key==nil then return end
  key=editable[keytype](key)
  local ok,valtype=editValue('string', 'Enter value type:')
  if not ok then return end
  local val
  if valtype=='table' then
    val={}
  else
    if not editable[valtype] then
      far.Message('Not editable type: '..tostring(valtype))
      return
    end
    ok,val=editValue(valtype=='string' and '' or valtype=='number' and 0 or valtype=='boolean', 'Enter value:')
    if not ok or val==nil then return end
  end

  local pos={ SelectPos=1 }
  local list=dialog.list.ListItems
  list.table[key]=editable[valtype](val)
  loadTable(history:peek().path, list.table)
  list=dialog.list.ListItems
  for i=1,#list do
    if list[i].key==key then
      pos.SelectPos=i
      break
    end
  end
  UpdateList(handle, pos)
  return true
end

keys.Del = function(handle, p1)
  if p1~=dialog.list.id then return end
  local listinfo=far.SendDlgMessage(handle, F.DM_LISTINFO, dialog.list.id)
  if listinfo.ItemsNumber==0 then return end

  local itemn=listinfo.SelectPos
  local res=far.Message("Are you sure you want to delete element "..itemn.."?", "", "No;Yes", "w")
  if res<=1 then return end

  local list=dialog.list.ListItems
  list.table[list[itemn].key]=nil
  loadTable(history:peek().path, list.table)
  UpdateList(handle, listinfo)
end

keys.F4 = function(handle, p1)
  if p1~=dialog.list.id then return end
  local listinfo=far.SendDlgMessage(handle, F.DM_LISTINFO, dialog.list.id)
  if listinfo.ItemsNumber==0 then return end

  local list=dialog.list.ListItems
  local key=list[listinfo.SelectPos].key
  local ok,res=editValue(list.table[key], "Enter new value:")
  if not ok or res==nil then return end

  list.table[key]=res
  loadTable(history:peek().path, list.table)
  UpdateList(handle, listinfo)
end

local function showDialog(path, tbl)
  loadTable(path, tbl)
  far.Dialog(unpack(dlgArguments,1,9))
end

init()
return showDialog
