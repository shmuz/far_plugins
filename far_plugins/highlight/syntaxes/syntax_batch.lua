local syntax_batch =
{
  bgcolor = 0x1;
  {
    name = "Comment1"; fgcolor = 0x7;
    pattern = [[ (?i) ^ \s* @? \s* REM (?: \s+ .*)? $ ]];
  },
  {
    name = "Comment2"; fgcolor = 0x7;
    pattern = [[ ^ :: .* ]];
  },
  {
    name = "Label"; color = 0x8F;
    pattern = [[ ^ : \w+ \s* $ ]];
  },
  {
    name = "Echo"; fgcolor = 0xD;
    pattern = [[ (?i) ^ \s* @? \s* ECHO \.? (?: \s+ .*)? $ ]];
  },
  {
    name = "EnvVar"; fgcolor = 0xA;
    pattern = [[ % \w+ % ]];
  },
  {
    name = "Keyword"; fgcolor = 0xE;
    --color = { ForegroundColor=0x00FF00; BackgroundColor=0x000080; Flags={FCF_FG_BOLD=1} };
    pattern = [[ (?i) (?<! [%.]) \b(?:
      ASSOC|BREAK|CALL|CD|CHDIR|CHCP|CLS|CMDEXTVERSION|COLOR|COPY|DATE|DEL|ERASE|ERRORLEVEL|DIR|
      ELSE|ENDLOCAL|EXIT|FOR|FTYPE|GOTO|
      EQU|GEQ|
      IF\s+EXIST | IF\s+NOT\s+EXIST |
      IF\s+DEFINED | IF\s+NOT\s+DEFINED |
      IF\s+NOT | IF |
      MD|MKDIR|MOVE|PATH|PAUSE|POPD|PROMPT|PUSHD|RD|RMDIR|REN|RENAME|SET|SETLOCAL|SHIFT|START|TIME|
      TITLE|TYPE|VER|VERIFY|VOL
      )\b ]];
  },
  {
    name = "Batch parameter"; fgcolor = 0xA;
    pattern = [[ % (?: ~ [fdpnxsatz]* )? [0-9] \b | (?<!\S) %\* (?!\S) ]];
  },
  {
    name = "MathOp"; fgcolor = 0xF;
    pattern = [[ [^\w\s] ]];
  },
}

Class {
  name = "Windows batch file";
  filemask = "*.bat,*.cmd";
  syntax = syntax_batch;
}
