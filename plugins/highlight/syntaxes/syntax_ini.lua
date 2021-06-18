local syntax_ini =
{
  bgcolor = "darkblue";
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ ; .* ]];
  },
  {
    name = "Section"; color = "darkblue on aqua";
    pattern = [=[ ^ \s* \[ [^\]]+ \] ]=];
  },
  {
    name = "Name"; fgcolor = "yellow";
    pattern = [[ ^ \s* \w+ \s* (?= =) ]];
  },
  {
    name = "String"; fgcolor = "purple";
    pattern = [[ " [^"]* " ]];
  },
}

Class {
  name = "Ini file";
  filemask = "*.ini";
  syntax = syntax_ini;
}
