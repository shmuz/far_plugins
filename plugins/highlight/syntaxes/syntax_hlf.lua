local syntax_hlf =
{
  bgcolor = "darkblue";
  {
    name = "Control"; fgcolor = "red";
    pattern = [[ ^\.(?:Language|PluginContents|Options)\b.* ]];
  },
  {
    name = "Formatting"; color = "black on green";
    pattern = [[ ^@[\-+=] ]];
  },
  {
    name = "Alias"; fgcolor = "green";
    pattern = [[ ^@.+?=.* ]];
  },
  {
    name = "Topic"; fgcolor = "purple";
    pattern = [[ ^@.* ]];
  },
  {
    name = "Header"; fgcolor = "purple";
    pattern = [[ ^\$.* ]];
  },
  {
    name = "Link"; fgcolor = "yellow";
    pattern = [[ ~.*?~@.*?@ ]];
  },
  {
    name = "Emphasize"; fgcolor = "white";
    pattern = [[ \#.*?\# ]];
  },
}

Class {
  name = "Far help file";
  filemask = "*.hlf,*.hlf.mcr";
  syntax = syntax_hlf;
}
