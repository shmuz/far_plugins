-- coding: UTF-8

local M = require "modules.string_rc"

-- settings --
local DELAY = 0.15e6 -- 0.15 sec (in microseconds); to avoid flickering
local PROGRESS_WIDTH = 30
-- /settings --

local CHAR_SOLID  = ("").char(9608) -->  █
local CHAR_DOTTED = ("").char(9617) -->  ░

local progress = {}
local mt_progress = { __index=progress }

function progress.newprogress(msg, max_value)
  local self = setmetatable({}, mt_progress)
  self._visible = false
  self._max_value = max_value or 0
  self._title = M.title_short
  self._message = msg
  self._start = far.FarClock()
  return self
end


function progress:show()
  if not self._visible then
    self._visible = true
    far.AdvControl("ACTL_SETPROGRESSSTATE", "TBPS_INDETERMINATE")
  end

  if self._bar == nil then
    far.Message(self._message, self._title, "")
  else
    far.Message(self._message.."\n"..self._bar, self._title, "")
  end
end


function progress:hide()
  if self._visible then
    far.AdvControl("ACTL_PROGRESSNOTIFY")
    far.AdvControl("ACTL_SETPROGRESSSTATE", "TBPS_NOPROGRESS")
    panel.RedrawPanel(nil, 1)
    panel.RedrawPanel(nil, 0)
    self._visible = false
  end
end


function progress:update(val)
  if (far.FarClock() - self._start) < DELAY then
    return
  end
  if self._max_value > 0 then
    local percent = math.floor(val * 100 / self._max_value)

    local pv = { Completed=percent; Total=100 }
    far.AdvControl("ACTL_SETPROGRESSVALUE", 0, pv)

    local len = math.floor(percent * PROGRESS_WIDTH / 100)
    self._bar = CHAR_SOLID:rep(len) .. CHAR_DOTTED:rep(PROGRESS_WIDTH - len)
  end
  self:show()
end


function progress.aborted() -- function, not method
  return win.ExtractKey() == "ESCAPE"
end


return progress
