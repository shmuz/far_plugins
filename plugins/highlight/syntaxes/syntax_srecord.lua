local syntax_srec =
{
  bgcolor = "darkblue";
  {
    name = "RecordType"; fgcolor = "white";
    pattern = [[ ^ S [0-9] ]];
  },
  {
    name = "Byte count"; fgcolor = "purple";
    pattern = [[ (?<= S[0-9]) [0-9a-fA-F]{2} ]];
  },
  {
    name = "Address"; fgcolor = "yellow";
    pattern = [[ (?<= S[0159] [0-9a-fA-F]{2}) [0-9a-fA-F]{4} |
                 (?<= S[268]  [0-9a-fA-F]{2}) [0-9a-fA-F]{6} |
                 (?<= S[37]   [0-9a-fA-F]{2}) [0-9a-fA-F]{8}   ]];
  },
  {
    name = "Checksum"; fgcolor = "red";
    pattern = [[ [0-9a-fA-F]{2} \s* $ ]];
  },
}

Class {
  name = "Motorola S-record file";
  filemask = "*.s19;*.s28;*.s37";
  syntax = syntax_srec;
  fastlines = 0;
}
