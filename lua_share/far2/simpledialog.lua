-- Started:                 2020-08-15
-- Minimal Far version:     3.0.3300
-- Far plugin:              any LuaFAR plugin

local F = far.Flags
local VK = win.GetVirtualKeys()
local band, bor = bit64.band, bit64.bor
local IND_TYPE, IND_X1, IND_Y1, IND_X2, IND_Y2, IND_VALUE, IND_DATA = 1,2,3,4,5,6,10

--- Edit some text (e.g. a DI_EDIT dialog field) in Far editor
-- @param text     : input text
-- @param ext      : extension of temporary file (affects syntax highlighting; optional)
-- @return         : output text (or nil)
local function OpenInEditor(text, ext)
  local tempdir = win.GetEnv("TEMP")
  if not tempdir then
    far.Message("Environment variable TEMP is not set", "Error", nil, "w"); return nil
  end
  ext = type(ext)=="string" and ext or ".tmp"
  if ext~="" and ext:sub(1,1)~="." then ext = "."..ext; end
  local fname = ("%s\\far3-%s%s"):format(tempdir, win.Uuid(win.Uuid()):sub(1,8), ext)
  local fp = io.open(fname, "w")
  if fp then
    fp:write(text or "")
    fp:close()
    local flags = {EF_DISABLEHISTORY=1,EF_DISABLESAVEPOS=1}
    if editor.Editor(fname,nil,nil,nil,nil,nil,flags,nil,nil,65001) == F.EEC_MODIFIED then
      fp = io.open(fname)
      if fp then
        text = fp:read("*all")
        fp:close()
        return text
      end
    end
    win.DeleteFile(fname)
  end
  return nil
end

-- @param txt     : string
-- @param h_char  : string; optional; defaults to "#"
-- @param h_color : number; optional; defaults to 0xF0 (black on white)
-- @return 1      : userdata: created usercontrol
-- @return 2      : number: usercontrol width
-- @return 3      : number: usercontrol height
local function usercontrol2 (txt, h_char, h_color)
  local COLOR_NORMAL = far.AdvControl("ACTL_GETCOLOR", far.Colors.COL_DIALOGTEXT)
  local CELL_BLANK = { Char=" "; Attributes=COLOR_NORMAL }
  h_char = h_char or "#"
  h_color = h_color or 0xF0

  local W, H, list = 1, 0, {}
  for line,text in txt:gmatch( "(([^\n]*)\n?)" ) do
    if line ~= "" then
      table.insert(list, text)
      text = text:gsub(h_char, "")
      W = math.max(W, text:len())
      H = H+1
    end
  end

  local buffer = far.CreateUserControl(W, H)
  for y=1,H do
    local line = list[y]
    local len = line:len()
    local ind, attr = 0, COLOR_NORMAL
    for x=1,len do
      local char = line:sub(x,x)
      if char == h_char then
        attr = (attr == COLOR_NORMAL) and h_color or COLOR_NORMAL
      else
        ind = ind + 1
        buffer[(y-1)*W+ind] = {Char=char; Attributes=attr};
      end
    end
    for x=ind+1,W do buffer[(y-1)*W+x] = CELL_BLANK; end
  end
  return buffer, W, H
end

local function calc_x2 (tp, x1, text)
  if tp==F.DI_CHECKBOX or tp==F.DI_RADIOBUTTON then
    return x1 + 3 + text:gsub("&",""):len()
  elseif tp==F.DI_TEXT then
    return x1 - 1 + text:gsub("&",""):len() + 1 -- +1: work around a Far's bug related to ampersands
  else
    return x1
  end
end

