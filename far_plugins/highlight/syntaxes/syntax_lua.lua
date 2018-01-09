-- Note: false, nil, true - placed in the group of "literals" rather than "keywords".
local syntax_lua =
{
  bgcolor = 0x1;
  bracketmatch = true;
  --bracketcolor = 0xE3;
  {
    name = "LongComment"; fgcolor = 0x7;
    pat_open = [[ \-\-\[(=*)\[ ]];
    pat_close = [[ \]%1\] ]];
  },
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
    pattern = [[ == | <= | >= | ~= | < | > ]];
  },
  {
    name = "String1"; fgcolor = 0xA; color_unfinished= 0xD1;
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "String2"; fgcolor = 0xA; color_unfinished= 0xD1;
    pat_open     = [[ ' ]];
    pat_skip     = [[ (?: \\. | [^\\'] )* ]];
    pat_close    = [[ ' ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "Keyword"; fgcolor = 0xE;
    --color = { ForegroundColor=0x00FF00; BackgroundColor=0x000080; Flags={FCF_FG_BOLD=1} };
    pattern = [[ \b(?:
      and|break|do|else|elseif|end|for|function|if|in|local|not|or|repeat|return|then|until|while
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
  name = "Lua";
  filemask = "*.lua,*.fmlua,*.lua.1";
  syntax = syntax_lua;
}
