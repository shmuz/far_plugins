-- Note: false, nil, true - placed in the group of "literals" rather than "keywords".
local syntax_moonscript =
{
  bgcolor = 0x1;
  bracketmatch = true;
  {
    name = "LongString"; fgcolor = 0xA;
    pat_open = [[ \[(=*)\[ ]];
    pat_close = [[ \]%1\] ]];
  },
  {
    name = "Comment"; fgcolor = 0x7;
    pattern = [[ \-\-.* ]];
  },
  {
    name = "Literal"; fgcolor = 0xF;
    pattern = [[
      \b (?: 0[xX][\da-fA-F]+ | (?:\d+\.\d*|\.?\d+)(?:[eE][+-]?\d+)? | false | nil | true) \b ]];
  },
  {
    name = "Compare"; fgcolor = 0xE;
    pattern = [[ == | <= | >= | ~= | != | < | > ]];
  },
  {
    name = "String1"; fgcolor = 0xD; color_unfinished= 0xD1;
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\?$ ]];
  },
  {
    name = "String2"; fgcolor = 0xD; color_unfinished= 0xD1;
    pat_open     = [[ ' ]];
    pat_skip     = [[ (?: \\. | [^\\'] )* ]];
    pat_close    = [[ ' ]];
    pat_continue = [[ \\?$ ]];
  },
  {
    -- https://github.com/leafo/moonscript-site/blob/master/highlight.coffee
    name = "Keyword"; fgcolor = 0xE;
    pattern = [[ \b(?:
      class|extends|if|then|super|do|with|import|export|while|elseif|return|for|in|from|when|using|
      else|and|or|not|switch|break|continue
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
  name = "MoonScript";
  filemask = "*.moon";
  syntax = syntax_moonscript;
}
