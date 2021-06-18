local syntax_python =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  --bracketcolor = 0xE3;
  {
    name = "LongString1"; fgcolor = "green"; color_unfinished= "darkblue on purple";
    pat_open     = [[ (\b[Rr])? """\\? ]];
    pat_skip     = [[ (?: \\. | [^\\"] | "{1,2} (?! ") )* ]];
    pat_close    = [[ """ ]];
    pat_continue = [[ $ ]];
  },
  {
    name = "LongString2"; fgcolor = "green"; color_unfinished= "darkblue on purple";
    pat_open     = [[ (\b[Rr])? '''\\? ]];
    pat_skip     = [[ (?: \\. | [^\\'] | '{1,2} (?! ') )* ]];
    pat_close    = [[ ''' ]];
    pat_continue = [[ $ ]];
  },
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \# .* ]];
  },
  {
    name = "Literal"; fgcolor = "white";
    pattern = [[
      \b (?: 0[xX][\da-fA-F]+ | (?:\d+\.\d*|\.?\d+)(?:[eE][+-]?\d+)? ) \b ]];
  },
  {
    name = "String1"; fgcolor = "purple";
    pattern = [[ (\b[Rr])? " (?: \\. | [^\\"] )* " ]];
  },
  {
    name = "String2"; fgcolor = "purple";
    pattern = [[ (\b[Rr])? ' (?: \\. | [^\\'] )* ' ]];
  },
  {
    name = "Keyword"; fgcolor = "yellow";
    pattern = [[ \b(?:
      False|class|finally|is|return|None|continue|for|lambda|try|True|def|from|nonlocal|while|
      and|del|global|not|with|as|elif|if|or|yield|assert|else|import|pass|break|except|in|raise
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
  name = "Python";
  filemask = "*.py";
  syntax = syntax_python;
}

