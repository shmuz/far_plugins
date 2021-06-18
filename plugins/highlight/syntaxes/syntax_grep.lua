local syntax_grep =
{
  bgcolor = "darkblue";
  {
    name = "Filename"; fgcolor = "yellow";
    pattern = [[ ^ \[\d+\].+ ]];
  },
  {
    name = "LineNUm"; color = "blue on aqua";
    pattern = [[ ^ (\d+:){1,2} ]];
  },
}

Class {
  name = "Grep";
  filemask = "*.grep";
  syntax = syntax_grep;
}