-- supported dialog item types
local TypeMap = {
    dbox           =  F.DI_DOUBLEBOX;
    dblbox         =  F.DI_DOUBLEBOX;
    doublebox      =  F.DI_DOUBLEBOX;
    sbox           =  F.DI_SINGLEBOX;
    sngbox         =  F.DI_SINGLEBOX;
    singlebox      =  F.DI_SINGLEBOX;
    text           =  F.DI_TEXT;
    vtext          =  F.DI_VTEXT;
    sep            =  "sep";
    separ          =  "sep";
    separator      =  "sep";
    sep2           =  "sep2";
    separ2         =  "sep2";
    separator2     =  "sep2";
    edit           =  F.DI_EDIT;
    fixedit        =  F.DI_FIXEDIT;
    pswedit        =  F.DI_PSWEDIT;
    cbox           =  F.DI_CHECKBOX;
    chbox          =  F.DI_CHECKBOX;
    checkbox       =  F.DI_CHECKBOX;
    but            =  F.DI_BUTTON;
    butt           =  F.DI_BUTTON;
    button         =  F.DI_BUTTON;
    radiobutton    =  F.DI_RADIOBUTTON;
    rbut           =  F.DI_RADIOBUTTON;
    rbutt          =  F.DI_RADIOBUTTON;
    rbutton        =  F.DI_RADIOBUTTON;
    combobox       =  F.DI_COMBOBOX;
    listbox        =  F.DI_LISTBOX;
    user           =  F.DI_USERCONTROL;
    ucontrol       =  F.DI_USERCONTROL;
    usercontrol    =  F.DI_USERCONTROL;
    user2          =  "usercontrol2";
    ucontrol2      =  "usercontrol2";
    usercontrol2   =  "usercontrol2";
}

-- supported dialog item flags
local FlagsMap = {
    boxcolor               = F.DIF_BOXCOLOR;
    btnnoclose             = F.DIF_BTNNOCLOSE;
    centergroup            = F.DIF_CENTERGROUP;
    centertext             = F.DIF_CENTERTEXT;
    default                = F.DIF_DEFAULTBUTTON;
    defaultbutton          = F.DIF_DEFAULTBUTTON;
    disable                = F.DIF_DISABLE;
    dropdownlist           = F.DIF_DROPDOWNLIST;
    editexpand             = F.DIF_EDITEXPAND;
    editor                 = F.DIF_EDITOR;
    editpath               = F.DIF_EDITPATH;
    editpathexec           = F.DIF_EDITPATHEXEC;
    focus                  = F.DIF_FOCUS;
    group                  = F.DIF_GROUP;
    hidden                 = F.DIF_HIDDEN;
    lefttext               = F.DIF_LEFTTEXT;
    listautohighlight      = F.DIF_LISTAUTOHIGHLIGHT;
    listnoampersand        = F.DIF_LISTNOAMPERSAND;
    listnobox              = F.DIF_LISTNOBOX;
    listnoclose            = F.DIF_LISTNOCLOSE;
    listtrackmouse         = F.DIF_LISTTRACKMOUSE;
    listtrackmouseinfocus  = F.DIF_LISTTRACKMOUSEINFOCUS;
    listwrapmode           = F.DIF_LISTWRAPMODE;
    manualaddhistory       = F.DIF_MANUALADDHISTORY;
    moveselect             = F.DIF_MOVESELECT;
    noautocomplete         = F.DIF_NOAUTOCOMPLETE;
    nobrackets             = F.DIF_NOBRACKETS;
    nofocus                = F.DIF_NOFOCUS;
    readonly               = F.DIF_READONLY;
    righttext              = F.DIF_RIGHTTEXT;
    selectonentry          = F.DIF_SELECTONENTRY;
    setshield              = F.DIF_SETSHIELD;
    showampersand          = F.DIF_SHOWAMPERSAND;
    tristate               = F.DIF_3STATE;                -- !!!
    uselasthistory         = F.DIF_USELASTHISTORY;
    wordwrap               = F.DIF_WORDWRAP;
}

---- Replacement for far.Dialog() with much cleaner syntax of dialog description.
-- @param inData table : contains an array part ("items") and a dictionary part ("properties")

--    Supported properties for entire dialog (all are optional):
--        guid          : string   : a text-form guid
--        width         : number   : dialog width
--        help          : string   : help topic
--        flags         : flags    : dialog flags
--        proc          : function : dialog procedure

--    Supported properties for a dialog item (all are optional except tp):
--        tp            : string   : type; mandatory
--        text          : string   : text
--        name          : string   : used as a key in the output table
--        val           : number/boolean : value for DI_CHECKBOX, DI_RADIOBUTTON initialization
--        flags         : number   : flag or flags combination
--        hist          : string   : history name for DI_EDIT, DI_FIXEDIT
--        mask          : string   : mask value for DI_FIXEDIT, DI_TEXT, DI_VTEXT
--        x1            : number   : left position
--        x2            : number   : right position
--        y1            : number   : top position
--        y2            : number   : bottom position
--        width         : number   : width
--        height        : number   : height
--        ystep         : number   : vertical offset relative to the previous item; may be <= 0; default=1
--        list          : table    : mandatory for DI_COMBOBOX, DI_LISTBOX
--        buffer        : userdata : buffer for DI_USERCONTROL

