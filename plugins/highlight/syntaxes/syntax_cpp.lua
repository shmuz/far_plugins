local syntax_cpp =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  {
    name = "LongComment"; fgcolor = "gray7";
    pat_open = [[ \/\* ]];
    pat_close = [[ \*\/ ]];
  },
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \/\/.* ]];
  },
  {
    name = "Preprocessor"; fgcolor = "green";
    pattern = [[ ^ \s* \# (?: (?! \/\/ | \/\*) .)* ]];
  },
  {
    name = "Literal"; fgcolor = "white";
    pattern = [[ (?i) \b
      (?: 0x[\dA-F]+ U?L?L? |
          \d+ U?L?L?        |
          (?:\d+\.\d*|\.?\d+) (?:E[+-]?\d+)?
      )
    \b ]];
  },
  {
    name = "String"; fgcolor = "purple"; color_unfinished= "darkblue on purple";
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "Char"; fgcolor = "purple"; color_unfinished= "darkblue on purple";
    pattern = [[ ' (?: \\. | [^\\'] ) ' ]];
  },
  {
    name = "Keyword"; fgcolor = "yellow";
    pattern = [[ \b(?:
      auto|const|double|float|int|short|struct|unsigned|break|continue|else|for|long|signed|switch|
      void|case|default|enum|goto|register|sizeof|typedef|volatile|char|do|extern|if|return|static|
      union|while|asm|dynamic_cast|namespace|reinterpret_cast|try|bool|explicit|new|static_cast|
      typeid|catch|false|operator|template|typename|class|friend|private|this|using|const_cast|
      inline|public|throw|virtual|delete|mutable|protected|true|wchar_t|and|bitand|compl|not_eq|
      or_eq|xor_eq|and_eq|bitor|not|or|xor |__property|__published|__fastcall
      )\b ]];
  },
  {
    name = "Word"; fgcolor = "aqua";
    pattern = [[ \b\w+\b ]];
  },
  {
    name = "MathOp"; fgcolor = "white";
    pattern = [[ [^\w\s] ]];
  },
}

Class {
  name = "C++";
  filemask = "*.c,*.h,*.cpp,*.cxx,*.hpp";
  syntax = syntax_cpp;
}
