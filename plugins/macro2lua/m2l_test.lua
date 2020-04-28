-- Можно сэкономить время, чтобы образцы вывода для сравнения сгенерировал
-- скрипт, то-есть, писать нужно было бы только первый аргумент вызова.

local function exp (input, ref)
  local result = Convert("expression", input)
  if result ~= ref then error('['..tostring(result)..']') end
end

exp ('1', '1')
exp ('1+2-3*4/5', '1+2-3*4/5')
exp ('1 || 2 && 3', '1  or  2  and  3')
exp ('1 | 2 & 3 ^ 4', 'bor(1,bxor(band(2,3),4))')
exp ('', nil)
exp ('a(1,2,3)', 'a(1,2,3)')
exp ('Key(1)', 'mf.key(1)')
exp ('Eval("Shell/CtrlC",2)', 'eval("Shell/CtrlC",2)')
exp ('1 || 2 ^^ 3 && 4 | 5 ^ 6 & 7 == 8 != 9 << 10 >> 11 + 12 - 13 * 14 / 15', '1  or  2 ^^ 3  and  bor(4,bxor(5,band(6,7 == 8 ~= rshift(lshift(9,10),11 + 12 - 13 * 14 / 15))))')
exp ('1 / 2 * 3 - 4 + 5 >> 6 << 7 != 8 == 9 & 10 ^ 11 | 12 && 13 ^^ 14 || 15', 'bor(bxor(band(lshift(rshift(1 / 2 * 3 - 4 + 5,6),7) ~= 8 == 9,10),11),12)  and  13 ^^ 14  or  15')
exp ([["a\\b\n\"c"]], [["a\\b\n\"c"]])
exp ([[@"a\b\n""c"]], [["a\\b\\n\"c"]])

far.Message("All tests OK", "Macro2Lua test")
