local Message = require'far2.message'.Message
local t, t1, t2 = {"\n"}, {text="  ", color=0xA5}, {text="  ", color=0x5A}
for k=1,8 do
  t[#t+1] = (9-k).." "
  for m=1,8 do
    t[#t+1] = (k+m)%2==0 and t1 or t2
  end
  t[#t+1] = "\n"
end
t[#t+1] = "  a b c d e f g h"
Message(t, "Chess", nil, "cl")
