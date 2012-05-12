-- Original author: Maxim Gonchar.

local far2dialog=require 'far2.dialog'
local F=far.Flags
local history={}
local opts={
  textheight=16,--30,
  textwidth=50,--60,
  keywidth=25,--30,
  nmax=3
}
local dlgArguments

local keys={}
local function dlgProc(handle,msg,p1,p2)
  if msg==F.DN_CONTROLINPUT or msg==F.DN_INPUT then
    if p2.EventType==F.KEY_EVENT then
      local f=keys[far.InputRecordToName(p2)]
      if f then
        return f(handle, p1)
      end
    end
  elseif msg==F.DN_CLOSE then
    history={}
  end
end

local dialog
local function init()
  opts.valuewidth=opts.textwidth-opts.keywidth+3-opts.nmax
  opts.height=opts.textheight+5
  opts.width=opts.textwidth+23-opts.nmax
  opts.fmt=('%%%ii║ %%1.1s │ %%%i.%is║ %%1.1s │ %%%i.%is'):format(opts.nmax, opts.keywidth, opts.keywidth, opts.valuewidth, opts.valuewidth)

  dialog=far2dialog.NewDialog()
  dialog.box  = { "DI_DOUBLEBOX",    3, 1, 1, 1,    0,0,0,0,    "Table View" }
  dialog.path = { "DI_EDIT",         5, 2, 1, 2,    0,0,0,0,    "" }
  dialog.list = { "DI_LISTBOX",      4, 3, 1, 1,    0,0,0,0,    "" }

  local Id = win.Uuid("76fec618-17b3-4dc0-b966-6073a589034f")
  dlgArguments={Id, -1, -1, opts.width+6, opts.height+6, nil, dialog, nil, dlgProc}
end
init()

local editable = {
 string=tostring,
 number=tonumber,
 boolean=function(a) return a~='false' and a~='nil' end
}
local function edit(value, title)
  local tp=type(value)
  if not editable[tp] then
    far.Message("Field of type '"..tp.."' is not editable")
    return
  end
  local result=far.InputBox(nil, title, nil, nil, tostring(value), 30, nil, nil )
  return result and editable[tp](result)
end

local function initDlgSizes(h)
  local shrink=0
  dialog.box[4]=opts.width+6-opts.nmax
  dialog.list[4]=opts.textwidth+25-opts.nmax
  dialog.path[4]=opts.textwidth+24-opts.nmax
  dialog.box[5]=opts.height
  dialog.list[5]=opts.textheight+4

  dlgArguments[5]=opts.height+2-shrink
end

