local syntax_pascal =
{
  bgcolor = 0x1;
  bracketmatch = true;
  {
    name = "Macro"; fgcolor = 0xA;
    pattern = [[ \{\$ [^}]* \} ]];
  },
  {
    name = "LongComment1"; fgcolor = 0x7;
    pat_open = [[ \(\* ]];
    pat_close = [[ \*\) ]];
  },
  {
    name = "LongComment2"; fgcolor = 0x7;
    pat_open = [[ \{ ]];
    pat_close = [[ \} ]];
  },
  {
    name = "Comment"; fgcolor = 0x7;
    pattern = [[ \/\/.* ]];
  },
  {
    name = "Literal"; fgcolor = 0xF;
    pattern = [[
      \b (?: (?: \d+\.\d* | \.?\d+) (?: [eE][+-]?\d+ )? ) \b |
      (?<! \w) \$[\da-fA-F]+ |
      (?<! \w) \&[07]+ |
      (?<! \w) \%[01]+
    ]];
  },
  {
    name = "String1"; fgcolor = 0xD;
    pattern = [[ " (?> (?: [^"]+ | "" | "(?: \#\d+)+" )* ) " ]]; -- important: atomic group used
  },
  {
    name = "String2"; fgcolor = 0xD;
    pattern = [[ ' (?> (?: [^']+ | '' | '(?: \#\d+)+' )* ) ' ]]; -- important: atomic group used
  },
  {
    name = "Char"; fgcolor = 0xD; color_unfinished= 0xD1;
    pattern = [[ ' (?: \\. | [^\\'] ) ' ]];
  },
  {
    name = "Keyword"; fgcolor = 0xE;
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
    name = "Type"; fgcolor = 0xF;
    pattern = [[ \b(?: (?i)
      Boolean|Byte|ByteBool|Cardinal|Char|Comp|Currency|Double|Extended|Int64|Integer|LongBool|
      Longint|Longword|PChar|QWord|Real|Shortint|Single|SmallInt|String|WideString|Word|WordBool
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
  name = "Pascal";
  filemask = "*.pas,*.dpr";
  syntax = syntax_pascal;
}
