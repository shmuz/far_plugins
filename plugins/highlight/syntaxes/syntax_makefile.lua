local syntax_makefile =
{
  bgcolor = "darkblue";
  bracketmatch = true;
  {
    name = "Comment"; fgcolor = "gray7";
    pattern = [[ ^\s*\#.* ]];
  },
  {
    name = "Include"; fgcolor = "red";
    pattern = [[ ^\s* [!\-]? include (?! \S) .* ]];
  },
  {
    name = "Conditional"; fgcolor = "green";
    pattern = [[ ^\s* (?: ifeq|ifneq|ifdef|ifndef|else|endif|
                          !(?: if|else|endif|elseif|ifdef|ifndef|undef) ) (?! \S) .* ]];
  },
  {
    name = "Assign"; fgcolor = "yellow";
    pattern = [[ ^\s*[a-zA-Z_][a-zA-Z_0-9]* (?= \s* [:+?]?= ) ]];
  },
  {
    name = "Target"; fgcolor = "white";
    pattern = [[ ^ (?: \S+\s+)* \S+\s* ::? (?= \s|$) ]];
  },
}

Class {
  name = "Make file";
  filemask = "/makefile([._\\-].+)?$/i,*.mak";
  syntax = syntax_makefile;
}
