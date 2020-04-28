local syntax_python =
{
  bgcolor = 0x1;
  bracketmatch = true;
  --bracketcolor = 0xE3;
  {
    name = "LongString1"; fgcolor = 0xA; color_unfinished= 0xD1;
    pat_open     = [[ """ ]];
    pat_skip     = [[ (?: \\. | [^\\"] | "{1,2} (?! ") )* ]];
    pat_close    = [[ """ ]];
    pat_continue = [[ $ ]];
  },
  {
    name = "LongString2"; fgcolor = 0xA; color_unfinished= 0xD1;
    pat_open     = [[ ''' ]];
    pat_skip     = [[ (?: \\. | [^\\'] | '{1,2} (?! ') )* ]];
    pat_close    = [[ ''' ]];
    pat_continue = [[ $ ]];
  },
  {
    name = "Comment"; fgcolor = 0x7;
    pattern = [[ \# .* ]];
  },
  {
    name = "Literal"; fgcolor = 0xF;
    pattern = [[
      \b (?: 0[xX][\da-fA-F]+ | (?:\d+\.\d*|\.?\d+)(?:[eE][+-]?\d+)? ) \b ]];
  },
  {
    name = "String1"; fgcolor = 0xD;
    pattern = [[ " (?: \\. | [^\\"] )* " ]];
  },
  {
    name = "String2"; fgcolor = 0xD;
    pattern = [[ ' (?: \\. | [^\\'] )* ' ]];
  },
  {
    name = "Keyword"; fgcolor = 0xE;
    pattern = [[ \b(?:
      and|as|assert|break|class|continue|def|del|elif|else|except|exec|finally|for|from|global|
      if|import|in|is|lambda|not|or|pass|print|raise|return|try|while|with|yield
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
  name = "Python";
  filemask = "*.py";
  syntax = syntax_python;
}

