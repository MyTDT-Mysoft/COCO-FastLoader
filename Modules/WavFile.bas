Type WaveFileHeader
  ChunkID       as ulong
  ChunkSize     as ulong
  ChunkFormat   as ulong
  SubChunk1ID   as ulong
  SubChunk1Size as ulong
  AudioFormat   as ushort
  NumChannels   as ushort
  SampleRate    as ulong
  ByteRate      as ulong
  BlockAlign    as ushort
  BitsPerSample as ushort
  'ExtraParamSz  as ushort
  'ExtraParams   as ushort
  SubChunk2ID   as ulong
  Subchunk2Size as ulong  
end type
type WavFileStruct
  iWfSm     as ulong 'WfSm' magic
  iFile     as ulong
  tWav      as WaveFileHeader  
end type

sub WaveFileUpdate( pWav as WavFileStruct ptr )
  if pWav = 0 then exit sub  
  if pWav->iWfSm <> cvl("WfSm") then exit sub
  if pWav->iFile = 0 then exit sub
  
  var iOldPos = seek(pWav->iFile)
  pWav->tWav.ChunkSize = pWav->tWav.Subchunk2Size+sizeof(WaveFileHeader)-8
  put #(pWav->iFile),1,pWav->tWav
  seek #(pWav->iFile),iOldPos
  
end sub
function WaveFileCreate( sFile as string , iFrequency as long , iBits as long, iChannels as long ) as WavFileStruct ptr
  
  'Bad frequency?
  if iFrequency < 32 or iFrequency > (1 shl 24) then return 0
  'Bad bitsize
  if iBits < 8 or iBits > 16 then return 0
  'Bad channels?
  if iChannels < 1 or iChannels > 2 then return 0
  
  'allocate memory for header
  var pHdr = cast(WavFileStruct ptr, allocate(sizeof(WavFileStruct)))
  if pHdr=0 then return 0
  
  'the filename can be opened as output?
  var iFile = freefile()
  if open(sFile for binary access write as #iFile) then 
    deallocate(pHdr): pHdr=0: return 0
  end if
  
  'fill the object header
  with *pHdr
    .iWfSm = cvl("WfSm")
    .iFile = iFile 
    with .tWav
      .Subchunk2Size = 0
      .ChunkID = cvl("RIFF")
      .ChunkSize = .Subchunk2Size+sizeof(WaveFileHeader)-8
      .ChunkFormat = cvl("WAVE")
      .SubChunk1ID = cvl("fmt ")
      .SubChunk1Size = 16
      .AudioFormat = 1
      .NumChannels = iChannels
      .SampleRate = iFrequency
      .BitsPerSample = iBits
      .BlockAlign = .NumChannels*(.BitsPerSample\8)
      .ByteRate = .SampleRate*.BlockAlign
      
      .SubChunk2ID = cvl("data")
    end with
  end with
  
  if put(#iFile,,pHdr->tWav) then
    deallocate(pHdr): pHdr = 0
    close #iFile: iFile = 0
    return 0
  end if  
  
  return pHdr
  
end function
function WaveFileWrite( pWav as WavFileStruct ptr , pData as any ptr , iSize as long ) as long  
  if pWav = 0 then return 0    
  if pWav->iWfSm <> cvl("WfSm") then return 0  
  if pWav->iFile = 0 then return 0
  if put(#(pWav->iFile),,*cptr(ubyte ptr,pData), iSize) then    
    return 0
  else
    pWav->tWav.Subchunk2Size += iSize
    return iSize
  end if
end function
sub WaveFileClose( byref pWav as WavFileStruct ptr )
  if pWav = 0 then exit sub  
  if pWav->iWfSm <> cvl("WfSm") then exit sub
  if pWav->iFile = 0 then exit sub
  
  vprint(vlMinimum,11) "Dumped Wav Size: " & seek(pWav->iFile)
    
  pWav->tWav.ChunkSize = pWav->tWav.Subchunk2Size+sizeof(WaveFileHeader)-8
  put #(pWav->iFile),1,pWav->tWav
  close #pWav->iFile : pWav->iFile = 0
  
  pWav->iWfSm = 0
  deallocate(pWav) : pWav=0
end sub