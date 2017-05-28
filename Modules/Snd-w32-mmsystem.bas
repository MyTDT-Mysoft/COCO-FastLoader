#Include once "windows.bi"
#include once "win\mmsystem.bi"
#include once "MyTDT\WaveFormatExtensible.bi"

'#undef waveOutGetErrorTextW
'#define waveOutGetErrorTextW rem

#if 0
type Sample as ubyte
type StereoSample
  as sample wLeft,wRight
end type
#endif
type WaveOutStruct
  dwMagic as dword  'cvi("WvOS")
  hWave as HWAVEOUT
  iBuffers as integer  
  iCurBuf as integer  
  ppWaves as WAVEHDR ptr
end type  

sub GetWaveOutError(iErr as integer)
  dim as wstring*4096 wErr = "Failed: "
  waveOutGetErrorTextW( iErr , @wErr+8 , 4096 )    
  MessageboxW( null , wErr , null , MB_ICONERROR or MB_SYSTEMMODAL )
  system
end sub
function AudioOpen( iHz as integer = 44100 , iBits as integer = 16, iChan as integer = 2, iBuffers as integer = 2, iDevice as integer=-1) as WaveOutStruct ptr
  
  dim WavFmt as WAVEFORMATEXTENSIBLE, hResult as HWAVEOUT
    
  with WavFmt
    select case iChan
    case -2  : iChan=2: .dwChannelMask = SPEAKER_BACK_LEFT or SPEAKER_BACK_RIGHT
    case -1  : iChan=1: .dwChannelMask = SPEAKER_BACK_CENTER
    case  1  : iChan=1: .dwChannelMask = SPEAKER_FRONT_CENTER
    case  2  : iChan=2: .dwChannelMask = SPEAKER_FRONT_LEFT or SPEAKER_FRONT_RIGHT
    case  3  : iChan=2: .dwChannelMask = SPEAKER_BACK_CENTER or SPEAKER_FRONT_CENTER
    case  4  : iChan=4: .dwChannelMask = SPEAKER_FRONT_LEFT or SPEAKER_FRONT_RIGHT or SPEAKER_BACK_LEFT or SPEAKER_BACK_RIGHT
    case else: return 0
    end select
    .SubFormat = KSDATAFORMAT_SUBTYPE_PCM
    .Samples.wValidBitsPerSample = 0 '? tWaveFmt.Format.wBitsPerSample
    with .Format
      .wFormatTag = WAVE_FORMAT_EXTENSIBLE        
      .nSamplesPerSec = iHz   '44.1khz
      .wBitsPerSample = iBits '16
      .nChannels      = iChan 'mono,stereo
      .nBlockAlign    = (.nChannels*.wBitsPerSample)\8
      .cbSize = sizeof(WAVEFORMATEXTENSIBLE)-sizeof(WaveFormatEx)    
    end with
  end with
  
  if cuint(iBuffers-1) > 255 then return 0
  var pResult = cast( WaveOutStruct ptr , allocate(sizeof(WaveOutStruct)) )
  if pResult = 0 then return 0
  
  if iDevice=-1 then iDevice = WAVE_MAPPER  
  var iResu = WaveOutOpen( @hResult , iDevice , cast(WAVEFORMATEX ptr,@WavFmt) , null , null , CALLBACK_NULL )
  if iResu <> MMSYSERR_NOERROR then GetWaveOutError( iResu )
    
  with *pResult
    .ppWaves = callocate( sizeof(WAVEHDR)*iBuffers )
    if .ppWaves = 0 then WaveOutClose( hResult ): deallocate( pResult )
    .dwMagic = cvi("WvOS") : .hWave = hResult
    .iBuffers = iBuffers : .iCurBuf = 0
  end with
  
  return pResult

end function
function AudioWrite( pWave as WaveOutStruct ptr , pzBuff as any ptr , iSz as integer ) as integer
  if pWave=null orelse pWave->dwMagic <> cvi("WvOS") then return 0
  
  with *pWave  
    'possible wait for front buffer to finish
    var pBuf = .ppWaves+.iCurBuf    
    if pBuf->lpData then 
      while (pBuf->dwFlags and WHDR_PREPARED) andalso (pBuf->dwFlags and WHDR_DONE)=0
        return -1 'SleepEx 1,1
      wend
      WaveOutUnprepareHeader( .hWave , pBuf , sizeof(WAVEHDR) )
      Deallocate( pBuf->lpData ): pBuf->lpData = null
    end if    
    'add new buffer
    if pzBuff andalso iSz then        
      pBuf->lpData = allocate( iSz ) : memcpy( pBuf->lpData , pzBuff , iSz )
      pBuf->dwFlags = 0: pBuf->dwBufferLength = iSz
      WaveOutprepareHeader( .hWave , pBuf , sizeof(WAVEHDR) )
      WaveOutWrite( .hWave , pBuf , sizeof(WAVEHDR) )        
    else
      pBuf->lpData = null
    end if
    .iCurBuf = (.iCurBuf+1) mod .iBuffers
    
    return (.iCurBuf+1)
  end with

end function
sub AudioWaitBuffers( pWave as WaveOutStruct ptr)
  if pWave=0 orelse pWave->dwMagic <> cvi("WvOS") then exit sub
  with *pWave    
    for N as integer = 0 to .iBuffers-1
      while AudioWrite( pWave , 0 , 0 )=-1
        sleepex 1,1
      wend
    next N
  end with
end sub
sub AudioClose( byref pWave as WaveOutStruct ptr )
  if pWave=0 orelse pWave->dwMagic <> cvi("WvOS") then exit sub
  with *pWave
    for N as integer = 0 to .iBuffers-1
      while AudioWrite( pWave , 0 , 0 )=-1
        sleepex 1,1
      wend
    next N
    var iResu = WaveOutClose( .hWave ): .hWave = null
    if iResu <> MMSYSERR_NOERROR then GetWaveOutError(iResu)
    deallocate( .ppWaves ) : .ppWaves = 0
    .dwMagic = 0: .iBuffers = 0
  end with
  deallocate( pWave ) : pWave=0
end sub

#if 0
  var pSnd = AudioOPen( 16000 , 8 , 1 , 1 )
  dim as ubyte bNoise( 15999 )
  
  for N as integer = 0 to 15999
    bNoise(N) = 128+rnd*16
  next N
  
  AudioWrite( pSnd , @bNoise(0) , 16000 )
  
  AudioWaitBuffers( pSnd )
  print "Done."
  sleep
  AudioClose( pSnd )
#endif