-- @return1 out  table : contains final values of dialog items indexed by 'name' field of 'inData' items
-- @return2 pos number : return value of API far.Dialog()
----------------------------------------------------------------------------------------------------
local function Run (inData)
  assert(type(inData)=="table", "parameter 'Data' must be a table")
  inData.flags = inData.flags or 0
  assert(type(inData.flags)=="number", "'Data.flags' must be a number")
  local HMARGIN = (0 == band(inData.flags,F.FDLG_SMALLDIALOG)) and 3 or 0 -- horisontal margin
  local VMARGIN = (0 == band(inData.flags,F.FDLG_SMALLDIALOG)) and 1 or 0 -- vertical margin
  local guid = inData.guid and win.Uuid(inData.guid) or ("\0"):rep(16)
  local W = inData.width or 76
  local Y, H = VMARGIN-1, 0
  local outData = {}
  local cgroup = { y=nil; width=0; } -- centergroup
  local x2_defer = {}
  local EMPTY = {}

  for i,v in ipairs(inData) do
    assert(type(v)=="table", "dialog element #"..i.." is not a table")
    local tp = v.tp and TypeMap[v.tp]
    if not tp then error("Unsupported dialog item type: "..tostring(v.tp)); end

    local flags = v.flags or 0
    assert(type(flags)=="number", "type of 'flags' is not a number")
    for k,w in pairs(v) do
      local f = w and FlagsMap[k]
      if f then flags = bor(flags,f); end
    end

    local text = type(v.val)=="string" and v.val or v.text or ""
    local hist = v.hist or ""
    local mask = v.mask or ""

    local prev = (i > 1) and outData[i-1] or EMPTY
    local is_cgroup = (tp==F.DI_BUTTON) and band(flags,F.DIF_CENTERGROUP)~=0
    local x1 = tonumber(v.x1)                  or
               v.x1=="" and prev[IND_X1]       or
               HMARGIN+2
    local x2 = tonumber(v.x2)                  or
               v.x2=="" and prev[IND_X2]       or
               v.width  and x1+v.width-1       or
               x2_defer
    local y1 = tonumber(v.y1)                  or
               v.ystep  and Y + v.ystep        or
               v.y1=="" and prev[IND_Y1]       or
               cgroup.y and is_cgroup and Y    or
               Y + 1
    local y2 = tonumber(v.y2)                  or
               v.y2=="" and prev[IND_Y2]       or
               v.height and y1+v.height-1      or
               y1
    if is_cgroup then
      local textlen = text:gsub("&", ""):len()
      local left = (y1==cgroup.y) and cgroup.width+1 or 2
      cgroup.width = left + textlen + (band(flags,F.DIF_NOBRACKETS)~=0 and 0 or 4)
      cgroup.y = y1
    else
      cgroup.width, cgroup.y = 0, nil
    end

    if tp == F.DI_DOUBLEBOX or tp == F.DI_SINGLEBOX then
      if i == 1 then outData[i] = {tp,  HMARGIN,y1,x2,0,   0,0,0,flags,  text}
      else           outData[i] = {tp,  x1,     y1,x2,y2,  0,0,0,flags,  text}
      end

    elseif tp == F.DI_TEXT then
      outData[i] = {tp,  x1,y1,x2,y1,  0,0,0,flags,  text}

    elseif tp == F.DI_VTEXT then
      if v.mask then flags = bor(flags, F.DIF_SEPARATORUSER); end -- set the flag automatically
      outData[i] = {tp,  x1,y1,x1,y2,  0,0,mask,flags,  text}

    elseif tp=="sep" or tp=="sep2" then
      x1, x2 = v.x1 or -1, v.x2 or -1
      flags = bor(flags, tp=="sep2" and F.DIF_SEPARATOR2 or F.DIF_SEPARATOR)
      if v.mask then flags = bor(flags, F.DIF_SEPARATORUSER); end -- set the flag automatically
      outData[i] = {F.DI_TEXT,  x1,y1,x2,y1,  0,0,mask,flags,  text}

    elseif tp == F.DI_EDIT then
      if v.hist then flags = bor(flags, F.DIF_HISTORY); end -- set the flag automatically
      outData[i] = {tp,  x1,y1,x2,0,  0,hist,0,flags,  text}

    elseif tp == F.DI_FIXEDIT then
      if v.hist then flags = bor(flags, F.DIF_HISTORY);  end -- set the flag automatically
      if v.mask then flags = bor(flags, F.DIF_MASKEDIT); end -- set the flag automatically
      outData[i] = {tp,  x1,y1,x2,0,  0,hist,mask,flags,  text}

    elseif tp == F.DI_PSWEDIT then
      outData[i] = {tp,  x1,y1,x2,0,  0,"",0,flags,  text}

    elseif tp == F.DI_CHECKBOX then
      local val = (v.val==2 and 2) or (v.val and v.val~=0 and 1) or 0
      outData[i] = {tp,  x1,y1,0,y1,  val,0,0,flags,  text}

    elseif tp == F.DI_RADIOBUTTON then
      local val = v.val and v.val~=0 and 1 or 0
      outData[i] = {tp,  x1,y1,0,y1,  val,0,0,flags,  text}

    elseif tp == F.DI_BUTTON then
      outData[i] = {tp,  x1,y1,0,y1,  0,0,0,flags,  text}

    elseif tp == F.DI_COMBOBOX then
      assert(type(v.list)=="table", "\"list\" field must be a table")
      local val = 0 ~= band(flags,F.DIF_DROPDOWNLIST) and
                  v.val and v.val>=1 and v.val<=#v.list and v.val
      v.list.SelectIndex = val or v.list.SelectIndex or 1
      outData[i] = {tp,  x1,y1,x2,y1,  v.list,0,0,flags,  text}

    elseif tp == F.DI_LISTBOX then
      assert(type(v.list)=="table", "\"list\" field must be a table")
      outData[i] = {tp,  x1,y1,x2,y2,  v.list,0,0,flags,  text}

    elseif tp == F.DI_USERCONTROL then
      local buffer = v.buffer or 0
      outData[i] = {tp,  x1,y1,x2,y2,  buffer,0,0,flags,  text}

    elseif tp == "usercontrol2" then
      assert(far.CreateUserControl, "Far 3.0.3590 or newer required to support usercontrol")
      assert(type(v.text)=="string" and v.text~="",    "invalid 'text' attribute in usercontrol2")
      assert(not v.hchar  or type(v.hchar)=="string",  "invalid 'hchar' attribute in usercontrol2")
      assert(not v.hcolor or type(v.hcolor)=="number", "invalid 'hcolor' attribute in usercontrol2")
      local buffer, wd, ht = usercontrol2(v.text, v.hchar, v.hcolor)
      x2 = x1 + wd - 1
      y2 = y1 + ht - 1
      outData[i] = {F.DI_USERCONTROL,  x1,y1,x2,y2,  buffer,0,0,flags}

    end

    if x2 == x2_defer then x2 = calc_x2(tp,x1,text); end
    W = math.max(W, x2+HMARGIN+3, cgroup.width+2*HMARGIN)
    Y = math.max(y1, y2)
    H = math.max(H, Y)

    if type(v.colors) == "table" then
      outData[i].colors = {}
      for j,w in ipairs(v.colors) do
        outData[i].colors[j] = far.AdvControl(F.ACTL_GETCOLOR, far.Colors[w] or w)
      end
    end

  end

  -- second pass (with W already having its final value)
  for i,item in ipairs(outData) do
    if i == 1 then
      if item[IND_TYPE]==F.DI_DOUBLEBOX or item[IND_TYPE]==F.DI_SINGLEBOX then
        item[IND_X2] = W - HMARGIN - 1
        if inData[1].height then
          item[IND_Y2] = item[IND_Y1] + inData[1].height - 1
        else
          item[IND_Y2] = H + 1
        end
        H = item[IND_Y2] + 1 + VMARGIN
      else
        H = H + 1 + VMARGIN
      end
    end
    if item[IND_X2] == x2_defer then
      item[IND_X2] = W-HMARGIN-3
    end
  end
  ----------------------------------------------------------------------------------------------
  local function get_dialog_state(hDlg)
    local out = {}
    for i,v in ipairs(inData) do
      local tp = type(v.name)
      if tp=="string" or tp=="number" then
        local item = far.GetDlgItem(hDlg, i)
        tp = item[IND_TYPE]
        if tp==F.DI_CHECKBOX then
          out[v.name] = (item[IND_VALUE]==2) and 2 or (item[IND_VALUE] ~= 0) -- false,true,2
        elseif tp==F.DI_RADIOBUTTON then
          out[v.name] = (item[IND_VALUE] ~= 0) -- boolean
        elseif tp==F.DI_EDIT or tp==F.DI_FIXEDIT or tp==F.DI_PSWEDIT then
          out[v.name] = item[IND_DATA] -- string
        elseif tp==F.DI_COMBOBOX or tp==F.DI_LISTBOX then
          local pos = far.SendDlgMessage(hDlg, "DM_LISTGETCURPOS", i, 0)
          out[v.name] = pos.SelectPos
        end
      end
    end
    return out
  end
  ----------------------------------------------------------------------------------------------
  local function DlgProc(hDlg, Msg, Par1, Par2)
    local r = inData.proc and inData.proc(hDlg, Msg, Par1, Par2)
    if r then return r; end

    if Msg == F.DN_INITDIALOG then
      if inData.initaction then inData.initaction(hDlg); end

    elseif Msg == F.DN_CLOSE then
      if inData.closeaction and inData[Par1] and not inData[Par1].cancel then
        return inData.closeaction(hDlg, Par1, get_dialog_state(hDlg))
      end

    elseif Msg == F.DN_CONTROLINPUT and Par2.EventType == F.KEY_EVENT and Par2.KeyDown then
      if inData.keyaction and inData.keyaction(hDlg, Par1, far.InputRecordToName(Par2)) then
        return
      end
      local mod = band(Par2.ControlKeyState,0x1F) ~= 0
      if Par2.VirtualKeyCode == VK.F1 and not mod then
        if type(inData.help) == "function" then
          inData.help()
        end
      elseif Par2.VirtualKeyCode == VK.F4 and not mod then
        if outData[Par1][IND_TYPE] == F.DI_EDIT then
          local txt = far.SendDlgMessage(hDlg, "DM_GETTEXT", Par1)
          txt = OpenInEditor(txt, inData[Par1].ext)
          if txt then far.SendDlgMessage(hDlg, "DM_SETTEXT", Par1, txt); end
        end
      end

    elseif Msg == F.DN_BTNCLICK then
      if inData[Par1].action then inData[Par1].action(hDlg,Par1,Par2); end

    elseif Msg == F.DN_CTLCOLORDLGITEM then
      local colors = outData[Par1].colors
      if colors then return colors; end

    end

  end
  ----------------------------------------------------------------------------------------------
  local help = type(inData.help)=="string" and inData.help or nil
  local x1, y1 = inData.x1 or -1, inData.y1 or -1
  local x2 = x1==-1 and W or x1+W-1
  local y2 = y1==-1 and H or y1+H-1
  local hDlg = far.DialogInit(guid, x1,y1,x2,y2, help, outData, inData.flags, DlgProc)
  if hDlg then
    if F.FDLG_NONMODAL and 0 ~= band(inData.flags, F.FDLG_NONMODAL) then
      return hDlg -- non-modal dialogs were introduced in build 5047
    end
  else
    far.Message("Error occured in far.DialogInit()", "module 'simpledialog'", nil, "w")
    return nil
  end
  ----------------------------------------------------------------------------------------------
  local ret = far.DialogRun(hDlg)
  if ret < 1 or inData[ret].cancel then
    far.DialogFree(hDlg)
    return nil
  end
  local out = get_dialog_state(hDlg)
  far.DialogFree(hDlg)
  return out, ret
end

local function Indexes(inData)
  assert(type(inData)=="table", "arg #1 is not a table")
  local Pos, Elem = {}, {}
  for i,v in ipairs(inData) do
    if type(v) ~= "table" then
      error("element #"..i.." is not a table")
    end
    if v.name then Pos[v.name], Elem[v.name] = i,v; end
  end
  return Pos, Elem
end

return {
  OpenInEditor = OpenInEditor;
  Run = Run;
  Indexes = Indexes;
}
