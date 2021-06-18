local syntax_lng =
{
  bgcolor = "darkblue";
  {
    name = "Control"; fgcolor = "red";
    pattern = [[ ^ \s* \. .* ]];
  },
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ ^ \s* [^".\s] .* ]];
  },
  {
    name = "Highlight"; fgcolor = "yellow";
    pattern = [[ (?<= &) . ]];
  },
  {
    name = "Param"; fgcolor = "purple";
    pattern = [[ % . ]];
  },
}

Class {
  name = "Far language file";
  filemask = "*.lng";
  syntax = syntax_lng;
}
