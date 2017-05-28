' this is the actual .bin file for Fastload.asm
' with some constants as to original "sync" instruction
' and it's address... that is optionally replaced
' to allow the decompression routine to be ran
' without changing the size of the loader routine
#if 1 '.BIN for COCO LOADER (autorun on CLOSE with SWI)
  const LdrOrgA = &hE46F , LdrOrgB = &h448D , LdrAddr = &h310
  'const _pSpeedA = &h2F, _pSpeedB = &hF9
  const _pSpeedA = &h29, _pSpeedB = &hF5
  static shared as ubyte pbLoader(...) = { _   
  &h00,&h00,&hF6,&h02,&hE5,&hC6,&h7E,&hF7,&h01,&h76,&h6A,&h6B,&h10,&hFF,&h03,&hFE, _ '0
  &h10,&hCE,&h03,&hFB,&h86,&hFF,&h1F,&h8B,&h1A,&h50,&h96,&h01,&hD6,&h03,&hED,&h61, _ '1
  &h84,&h77,&h8A,&h08,&h97,&h01,&hC4,&h77,&hD7,&h03,&hC6,&h3C,&hE7,&h65,&hD7,&h21, _ '2
  &h6F,&hE4,&h8D,&h44,&hC1,&h4B,&h27,&h0C,&h5D,&h27,&h11,&h5C,&h26,&hF2,&h6D,&h60, _ '3
  &h2A,&h10,&h20,&h5B,&h6D,&h60,&h26,&h0C,&h6C,&h60,&h20,&h06,&h6D,&hE4,&h2F,&h06, _ '4
  &h60,&hE4,&h20,&hDE,&h32,&hE4,&h21,&hFE,&h20,&hF8,&h2B,&h10,&h86,&h01,&h95,&h20, _ '5
  &h27,&hFC,&h95,&h20,&h27,&hF8,&h21,&hF6,&hF8,&h00,&hAA,&h39,&h86,&h01,&h95,&h20, _ '6
  &h26,&hFC,&h95,&h20,&h26,&hF8,&h20,&hF0,&hC6,&h80,&h96,&h20,&h84,&h01,&h12,&h04, _ '7
  &h20,&h89,&h00,&h12,&h04,&h20,&h89,&h00,&h12,&h04,&h20,&h89,&h00,&h12,&h04,&h20, _ '8
  &h89,&hFD,&h56,&h25,&hC5,&h1F,&h00,&h20,&hE1,&h3A,&h3D,&h1F,&h00,&h20,&hD9,&h8D, _ '9
  &hD7,&hC1,&h01,&h22,&h8B,&h8E,&h00,&h00,&hE7,&hE4,&h3A,&h12,&h3D,&h8D,&hC9,&hE7, _ 'A
  &h8C,&h19,&h8D,&hE5,&hE7,&h8C,&h15,&h8D,&hE0,&hE7,&h8C,&h12,&h8D,&hDB,&hE7,&h8C, _ 'B
  &h0E,&h8D,&hD6,&h3A,&h1F,&h10,&h5D,&h26,&h20,&h10,&h8E,&h00,&h00,&hCE,&h00,&h00, _ 'C
  &hE6,&hE4,&h27,&h19,&h8D,&hA2,&h3A,&hE7,&hC0,&h3D,&h31,&h3F,&h26,&hF6,&h8D,&h98, _ 'D
  &h3A,&h1F,&h10,&h5D,&h26,&h03,&h3D,&h20,&hB6,&h86,&h45,&hED,&h65,&hEC,&h61,&h10, _ 'E
  &hEE,&h63,&h97,&h01,&hD7,&h03,&hC6,&h34,&hD7,&h21,&h3B,&h00,&h00,&h03,&h01,&h06, _ 'F
  &h7E,&h02,&hE5,&h00,&h00,&h01,&h01,&h76,&h3F,&hFF,&h00,&h00,&h02,&hE5 }
  ' 0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F       
#endif
' this is just the code for the decompressor, it's address independent
' but i'm loading at 1DA because it's the cassette buffer... so a safe place
' and the constants are for parts of it that must be set by the loader...
' like source,target addresses, and the last 5 uncompressed bytes... 
' as those could be overwritten when decompressing those "in place"
#if 1 '.raw (code) for decompressor
  const DecompAddr = &h1DA
  const _pSource = &h07, _pTarget = &h0B , _pExt01 = &h97, _pExt23 = &h9A, _pExt4 = &h9D
  const _pRestore01 = &hA5, _pRestore23 = &hA8, _pResOff = &hAB
  static shared as ubyte pbDecompress(...) = { _
  &h10,&hEF,&h8D,&h00,&hAE,&h10,&h8E,&hAA,&hAA,&h10,&hCE,&hAA,&hAA,&hEC,&hA1,&h44, _ '0
  &h25,&h5C,&h44,&h25,&h3D,&h27,&h1A,&hE7,&hE0,&h4A,&h27,&hF1,&h85,&h01,&h27,&h07, _ '1
  &hE6,&hA0,&hE7,&hE0,&h4A,&h27,&hE6,&hEE,&hA1,&hEF,&hE1,&h80,&h02,&h26,&hF8,&h20, _ '2
  &hDC,&h86,&h20,&hEE,&hA1,&hEF,&hE1,&h4A,&h26,&hF9,&h5D,&h27,&hD0,&hC5,&h01,&h27, _ '3
  &h07,&hA6,&hA0,&hA7,&hE0,&h5A,&h27,&hC5,&hEE,&hA1,&hEF,&hE1,&hC0,&h02,&h26,&hF8, _ '4
  &h20,&hBB,&hE7,&h8C,&h03,&h33,&hE9,&hFF,&hFF,&h85,&h01,&h27,&h07,&hE6,&hC0,&hE7, _ '5
  &hE0,&h4A,&h27,&hA9,&hAE,&hC1,&hAF,&hE1,&h80,&h02,&h26,&hF8,&h20,&h9F,&h44,&h25, _ '6
  &h1A,&h27,&h23,&h85,&h01,&h27,&h05,&hE7,&hE0,&h4A,&h27,&h91,&hE7,&h8C,&h01,&h8E, _ '7
  &h00,&h00,&h3A,&hAF,&hE1,&h80,&h02,&h26,&hFA,&h20,&h82,&hA7,&h8C,&h05,&hA6,&hA0, _ '8
  &h33,&hEB,&h86,&h00,&h20,&hC3,&h8E,&h55,&h55,&hCE,&h55,&h55,&h86,&h55,&hAF,&hE1, _ '9
  &hEF,&hE1,&hA7,&hE0,&hCE,&h66,&h66,&hCC,&h66,&h66,&h8E,&h77,&h77,&hEF,&h84,&hED, _ 'A
  &h02,&h10,&hCE,&h00,&h00,&h6E,&h84 }                                               'B
  ' 0    1    2    3    4    5    6    7    8    9    A    B    C    D    E    F       
#endif  
