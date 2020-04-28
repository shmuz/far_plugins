local syntax_makefile =
{
  bgcolor = 0x1;
  bracketmatch = true;
  {
    name = "Comment"; fgcolor = 0x7;
    pattern = [[ ^\s*\#.* ]];
  },
  {
    name = "Include"; fgcolor = 0xC;
    pattern = [[ ^\s* !? include (?! \S) .* ]];
  },
  {
    name = "Conditional"; fgcolor = 0xA;
    pattern = [[ ^\s* (?: ifeq|ifneq|ifdef|ifndef|else|endif|
                          !(?: if|else|endif|elseif|ifdef|ifndef|undef) ) (?! \S) .* ]];
  },
  {
    name = "Assign"; fgcolor = 0xE;
    pattern = [[ ^\s*[a-zA-Z_][a-zA-Z_0-9]* (?= \s* [:+?]?= ) ]];
  },
  {
    name = "Target"; fgcolor = 0xF;
    pattern = [[ ^ \s* [^:\s]+ (?: \s+ [^:\s]+ )* \s* ::? ]];
  },
}

Class {
  name = "Make file";
  filemask = "/makefile[^.]*$/i,*.mak";
  syntax = syntax_makefile;
}
