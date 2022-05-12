-- encoding: utf-8
-- started: 2014-09-27

local M = require "lfs_message"

local function CreateTable()
  return { MaxGroupNumber=0 }
end

local function BS_NameExt_FileName (T, subj, offs)
  local nm = string.match(subj, "^\\([NX])", offs)
  if nm then
    T[#T+1] = { nm=="N" and "name" or "extension" }
    return 2
  end
  return 0
end

local function BS_CaseModifier (T, subj, offs)
  local c = string.match(subj, "^\\([LlUuE])", offs)
  if c then
    T[#T+1] = { "case", c }
    return 2
  end
  return 0
end

local RPatterns = {
  "^(\\R{(%-?%d+),(%d+)})",
  "^(\\R{(%-?%d+)})",
  "^(\\R)"
}
local function BS_Counter (T, subj, offs)
  for _,patt in ipairs(RPatterns) do
    local R1,R2,R3 = string.match(subj, patt, offs)
    if R1 then
      T[#T+1] = { "counter", R2 and tonumber(R2) or 1, R3 and tonumber(R3) or 0 }
      return #R1
    end
  end
  return 0
end

local HexPattern = "^\\x(" .. ("%x?"):rep(4) .. ")"
local function BS_Hex (T, subj, offs)
  local hex = string.match(subj, HexPattern, offs)
  if hex then
    local num = tonumber(hex,16) or 0
    T[#T+1] = { "hex", ("").char(num) }
    return 2 + #hex
  end
  return 0
end

local function BS_Date (T, subj, offs)
  local d = string.match(subj, "^\\D{([^}]+)}", offs)
  if d then
    T[#T+1] = { "date", d }
    return 4 + #d
  end
  return 0
end

local EscapeMap = { a="\a", e="\27", f="\f", n="\n", r="\r", t="\t" }

local function BS_Escape (T, subj, offs)
  local escape = string.match(subj, "^\\(.?)", offs)
  if escape then
    local val = escape:match("[%p%-+^$&]") or EscapeMap[escape]
    if val then
      T[#T+1] = { "literal", val }
      return 1 + #escape
    end
    return -1, "invalid or incomplete escape: \\"..escape
  end
  return 0
end

local function BS_Escape_FileName (T, subj, offs)
  local escape = string.match(subj, "^\\(.?)", offs)
  if escape then
    local val = escape:match("[~!@#$%%^&*()%-+[%]{}\\|:;'\",<.>/?]")
    if val then
      T[#T+1] = { "literal", val }
      return 1 + #escape
    end
    return -1, "invalid or incomplete escape: \\"..escape
  end
  return 0
end

local function DLR_NamedGroup (T, subj, offs)
  local ng = string.match(subj, "^%${([a-zA-Z_][a-zA-Z_0-9]*)}", offs)
  if ng then
    T[#T+1] = { "ngroup", ng }
    return 3 + #ng
  end
  return 0
end

local function DLR_Group (T, subj, offs)
  local gr = string.match(subj, "^%$([0-9a-zA-Z]?)", offs)
  if gr then
    local val = tonumber(gr,36)
    if val then
      if T.MaxGroupNumber < val then T.MaxGroupNumber = val end
      T[#T+1] = { "group", val }
      return 1 + #gr
    end
    return -1, M.MErrorGroupNumber..": $"..gr
  end
  return 0
end

local function IsChar (T, subj, offs)
  subj = string.sub(subj, offs, offs+3) -- take up to 4 bytes (1 UTF-8 char == 1...4 bytes)
  local char = subj:match("^.") -- a UTF-8 character
  if char then
    if T[#T] and T[#T][1]=="literal" then T[#T][2] = T[#T][2] .. char
    else T[#T+1] = { "literal", char }
    end
    return #char
  end
  return 0
end

local ReplacePatTable = {
  BS_CaseModifier,   -- "\\([LlUuE])"
  BS_Counter,        -- "(\\R{(%-?%d+),(%d+)})"
  BS_Hex,            -- "\\x...."
  BS_Date,           -- "\\D{([^}]+)}"
  BS_Escape,         -- "\\(.?)"
  DLR_NamedGroup,    -- "%${([a-zA-Z_][a-zA-Z_0-9]*)}"
  DLR_Group,         -- "%$([0-9a-fA-F]?)"
  IsChar             -- "."
}

local function TransformReplacePat (aStr)
  local T = CreateTable()
  local offs = 1
  while offs <= #aStr do
    for _,f in ipairs(ReplacePatTable) do
      local res, msg = f(T, aStr, offs)
      if res > 0 then offs = offs + res; break; end
      if res < 0 then return nil, msg; end
    end
  end
  return T
end

local function GetReplaceFunction (aReplacePat, is_wide)
  if type(aReplacePat) ~= "table" then
    error("invalid type of replace pattern")
  end

  local fSame = function(s) return s end
  local U8, U16, sub, empty = fSame, fSame, ("").sub, ""
  if is_wide then
    U8, U16, sub, empty = win.Utf16ToUtf8, win.Utf8ToUtf16, win.subW, win.Utf8ToUtf16("")
  end
  local cache = {} -- performance optimization
  for i,v in ipairs(aReplacePat) do
    if v[1] == "hex" or v[1] == "literal" or v[1] == "ngroup" then
      cache[i] = U16(v[2])
    end
  end
  ---------------------------------------------------------------------------
  return function(collect, nFound, nReps)
    local rep, stack = empty, {}
    local case, instant_case
    for i,v in ipairs(aReplacePat) do
      local instant_case_set = nil
      ---------------------------------------------------------------------
      if v[1] == "case" then
        if v[2] == "L" or v[2] == "U" then
          stack[#stack+1], case = v[2], v[2]
        elseif v[2] == "E" then
          if stack[1] then table.remove(stack) end
          case = stack[#stack]
        else
          instant_case, instant_case_set = v[2], true
        end
      ---------------------------------------------------------------------
      elseif v[1] == "counter" then
        rep = rep .. U16(("%%0%dd"):format(v[3]):format(nReps+v[2]))
      ---------------------------------------------------------------------
      elseif v[1] == "hex" then
        rep = rep .. cache[i]
      ---------------------------------------------------------------------
      elseif v[1] == "literal" or v[1] == "group" then
        local c
        if v[1] == "literal" then
          c = cache[i]
        else -- group
          c = collect[v[2]]
          assert (c ~= nil, "invalid capture index")
        end
        if c ~= false then -- a capture *can* equal false
          if instant_case then
            local d = U8(c):sub(1,1)
            rep = rep .. U16((instant_case=="l" and d:lower() or d:upper()))
            c = sub(c, 2)
          end
          if case=="L" then rep = rep .. U16(U8(c):lower())
          elseif case=="U" then rep = rep .. U16(U8(c):upper())
          else rep = rep .. c
          end
        end
      elseif v[1] == "ngroup" then
        local c = collect[cache[i]]
        if c then rep = rep .. c end
      elseif v[1] == "date" then
        local c = os.date(v[2])
        if type(c)=="string" then rep = rep .. U16(c) end
      ---------------------------------------------------------------------
      end
      if not instant_case_set then
        instant_case = nil
      end
    end
    return rep
  end
end

return {
  GetReplaceFunction  = GetReplaceFunction;
  TransformReplacePat = TransformReplacePat;
}
