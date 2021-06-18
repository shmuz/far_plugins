local syntax_diff =
{
  bgcolor = "darkblue";
  {
    name = "Added"; color = "yellow on darkgreen";
    pattern = [[ ^ \+ .* ]];
  },
  {
    name = "Removed"; color = "yellow on darkred";
    pattern = [[ ^ \- .* ]];
  },
  {
    name = "Chunk"; color = "black on white";
    pattern = [[ ^ @@ .* ]];
  },
}

Class {
  name = "Diff files";
  filemask = "*.diff,*.patch";
  syntax = syntax_diff;
}
