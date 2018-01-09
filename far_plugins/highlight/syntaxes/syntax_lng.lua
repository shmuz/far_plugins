local syntax_lng =
{
  bgcolor = 0x1;
  {
    name = "Control"; fgcolor = 0xC;
    pattern = [[ ^ \s* \. .* ]];
  },
  {
    name = "Comment"; fgcolor = 0x7;
    pattern = [[ ^ \s* [^".\s] .* ]];
  },
  {
    name = "Highlight"; fgcolor = 0xE;
    pattern = [[ (?<= &) . ]];
  },
  {
    name = "Param"; fgcolor = 0xD;
    pattern = [[ % . ]];
  },
}

Class {
  name = "Far language file";
  filemask = "*.lng";
  syntax = syntax_lng;
}
