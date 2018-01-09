local syntax_cpp =
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
    name = "Preprocessor"; fgcolor = 0xA;
    pattern = [[ ^ \s* \# (?: (?! \/\/ | \/\*) .)* ]];
  },
  {
    name = "Literal"; fgcolor = 0xF;
    pattern = [[ (?i) \b
      (?: 0x[\dA-F]+ U?L?L? |
          \d+ U?L?L?        |
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
      auto|const|double|float|int|short|struct|unsigned|break|continue|else|for|long|signed|switch|
      void|case|default|enum|goto|register|sizeof|typedef|volatile|char|do|extern|if|return|static|
      union|while|asm|dynamic_cast|namespace|reinterpret_cast|try|bool|explicit|new|static_cast|
      typeid|catch|false|operator|template|typename|class|friend|private|this|using|const_cast|
      inline|public|throw|virtual|delete|mutable|protected|true|wchar_t|and|bitand|compl|not_eq|
      or_eq|xor_eq|and_eq|bitor|not|or|xor |__property|__published|__fastcall
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
  name = "C++";
  filemask = "*.c,*.h,*.cpp,*.hpp";
  syntax = syntax_cpp;
}