local function repr(a)
  if type(a)=='table'  then
    local str='table'
    if not next(a) then
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
  local tit=("Elements: %i"):format(#list)
  local mt=(getmetatable(list.tbl))
  if mt then
    local mts={' ('}
    for k,v in pairs(mt) do
      if mtnames[k] then
        table.insert(mts, mtnames[k])
      end
    end
    table.insert(mts, ')')
    tit=tit..table.concat(mts)
  end

  return tit
end

local function tblToList(aTbl)
  local list={}
  for k, v in pairs(aTbl) do
    table.insert(list, { key=k, value=v } )
  end
  table.sort(list, function(a,b) return tostring(a.key)<tostring(b.key) end)
  for i, v in ipairs(list) do
    v.Text=opts.fmt:format(i, type(v.key), repr(v.key), type(v.value), repr(v.value))
    v.id=i
  end
  list.tbl=aTbl
  return list
end

local function loadTable(aPath, aTbl)
  dialog.path[10]=aPath and tostring(aPath) or '<internal>'
  local tbl=aTbl
  if aPath and not aTbl then
    local fun,err=loadstring( ("return %s"):format(aPath) )
    if not fun then
      far.Message(err, 'Syntax error', nil, 'w')
      return
    end
    tbl=fun()
  end
  if type(tbl)~='table' then
    far.Message('Table expected, got '..type(tbl), 'Error', nil, 'w')
    return
  end
  local list=tblToList(tbl)
  local nlen=#tostring(#list)
  if nlen>opts.nmax then
    far.Message('Updating opts.nmax from '..opts.nmax..' to '..nlen)
    opts.nmax=nlen
    init()
    return loadTable(aPath, aTbl)
  end

  history[#history+1]={path=aPath, list=list}

  dialog.list[6]=list
  dialog.list[10]=gettitle(list)
  dialog.list.Title=dialog.list[10]

  initDlgSizes(#list)
end

local deferFunc=nil
local function callDefer()
  if not deferFunc then
    return
  end
  local result=far.InputBox(nil, nil, "Arguments:", nil, "", 30, nil, nil)
  if not result then
    deferFunc=nil
    return
  end

  local fun=loadstring( ("return %s"):format(result) )
  if not fun then
    deferFunc=nil
    return
  end
  far.Message(deferFunc(fun()) or "nothing", "Function call result:")
end

keys.Enter = function(handle, p1)
  local path,tbl
  if p1==dialog.path.id then
    path=far.SendDlgMessage(handle, F.DM_GETTEXT, dialog.path.id)
    dialog.path[10]=path
    history[#history].pos=history[#history].pos or {}
  elseif p1==dialog.list.id then
    local iteminfo=far.SendDlgMessage(handle, F.DM_LISTINFO, dialog.list.id)
    local itemn=iteminfo.SelectPos
    history[#history].pos=iteminfo
    local list=dialog.list[6]
    local item=list[itemn]
    tbl=list.tbl[item.key]

    if type(tbl)=='function' then
      deferFunc=tbl
      far.SendDlgMessage(handle, F.DM_CLOSE)
      return false
    end

    if type(item.key)=='string' then
      path=dialog.path[10]..'.'..item.key
    else
      path=dialog.path[10]..'['..item.key..']'
    end
    dialog.path[10]=path
  end
  loadTable(path,tbl)
  far.SendDlgMessage(handle, F.DM_SETTEXT, dialog.path.id, dialog.path[10])
  far.SendDlgMessage(handle, F.DM_LISTSET, dialog.list.id, dialog.list[6])
  far.SendDlgMessage(handle, F.DM_LISTSETTITLES, dialog.list.id, dialog.list)
  return true
end
keys.NumEnter=keys.Enter

keys.BS = function(handle, p1)
  if p1~=dialog.list.id then return end
  if #history==1 then
    return true
  end
  history[#history]=nil
  local hist=history[#history]
  local list=hist.list
  dialog.list[6]=list
  dialog.list.Title=gettitle(list)
  dialog.path[10]=history[#history].path
  far.SetDlgItem(handle, dialog.path.id, dialog.path)
  far.SendDlgMessage(handle, F.DM_LISTSET, dialog.list.id, dialog.list[6])
  far.SendDlgMessage(handle, F.DM_LISTSETTITLES, dialog.list.id, dialog.list)
  far.SendDlgMessage(handle, F.DM_LISTSETCURPOS, dialog.list.id, hist.pos)
  return true
end

keys.Ins = function(handle, p1)
  if p1~=dialog.list.id then return end
  local keytype=edit('string', 'Enter key type:')
  if not editable[keytype] then
    far.Message('Invalid type '..tostring(keytype))
    return
  end
  local key=edit(keytype=='string' and '' or keytype=='number' and 0 or keytype=='boolean', 'Enter key:')
  if not key then return end
  key=editable[keytype](key)
  local valtype=edit('string', 'Enter value type:')
  local val
  if valtype=='table' then
    val={}
  else
    if not editable[valtype] then
      far.Message('Invalid type '..tostring(valtype))
      return
    end
    val=edit(valtype=='string' and '' or valtype=='number' and 0 or valtype=='boolean', 'Enter value:')
    if not val then return end
  end

  local list=dialog.list[6]
  list.tbl[key]=editable[valtype](val)
  loadTable(history[#history].path, list.tbl)
  list=dialog.list[6]
  local pos={ SelectPos=1 }
  for i=1,#list do
    if list[i].key==key then
      pos.SelectPos=list[i].idx
      break
    end
  end

  far.SendDlgMessage(handle, F.DM_LISTSETCURPOS, dialog.list.id, pos)
  far.SendDlgMessage(handle, F.DM_LISTSET, dialog.list.id, dialog.list[6])
  far.SendDlgMessage(handle, F.DM_LISTSETTITLES, dialog.list.id, dialog.list)
  return true
end

keys.Del = function(handle, p1)
  if p1~=dialog.list.id then return end
  local iteminfo=far.SendDlgMessage(handle, F.DM_LISTINFO, dialog.list.id)
  local itemn=iteminfo.SelectPos
  local pos={ SelectPos=1 }

  local res=far.Message("Are you sure you want to delete element "..itemn.."?", "", "No;Yes", "w")
  if res<=0 then return end

  local list=dialog.list[6]
  list.tbl[list[itemn].key]=nil
  loadTable(history[#history].path, list.tbl)
  list=dialog.list[6]
  local pos={ SelectPos=1 }
  for i=1,#list do
    if list[i].key==key then
      pos.SelectPos=list[i].idx
      break
    end
  end

  far.SendDlgMessage(handle, F.DM_LISTSETCURPOS, dialog.list.id, pos)
  far.SendDlgMessage(handle, F.DM_LISTSET, dialog.list.id, dialog.list[6])
  far.SendDlgMessage(handle, F.DM_LISTSETTITLES, dialog.list.id, dialog.list)
  return
end

keys.F4 = function(handle, p1)
  if p1~=dialog.list.id then return end
  local iteminfo=far.SendDlgMessage(handle, F.DM_LISTINFO, dialog.list.id)
  local itemn=iteminfo.SelectPos
  local pos={ SelectPos=itemn, TopPos=iteminfo.TopPos}

  local list=dialog.list[6]
  local key=list[itemn].key
  local res=edit(list.tbl[key], "Enter new value:")
  if not res then return end

  list.tbl[key]=res
  loadTable(history[#history].path, list.tbl)
  list=dialog.list[6]

  far.SendDlgMessage(handle, F.DM_LISTSETCURPOS, dialog.list.id, pos)
  far.SendDlgMessage(handle, F.DM_LISTSET, dialog.list.id, dialog.list[6])
  far.SendDlgMessage(handle, F.DM_LISTSETTITLES, dialog.list.id, dialog.list)
  return
end

local function showDialog(path, tbl)
  loadTable(path, tbl)
  far.Dialog(unpack(dlgArguments))

  callDefer()
end

showDialog('_G')
