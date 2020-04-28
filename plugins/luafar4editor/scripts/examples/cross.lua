-- Cross in the editor, controlled by Scroll Lock key.
-- Author: Vadim Yegorov.

local F=far.Flags
local editors={}
local color={Flags=bit64.bor(F.FCF_FG_4BIT,F.FCF_BG_4BIT),ForegroundColor=0x1,BackgroundColor=0xf}
local color1={Flags=bit64.bor(F.FCF_FG_4BIT,F.FCF_BG_4BIT),ForegroundColor=0x1,BackgroundColor=0xc}
local scrolllock=false

function GetData(id)
  local data=editors[id]
  if not data then
    editors[id]={start=1,finish=1}
    data=editors[id]
  end
  return data
end

function RemoveCrest(id,data)
  for ii=data.start,data.finish do
    editor.DelColor(id,ii,nil)
  end
end

function ProcessCrest(id,update)
  local data=GetData(id)
  RemoveCrest(id,data)
  update(data)
end

function ProcessEditorInput(rec)
  if F.KEY_EVENT==rec.EventType and 0~=rec.VirtualKeyCode then
    if 0==bit64.band(rec.ControlKeyState,F.SCROLLLOCK_ON) then
      if scrolllock then
        ProcessCrest(editor.GetInfo(-1).EditorID,
          function(data)
            data.start=1
            data.finish=1
          end
        )
        scrolllock=false
        editor.Redraw(-1)
      end
    else
      if not scrolllock then
        scrolllock=true
        editor.Redraw(-1)
      end
    end
  end
  return false
end

function ProcessEditorEvent(id,event,param)
  if event==F.EE_READ then
    editors[id]={start=1,finish=1}
  end
  if event==F.EE_CLOSE then
    editors[id]=nil
  end
  if event==F.EE_REDRAW then
    if scrolllock then
      local ei=editor.GetInfo(id)
      ProcessCrest(ei.EditorID,
        function(data)
          data.start=ei.TopScreenLine
          data.finish=math.min(ei.TopScreenLine+ei.WindowSizeY,ei.TotalLines)
          for ii=data.start,data.finish do
            local toreal=function(pos) return editor.TabToReal(ei.EditorID,ii,pos) end
            if ei.CurLine==ii then
              editor.AddColor(ei.EditorID,ii,toreal(ei.LeftPos),toreal(ei.LeftPos+ei.WindowSizeX),F.ECF_TABMARKCURRENT,color,200)
            end
            local column=toreal(ei.CurTabPos)
            editor.AddColor(ei.EditorID,ii,column,column,F.ECF_TABMARKCURRENT,ii==ei.CurLine and color1 or color,201)
          end
        end
      )
    end
  end
end

function ExitScript()
  local wincount=far.AdvControl(F.ACTL_GETWINDOWCOUNT,0,0)
  for ii=1,wincount do
    local info=far.AdvControl(F.ACTL_GETWINDOWINFO,ii,0)
    if info and F.WTYPE_EDITOR==info.Type then
      ProcessCrest(info.Id,
        function(data)
          data.start=1
          data.finish=1
        end
      )
    end
  end
end
