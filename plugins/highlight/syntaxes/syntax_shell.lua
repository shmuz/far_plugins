-- Note: false, nil, true - placed in the group of "literals" rather than "keywords".
local syntax_shell =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  --bracketcolor = 0xE3;
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \#.* ]];
  },
  {
    name = "Literal"; fgcolor = "white";
    pattern = [[
      \b (?: 0[xX][\da-fA-F]+ | (?:\d+\.\d*|\.?\d+)(?:[eE][+-]?\d+)? | false | nil | true) \b ]];
  },
  {
    name = "Compare"; fgcolor = "yellow";
    pattern = [[ == | <= | >= | ~= | < | > ]];
  },
  {
    name = "String1"; fgcolor = "green"; color_unfinished= "darkblue on purple";
    pat_open     = [[ " ]];
    pat_skip     = [[ (?: \\. | [^\\"] )* ]];
    pat_close    = [[ " ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "String2"; fgcolor = "green"; color_unfinished= "darkblue on purple";
    pat_open     = [[ ' ]];
    pat_skip     = [[ (?: \\. | [^\\'] )* ]];
    pat_close    = [[ ' ]];
    pat_continue = [[ \\$ ]];
  },
  {
    name = "Keyword"; fgcolor = "yellow";
    --color = { ForegroundColor=0x00FF00; BackgroundColor=0x000080; Flags={FCF_FG_BOLD=1} };
    pattern = [[ \b(?:
      case|cd|do|done|echo|else|esac|exec|exit|expr|fi|for|if|in|kill|rm|sleep|start|then|while
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
  name = "Shell script";
  filemask = "*.sh;*.bash";
  syntax = syntax_shell;
}
