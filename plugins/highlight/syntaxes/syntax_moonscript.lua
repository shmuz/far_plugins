-- Note: false, nil, true - placed in the group of "literals" rather than "keywords".
local syntax_moonscript =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  {
    name = "LongString"; fgcolor = "green";
    pat_open = [[ \[(=*)\[ ]];
    pat_close = [[ \]%1\] ]];
  },
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \-\-.* ]];
  },
  {
    name = "Literal"; fgcolor = "white";
    pattern = [[
      \b (?: 0[xX][\da-fA-F]+ | (?:\d+\.\d*|\.?\d+)(?:[eE][+-]?\d+)? | false | nil | true) \b ]];
  },
  {
    name = "Compare"; fgcolor = "yellow";
    pattern = [[ == | <= | >= | ~= | != | < | > ]];
  },
  {
    name = "String1"; fgcolor = "purple"; color_unfinished= "darkblue on purple";
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\?$ ]];
  },
  {
    name = "String2"; fgcolor = "purple"; color_unfinished= "darkblue on purple";
    pat_open     = [[ ' ]];
    pat_skip     = [[ (?: \\. | [^\\'] )* ]];
    pat_close    = [[ ' ]];
    pat_continue = [[ \\?$ ]];
  },
  {
    -- https://github.com/leafo/moonscript-site/blob/master/highlight.coffee
    name = "Keyword"; fgcolor = "yellow";
    pattern = [[ \b(?:
      class|extends|if|then|super|do|with|import|export|while|elseif|return|for|in|from|when|using|
      else|and|or|not|switch|break|continue
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
  name = "MoonScript";
  filemask = "*.moon";
  syntax = syntax_moonscript;
}
