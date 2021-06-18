local syntax_pascal =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  {
    name = "Macro"; fgcolor = "green";
    pattern = [[ \{\$ [^}]* \} ]];
  },
  {
    name = "LongComment1"; fgcolor = "gray7";
    pat_open = [[ \(\* ]];
    pat_close = [[ \*\) ]];
  },
  {
    name = "LongComment2"; fgcolor = "gray7";
    pat_open = [[ \{ ]];
    pat_close = [[ \} ]];
  },
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ \/\/.* ]];
  },
  {
    name = "Literal"; fgcolor = "white";
    pattern = [[
      \b (?: (?: \d+\.\d* | \.?\d+) (?: [eE][+-]?\d+ )? ) \b |
      (?<! \w) \$[\da-fA-F]+ |
      (?<! \w) \&[07]+ |
      (?<! \w) \%[01]+
    ]];
  },
  {
    name = "String1"; fgcolor = "purple";
    pattern = [[ " (?> (?: [^"]+ | "" | "(?: \#\d+)+" )* ) " ]]; -- important: atomic group used
  },
  {
    name = "String2"; fgcolor = "purple";
    pattern = [[ ' (?> (?: [^']+ | '' | '(?: \#\d+)+' )* ) ' ]]; -- important: atomic group used
  },
  {
    name = "Char"; fgcolor = "purple"; color_unfinished= "darkblue on purple";
    pattern = [[ ' (?: \\. | [^\\'] ) ' ]];
  },
  {
    name = "Keyword"; fgcolor = "yellow";
    pattern = [[ \b(?: (?i)
      Absolute|Abstract|All|And|And_then|Array|Asm|Begin|Bindable|Case|Class|Const|Constructor|
      Destructor|Div|Do|Downto|Else|End|Export|File|For|Function|Goto|If|Import|Implementation|
      Inherited|In|Inline|Interface|Is|Label|Mod|Module|Nil|Not|Object|Of|Only|Operator|Or|Or_else|
      Otherwise|Packed|Pow|Private|Procedure|Program|Property|Protected|Public|Qualified|Record|
      Repeat|Restricted|Set|Shl|Shr|Then|To|Type|Unit|Until|Uses|Value|Var|View|Virtual|While|With|
      Xor
      )\b ]];
  },
  {
    name = "Type"; fgcolor = "white";
    pattern = [[ \b(?: (?i)
      Boolean|Byte|ByteBool|Cardinal|Char|Comp|Currency|Double|Extended|Int64|Integer|LongBool|
      Longint|Longword|PChar|QWord|Real|Shortint|Single|SmallInt|String|WideString|Word|WordBool
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
  name = "Pascal";
  filemask = "*.pas,*.dpr";
  syntax = syntax_pascal;
}
