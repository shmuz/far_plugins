-- coding: utf-8
-- started 2010-06-07 by Shmuel Zeigerman

---- require "unicode"
---- getmetatable("").__index = unicode.utf8

--[[---------------------------------------------------------------------------
Purpose:
  Get automatically highlighting (hot keys) for strings in a menu or dialog.
-------------------------------------------------------------------------------
Parameters:
  @Arr:
    An array of strings. The strings containing & are excluded from the
    processing but their highlighted characters will be considered reserved
    and not available for highlighting in other strings.
  @Patt (optional):
    Lua pattern for determining what characters can be highlighted.
    The default is '%w', but '%S', '%a', etc. can also be used.
-------------------------------------------------------------------------------
Returns:
  @Out:
    A table containing highlighted strings (if any) placed at the same indexes
    as those strings are in the input array.
    Out.n is set to the number of strings highlighted by the function.
    Out.n will be <= the number of unhighlighted strings in Arr.
-------------------------------------------------------------------------------
--]]

local function hilite (Arr, Patt)
  Patt = Patt or "%w"
  local charstate, indexes, wei, out = {}, {}, {}, {n=0}

  -- Initialize 'charstate' and 'indexes'
  local patt2 = "%&(" .. Patt .. ")"
  for i, str in ipairs(Arr) do
    local _, n = str:lower():gsub(patt2, function(c) charstate[c]="reserved" end, 1)
    if n == 0 then table.insert(indexes,i) end
  end
  
  -- Initialize 'wei' as a number of times a char is found in words to be highlighted.
  for _, v in ipairs(indexes) do
    local used = {}
    for c in Arr[v]:lower():gmatch(Patt) do
      if not (charstate[c] or used[c]) then
        wei[c] = (wei[c] or 0) + 1
        used[c] = true
      end
    end
  end
  
  -- Get "weight" of a word.
  local function get_weight (str)
    local w, used = 0, {}
    for c in str:lower():gmatch(Patt) do
      if not (charstate[c] or used[c]) then
        w = w + 1/wei[c]
        used[c] = true
      end
    end
    return w
  end

  -- Sort
  table.sort(indexes, function(i1, i2)
    return get_weight(Arr[i1]) < get_weight(Arr[i2]) end)
  
  -- Assign
  for _, v in ipairs(indexes) do
    local found
    local s = Arr[v]:gsub(Patt,
      function(c)
        local c_lower = c:lower()
        if not found and not charstate[c_lower] then
          found = true
          charstate[c_lower] = "assigned"
          return "&"..c
        end
      end)
    if found then
      out[v], out.n = s, out.n+1
    end
  end
  return out
end

return hilite
