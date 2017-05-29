#include "..\inc\ao.bi"

type WaveOutStruct
  dwMagic as ulong  'cvl("WvOS")
  hWave as ao_device ptr
  iBuffers as long  
  iCurBuf as long  
  ppWaves as any ptr 'WAVEHDR ptr
end type  

function AudioOpen( iHz as long = 44100 , iBits as long = 16, iChan as long = 2, iBuffers as long = 2, iDevice as integer=-1) as WaveOutStruct ptr
  
  dim WavFmt as ao_sample_format, hResult as ao_device ptr
  
  DebugShowLine()
  
  with WavFmt
    select case iChan
    case -2  : iChan=2: .matrix = @"BL,BF"
    case -1  : iChan=1: .matrix = @"BC"
    case  1  : iChan=1: .matrix = 0
    case  2  : iChan=2: .matrix = 0
    case  3  : iChan=2: .matrix = @"C,BC"
    case  4  : iChan=4: .matrix = @"L,R,BL,BR"
    case else: return 0
    end select         
    
    .rate = iHz   '44.1khz
    .bits = iBits '16
    .channels = iChan 'mono,stereo
    .byte_format = AO_FMT_LITTLE
  end with
  
  DebugShowLine()
  
  if cuint(iBuffers-1) > 255 then return 0
  var pResult = cast( WaveOutStruct ptr , allocate(sizeof(WaveOutStruct)) )
  if pResult = 0 then return 0
  
  DebugShowLine()
  
  ao_initialize()
  
  DebugShowLine()
  
  var driver = iif(iDevice=-1,ao_default_driver_id(),iDevice)
  
  'print "Default Driver: " & driver  
  'print "rate:" & WavFmt.rate & " bits:" & WavFmt.Bits & " channels:"  & WavFmt.channels
  'print " byte_format:" & WavFmt.byte_format & " matrix: " & *iif(wavFmt.matrix,WavFmt.matrix,@"null")
  
  hResult = ao_open_live(driver, @WavFmt, 0)  
  
  DebugShowLine()
  
  if hResult=0 then deallocate(pResult): return 0
    
  DebugShowLine()
    
  with *pResult
    '.ppWaves = callocate( sizeof(WAVEHDR)*iBuffers )
    'if .ppWaves = 0 then WaveOutClose( hResult ): deallocate( pResult )
    .ppWaves = null
    .dwMagic = cvl("WvOS") : .hWave = hResult
    .iBuffers = iBuffers : .iCurBuf = 0
    
  end with
  
  DebugShowLine()
  
  return pResult

end function
function AudioWrite( pWave as WaveOutStruct ptr , pzBuff as any ptr , iSz as long ) as long
  if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then return 0
  
  with *pWave  
    ao_play(.hWave, pzBuff, iSz)
    return 1
  end with

end function
sub AudioWaitBuffers( pWave as WaveOutStruct ptr)
  if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub
  with *pWave    
    exit sub
  end with
end sub
sub AudioClose( byref pWave as WaveOutStruct ptr )
  if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub
   DebugShowLine()
  AudioWaitBuffers(pWave)
   DebugShowLine()
  with *pWave    
     DebugShowLine()
    ao_close( .hWave ): .hWave = 0
     DebugShowLine()
    ao_shutdown()
     DebugShowLine()
    if .ppWaves then deallocate( .ppWaves ) : .ppWaves = 0
     DebugShowLine()
    .dwMagic = 0: .iBuffers = 0
  end with
   DebugShowLine()
  deallocate( pWave ) : pWave=0
   DebugShowLine()
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


