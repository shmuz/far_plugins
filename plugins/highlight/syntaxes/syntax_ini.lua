-- Note: false, nil, true - placed in the group of "literals" rather than "keywords".
local syntax_ini =
{
  bgcolor = 0x1;
  {
    name = "Comment"; fgcolor = 0x7;
    pattern = [[ ^ \s* ; .* ]];
  },
  {
    name = "Section"; color = 0xB1;
    pattern = [=[ ^ \s* \[ [^\]]+ \] ]=];
  },
  {
    name = "Name"; fgcolor = 0xE;
    pattern = [[ ^ \s* ([^=]+) (?= =) ]];
  },
}

Class {
  name = "Ini file";
  filemask = "*.ini";
  syntax = syntax_ini;
}
