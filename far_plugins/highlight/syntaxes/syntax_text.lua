local syntax_text =
{
  bgcolor = 0x1;
  bracketmatch = true;
  {
    name = "Emphasize1"; fgcolor = 0xA;
    pattern = [[ ^\s*__.* | \b_\w+ ]];
  },
  {
    name = "Emphasize2"; color = 0x6E;
    pattern = [[ \*\*.*?\*{2,} ]];
  },
  {
    name = "RusLetter"; fgcolor = 0xE;
    pattern = [[ [а-яёА-ЯЁ]+ ]];
  },
  {
    name = "Digit"; fgcolor = 0xF;
    pattern = [[ [\d\W]+? ]];
  },
}

Class {
  name = "My editor";
  filemask = "*.txt";
  syntax = syntax_text;
  fastlines = 0;
}
