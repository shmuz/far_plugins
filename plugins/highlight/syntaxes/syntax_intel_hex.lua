local syntax_hex =
{
  bgcolor = "darkblue";
  {
    name = "Colon"; fgcolor = "white";
    pattern = [[ ^ : ]];
  },
  {
    name = "Byte count"; fgcolor = "red";
    pattern = [[ (?<= :) [0-9a-fA-F]{2} ]];
  },
  {
    name = "Address"; fgcolor = "yellow";
    pattern = [[ (?<= : [0-9a-fA-F]{2}) [0-9a-fA-F]{4} ]];
  },
  {
    name = "RecordType"; fgcolor = "purple";
    pattern = [[ (?<= : [0-9a-fA-F]{6}) [0-9a-fA-F]{2} ]];
  },
  {
    name = "Checksum"; fgcolor = "white";
    pattern = [[ [0-9a-fA-F]{2} \s* $ ]];
  },
}

Class {
  name = "Intel hex file";
  filemask = "*.hex";
  syntax = syntax_hex;
  fastlines = 0;
}
