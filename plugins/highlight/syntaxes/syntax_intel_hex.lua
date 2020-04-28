local syntax_hex =
{
  bgcolor = 0x1;
  {
    name = "Colon"; fgcolor = 0xF;
    pattern = [[ ^ : ]];
  },
  {
    name = "Byte count"; fgcolor = 0xC;
    pattern = [[ (?<= :) [0-9a-fA-F]{2} ]];
  },
  {
    name = "Address"; fgcolor = 0xE;
    pattern = [[ (?<= : [0-9a-fA-F]{2}) [0-9a-fA-F]{4} ]];
  },
  {
    name = "RecordType"; fgcolor = 0xD;
    pattern = [[ (?<= : [0-9a-fA-F]{6}) [0-9a-fA-F]{2} ]];
  },
  {
    name = "Checksum"; fgcolor = 0xF;
    pattern = [[ [0-9a-fA-F]{2} \s* $ ]];
  },
}

Class {
  name = "Intel hex file";
  filemask = "*.hex";
  syntax = syntax_hex;
  fastlines = 0;
}
