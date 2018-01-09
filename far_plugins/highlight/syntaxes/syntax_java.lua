local syntax_java =
{
  bgcolor = 0x1;
  bracketmatch = true;
  {
    name = "LongComment"; fgcolor = 0x7;
    pat_open = [[ \/\* ]];
    pat_close = [[ \*\/ ]];
  },
  {
    name = "Comment"; fgcolor = 0x7;
    pattern = [[ \/\/.* ]];
  },
  {
    name = "Literal"; fgcolor = 0xF;
    pattern = [[ (?i) \b
      (?: 0x[\dA-F]+ L? |
          \d+ L?        |
          (?:\d+\.\d*|\.?\d+) (?:E[+-]?\d+)?
      )
    \b ]];
  },
  {
    name = "String"; fgcolor = 0xD; color_unfinished= 0xD1;
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "Char"; fgcolor = 0xD; color_unfinished= 0xD1;
    pattern = [[ ' (?: \\. | [^\\'] ) ' ]];
  },
  {
    name = "Keyword"; fgcolor = 0xE;
    pattern = [[ \b(?:
      abstract|continue|for|new|switch|
      assert|default|if|package|synchronized|
      boolean|do|goto|private|this|
      break|double|implements|protected|throw|
      byte|else|import|public|throws|
      case|enum|instanceof|return|transient|
      catch|extends|int|short|try|
      char|final|interface|static|void|
      class|finally|long|strictfp|volatile|
      const|float|native|super|while|true|false|null
      )\b ]];
  },
  {
    name = "Word"; fgcolor = 0xB;
    pattern = [[ \b\w+\b ]];
  },
  {
    name = "MathOp"; fgcolor = 0xF;
    pattern = [[ [^\w\s] ]];
  },
}

Class {
  name = "Java";
  filemask = "*.java";
  syntax = syntax_java;
}
