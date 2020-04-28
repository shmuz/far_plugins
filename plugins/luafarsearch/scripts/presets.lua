--[[
    The regular expressions in this file are for illustration only.
    They (along with their descriptions) were taken from the site
    http://regexlib.com/
--]]

local what=(...)[1]
-------------------------------------------------------------------------------

if what=="url" then
  --[[
    Description
    This will find URLs in plain text. With or without protocol. It matches
    against all toplevel domains to find the URL in the text.

    Matches
    http://www.website.com/index.html | www.website.com | website.com

    Non-Matches
    Works in all my tests. Does not capture protocol.

    Author: James Johnston
  --]]

  local d = {bRegExpr=true}
  d.sSearchPat = [==[([\d\w-.]+?\.(a[cdefgilmnoqrstuwz]|b[abdefghijmnorstvwyz]|c[acdfghiklmnoruvxyz]|d[ejkmnoz]|e[ceghrst]|f[ijkmnor]|g[abdefghilmnpqrstuwy]|h[kmnrtu]|i[delmnoqrst]|j[emop]|k[eghimnprwyz]|l[abcikrstuvy]|m[acdghklmnopqrstuvwxyz]|n[acefgilopruz]|om|p[aefghklmnrstwy]|qa|r[eouw]|s[abcdeghijklmnortuvyz]|t[cdfghjkmnoprtvwz]|u[augkmsyz]|v[aceginu]|w[fs]|y[etu]|z[amw]|aero|arpa|biz|com|coop|edu|info|int|gov|mil|museum|name|net|org|pro)(\b|\W(?<!&|=)(?!\.\s|\.{3}).*?))(\s|$)]==]
  lfsearch.EditorAction("search", d)
-------------------------------------------------------------------------------

elseif what=="creditcard" then
  --[[
    Description
    Used to validate Credit Card numbers, Checks if it contains 16 numbers
    in groups of 4 separated by -, ,or nothing

    Matches
    1111-2323-2312-3434 | 1234343425262837 | 1111 2323 2312 3434

    Non-Matches
    1111 2323 2312-3434 | 34323423 | 1111-2323-23122-3434

    Author: Sachin Bhatt
  --]]

  local d = {bRegExpr=true}
  d.sSearchPat = [[(\d{4}-){3}\d{4}|(\d{4} ){3}\d{4}|\d{16}]]
  lfsearch.EditorAction("search", d)
-------------------------------------------------------------------------------

end
