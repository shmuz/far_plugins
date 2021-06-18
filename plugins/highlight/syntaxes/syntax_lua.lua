-- Note: false, nil, true - placed in the group of "literals" rather than "keywords".
local syntax_lua =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  --bracketcolor = 0xE3;
  {
    name = "LongComment"; fgcolor = "gray7";
    pat_open = [[ \-\-\[(=*)\[ ]];
    pat_close = [[ \]%1\] ]];
  },
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
      and|break|do|else|elseif|end|for|function|if|in|local|not|or|repeat|return|then|until|while
      )\b ]];
  },
  {
    name = "Function"; fgcolor = "purple";
    pattern = [[ \b(?:
      _G|_VERSION|assert|collectgarbage|dofile|error|getfenv|getmetatable|ipairs|load|loadfile|loadstring|module|next|
      pairs|pcall|print|rawequal|rawget|rawset|require|select|setfenv|setmetatable|tonumber|tostring|type|unpack|xpcall|
      coroutine\.create|coroutine\.resume|coroutine\.running|coroutine\.status|coroutine\.wrap|coroutine\.yield|
      debug\.debug|debug\.getfenv|debug\.gethook|debug\.getinfo|debug\.getlocal|debug\.getmetatable|debug\.getregistry|
      debug\.getupvalue|debug\.setfenv|debug\.sethook|debug\.setlocal|debug\.setmetatable|debug\.setupvalue|
      debug\.traceback|io\.close|io\.flush|io\.input|io\.lines|io\.open|io\.output|io\.popen|io\.read|io\.stderr|
      io\.stdin|io\.stdout|io\.tmpfile|io\.type|io\.write|math\.abs|math\.acos|math\.asin|math\.atan|math\.atan2|
      math\.ceil|math\.cos|math\.cosh|math\.deg|math\.exp|math\.floor|math\.fmod|math\.frexp|math\.huge|math\.ldexp|
      math\.log|math\.log10|math\.max|math\.min|math\.modf|math\.pi|math\.pow|math\.rad|math\.random|math\.randomseed|
      math\.sin|math\.sinh|math\.sqrt|math\.tan|math\.tanh|os\.clock|os\.date|os\.difftime|os\.execute|os\.exit|
      os\.getenv|os\.remove|os\.rename|os\.setlocale|os\.time|os\.tmpname|package\.cpath|package\.loaded|
      package\.loaders|package\.loadlib|package\.path|package\.preload|package\.seeall|string\.byte|string\.char|
      string\.dump|string\.find|string\.format|string\.gmatch|string\.gsub|string\.len|string\.lower|string\.match|
      string\.rep|string\.reverse|string\.sub|string\.upper|table\.concat|table\.insert|table\.maxn|table\.remove|
      table\.sort
      )\b ]];
  },
  {
    name = "Library"; color="darkred on white";
    pattern = [[ \b(?:
      coroutine|debug|io|math|os|package|string|table
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
  name = "Lua";
  filemask = "*.lua;*.luacheckrc";
  syntax = syntax_lua;
  firstline = "lua";
}
