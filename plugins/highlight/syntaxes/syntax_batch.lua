local syntax_batch =
{
  bgcolor = "darkblue";
  {
    name = "Comment1"; fgcolor = "gray7";
    pattern = [[ (?i) ^ \s* @? \s* REM (?: \s+ .*)? $ ]];
  },
  {
    name = "Comment2"; fgcolor = "gray7";
    pattern = [[ ^ :: .* ]];
  },
  {
    name = "Label"; color = "white on gray8";
    pattern = [[ ^ : \w+ \s* $ ]];
  },
  {
    name = "Echo"; fgcolor = "purple";
    pattern = [[ (?i) @? \s* \b ECHO \.? (?: \s+ .*)? $ ]];
  },
  {
    name = "EnvVar"; fgcolor = "green";
    pattern = [[ % \w+ % ]];
  },
  {
    name = "Keyword"; fgcolor = "yellow";
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
    name = "Batch parameter"; fgcolor = "green";
    pattern = [[ % (?: ~ [fdpnxsatz]* )? [0-9] \b | (?<!\S) %\* (?!\S) ]];
  },
  {
    name = "MathOp"; fgcolor = "white";
    pattern = [[ [^\w\s] ]];
  },
}

Class {
  name = "Windows batch file";
  filemask = "*.bat,*.cmd";
  syntax = syntax_batch;
}
