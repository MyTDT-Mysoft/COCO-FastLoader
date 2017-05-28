#include once "win\mmreg.bi"
#ifndef WAVEFORMATEXTENSIBLE
  union SamplesUnion
    as WORD wValidBitsPerSample
    as WORD wSamplesPerBlock
    as WORD wReserved
  end union
  type WAVEFORMATEXTENSIBLE
    Format as WAVEFORMATEX
    Samples as SamplesUnion  
    dwChannelMask as dword
    SubFormat as GUID
  end type    
#endif

#undef KSDATAFORMAT_SUBTYPE_PCM
#define KSDATAFORMAT_SUBTYPE_PCM   type(&h00000001,&h0000,&h0010,{&h80,&h00,&h00,&haa,&h00,&h38,&h9b,&h71})

#undef KSDATAFORMAT_SUBTYPE_ADPCM
#define KSDATAFORMAT_SUBTYPE_ADPCM type(&h00000002,&h0000,&h0010,{&h80,&h00,&h00,&haa,&h00,&h38,&h9b,&h71})

#undef KSDATAFORMAT_SUBTYPE_MPEG
#define KSDATAFORMAT_SUBTYPE_MPEG  type(&h00000050,&h0000,&h0010,{&h80,&h00,&h00,&haa,&h00,&h38,&h9b,&h71})  
