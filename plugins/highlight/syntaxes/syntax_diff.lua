local syntax_diff =
{
  bgcolor = 0x1;
  {
    name = "Added"; color = 0x2E;
    pattern = [[ ^ \+ .* ]];
  },
  {
    name = "Removed"; color = 0xDF;
    pattern = [[ ^ \- .* ]];
  },
  {
    name = "Chunk"; color = 0xF0;
    pattern = [[ ^ @@ .* ]];
  },
}

Class {
  name = "Diff files";
  filemask = "*.diff,*.patch";
  syntax = syntax_diff;
}
