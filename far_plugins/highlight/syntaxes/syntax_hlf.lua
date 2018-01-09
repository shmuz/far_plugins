local syntax_hlf =
{
  bgcolor = 0x1;
  {
    name = "Control"; fgcolor = 0xC;
    pattern = [[ ^\.(?:Language|PluginContents|Options)\b.* ]];
  },
  {
    name = "Formatting"; color = 0xA0;
    pattern = [[ ^@[\-+=] ]];
  },
  {
    name = "Alias"; fgcolor = 0xA;
    pattern = [[ ^@.+?=.* ]];
  },
  {
    name = "Topic"; fgcolor = 0xD;
    pattern = [[ ^@.* ]];
  },
  {
    name = "Header"; fgcolor = 0xD;
    pattern = [[ ^\$.* ]];
  },
  {
    name = "Link"; fgcolor = 0xE;
    pattern = [[ ~.*?~@.*?@ ]];
  },
  {
    name = "Emphasize"; fgcolor = 0xF;
    pattern = [[ \#.*?\# ]];
  },
}

Class {
  name = "Far help file";
  filemask = "*.hlf,*.hlf.mcr";
  syntax = syntax_hlf;
}
