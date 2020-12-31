#define xfbc -lib -x libSnd.a
'-nodeflibs

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
  dwMagic as dword  'cvl("WvOS")
  hWave as HANDLE
  iBuffers as integer  
  iCurBuf as integer  
  ppWaves as WAVEHDR ptr
  iRecord as integer
end type  

sub __GetWaveOutError__(iErr as integer)
  static as zstring*512 zErr = "Failed: "
  waveOutGetErrorTextA( iErr , @zErr+8 , 512 )    
  Messagebox( null , zErr , null , MB_ICONERROR or MB_SYSTEMMODAL )
  ExitProcess(iErr)
end sub

dim shared malloc2 as function cdecl ( size as long ) as any ptr
dim shared calloc2 as function cdecl ( size as long , iBlock as long = 1 ) as any ptr
dim shared free2   as sub      cdecl ( p as any ptr )
dim shared memcpy2 as sub      cdecl ( pTgt as any ptr , pSrc as any ptr , size as long )

sub __Init__ ()  
  static iInit as integer = 0
  if iInit=0 then
    iInit = 1
    var hLib = GetModuleHandle("msvcrt.dll")
    if hLib = 0 then hLib = LoadLibrary("msvcrt.dll")
    malloc2 = cast(any ptr,GetProcAddress(hLib,"malloc"))
    calloc2 = cast(any ptr,GetProcAddress(hLib,"calloc"))
    free2 = cast(any ptr,GetProcAddress(hLib,"free"))
    memcpy2 = cast(any ptr,GetProcAddress(hLib,"memcpy"))
  end if
end sub

extern "C"

  function AudioOpen( iHz as integer = 44100 , iBits as integer = 16, iChan as integer = 2, iBuffers as integer = 2, iDevice as integer=-1) as WaveOutStruct ptr export
    
    dim WavFmt as WAVEFORMATEXTENSIBLE, hResult as HWAVEOUT
    __Init__()
    
    with WavFmt
      select case iChan
      case -2  : iChan=2: .dwChannelMask = SPEAKER_BACK_LEFT or SPEAKER_BACK_RIGHT
      case -1  : iChan=1: .dwChannelMask = SPEAKER_BACK_CENTER
      case  1  : iChan=-1: .dwChannelMask = SPEAKER_FRONT_CENTER
      case  2  : iChan=-2: .dwChannelMask = SPEAKER_FRONT_LEFT or SPEAKER_FRONT_RIGHT
      case  3  : iChan=2: .dwChannelMask = SPEAKER_BACK_CENTER or SPEAKER_FRONT_CENTER
      case  4  : iChan=4: .dwChannelMask = SPEAKER_FRONT_LEFT or SPEAKER_FRONT_RIGHT or SPEAKER_BACK_LEFT or SPEAKER_BACK_RIGHT
      case else: return 0
      end select
      if iChan < 0 then      
        iChan = -iChan
        .Format.wFormatTag = WAVE_FORMAT_PCM
        .Format.cbSize = 0
      else
        .SubFormat = KSDATAFORMAT_SUBTYPE_PCM
        .Samples.wValidBitsPerSample = 0 '? tWaveFmt.Format.wBitsPerSample
        .Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE
        .Format.cbSize = sizeof(WAVEFORMATEXTENSIBLE)-sizeof(WaveFormatEx)    
      end if
      with .Format        
        .nSamplesPerSec = iHz   '44.1khz
        .wBitsPerSample = iBits '16
        .nChannels      = iChan 'mono,stereo
        .nBlockAlign    = (.nChannels*.wBitsPerSample)\8        
        .nAvgBytesPerSec = .nSamplesPerSec * .nBlockAlign
      end with
    end with
        
    if cuint(iBuffers-1) > 255 then return 0
    var pResult = cast( WaveOutStruct ptr , calloc2(sizeof(WaveOutStruct)) )
    if pResult = 0 then return 0
        
    if iDevice=-1 then iDevice = WAVE_MAPPER 
    
    var iResu = WaveOutOpen( @hResult , iDevice , cast(WAVEFORMATEX ptr,@WavFmt) , null , null , CALLBACK_NULL )
    if iResu <> MMSYSERR_NOERROR then __GetWaveOutError__( iResu )
      
    with *pResult
      .ppWaves = calloc2( sizeof(WAVEHDR)*iBuffers )
      if .ppWaves = 0 then WaveOutClose( hResult ): free2( pResult )
      .dwMagic = cvl("WvOS") : .hWave = hResult
      .iBuffers = iBuffers : .iCurBuf = 0: .iRecord = 0
    end with
    
    return pResult
  
  end function
  function AudioOpenRecord(iHz as integer = 44100 , iBits as integer = 16, iChan as integer = 1, iBuffers as integer = 2, iDevice as integer=-1) as WaveOutStruct ptr export
    
    dim WavFmt as WAVEFORMATEX, hResult as HWAVEIN
    __Init__()
    
    with WavFmt        
      .wFormatTag = WAVE_FORMAT_PCM    
      .nSamplesPerSec  = iHz   '44.1khz
      .wBitsPerSample  = iBits '16
      .nChannels       = iChan 'mono,stereo
      .nBlockAlign     = (.nChannels*.wBitsPerSample)\8
      .nAvgBytesPerSec = .nBlockAlign*.nSamplesPerSec
      .cbSize = 0 'sizeof(WAVEFORMATEXTENSIBLE)-sizeof(WaveFormatEx)
    end with
    
    if cuint(iBuffers-1) > 255 then return 0
    var pResult = cast( WaveOutStruct ptr , malloc2(sizeof(WaveOutStruct)) )
    if pResult = 0 then return 0
    
    if iDevice=-1 then iDevice = WAVE_MAPPER  
    var iResu = WaveInOpen( @hResult , iDevice , cast(WAVEFORMATEX ptr,@WavFmt) , null , null , CALLBACK_NULL )
    if iResu <> MMSYSERR_NOERROR then __GetWaveOutError__( iResu )
      
    with *pResult
      .ppWaves = calloc2( sizeof(WAVEHDR)*iBuffers )
      if .ppWaves = 0 then WaveInClose( hResult ): free2( pResult )
      .dwMagic = cvl("WvOS") : .hWave = hResult
      .iBuffers = iBuffers : .iCurBuf = -1: .iRecord = 1 
    end with
    
    return pResult
  
  end function
  function AudioWrite( pWave as WaveOutStruct ptr , pzBuff as any ptr , iSz as integer ) as integer export
    if pWave=null orelse pWave->dwMagic <> cvl("WvOS") then return 0
    if pWave->iRecord then return 0
    
    with *pWave  
      'possible wait for front buffer to finish
      var pBuf = .ppWaves+.iCurBuf    
      if pBuf->lpData then 
        while (pBuf->dwFlags and WHDR_PREPARED) andalso (pBuf->dwFlags and WHDR_DONE)=0
          return -1 'SleepEx 1,1
        wend
        WaveOutUnprepareHeader( .hWave , pBuf , sizeof(WAVEHDR) )
        free2( pBuf->lpData ): pBuf->lpData = null
      end if    
      'add new buffer
      if pzBuff andalso iSz then        
        pBuf->lpData = malloc2( iSz ) : memcpy2( pBuf->lpData , pzBuff , iSz )
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
  function AudioRead( pWave as WaveOutStruct ptr , pzBuff as any ptr , iSz as integer ) as integer export
    
    if pWave=null orelse pWave->dwMagic <> cvl("WvOS") then return 0
    if pWave->iRecord=0 then return 0
    
    if pWave->iCurBuf < 0 then    
      for N as integer = 0 to (pWave->iBuffers)-1
        with pWave->ppWaves[N]
          .dwBufferLength = iSz
          .lpData = malloc2( iSz )
          if .lpData = 0 then
            for I as integer = 0 to N-1
              free2(pWave->ppWaves[I].lpData)
              pWave->ppWaves[I].lpData = 0        
            next I
            return 0
          end if
        end with    
      next N
    end if
    
    for N as integer = 0 to (pWave->iBuffers)-1
      with pWave->ppWaves[N]
        if (.dwFlags and WHDR_PREPARED)=0 then
          .dwBytesRecorded = 0: .dwFlags = 0 : .dwUser = 0
          waveInPrepareHeader( pWave->hWave , pWave->ppWaves+N , sizeof(WAVEHDR) )
          waveInAddBuffer( pWave->hWave , pWave->ppWaves+N , sizeof(WAVEHDR) )
        end if
      end with
    next N
  
    if pWave->iCurBuf < 0 then
      waveInStart( pWave->hWave ): pWave->iCurBuf = 0
    end if
    
    with pWave->ppWaves[pWave->iCurBuf]
      if (.dwFlags and WHDR_DONE) orelse (.dwBytesRecorded-.dwUser) >= iSz then
        var iCpyLen = .dwBufferLength-.dwUser
        if iSz < iCpyLen then iCpyLen = iSz
        memcpy2( pzBuff , .lpData+.dwUser , iCpyLen )
        .dwUser += iCpyLen
        if .dwUser >= .dwBufferLength then
          waveInUnprepareHeader( pWave->hWave , pWave->ppWaves+pWave->iCurBuf , sizeof(WAVEHDR) )
          .dwFlags=0:.dwUser=0:.dwBytesRecorded=0
          pWave->iCurBuf = (pWave->iCurBuf+1) mod pWave->iBuffers
        end if
        return iCpyLen
      end if
    end with
    
    return -1
  end function
  sub AudioWaitBuffers( pWave as WaveOutStruct ptr) export
    if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub
    with *pWave    
      for N as integer = 0 to .iBuffers-1
        while AudioWrite( pWave , 0 , 0 )=-1
          sleepex 1,1
        wend
      next N
    end with
  end sub
  sub AudioClose( byref pWave as WaveOutStruct ptr ) export
    if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub
    with *pWave
      if .iRecord then    
        WaveInStop( .hWave ): WaveInClose( .hWave) : .hWave = 0
        for N as integer = 0 to .iBuffers-1      
          if .ppWaves[N].lpData then 
            free2( .ppWaves[N].lpData ): .ppWaves[N].lpData=0
          end if
        next N    
      else    
        for N as integer = 0 to .iBuffers-1
          while AudioWrite( pWave , 0 , 0 )=-1
            sleepex 1,1
          wend
        next N
        var iResu = WaveOutClose( .hWave ): .hWave = null
        if iResu <> MMSYSERR_NOERROR then __GetWaveOutError__(iResu)      
      end if
      
      free2( .ppWaves ) : .ppWaves = 0
      .dwMagic = 0: .iBuffers = 0
    end with
    
    free2( pWave ) : pWave=0
  end sub
end extern

#if 0
  const iRate = 44100, iBuffSz = (iRate\35)
  const iScrWid = iBuffSz
  
  dim as integer iN, iC, iMedLo = -16 , iMedHi = 16
    
  dim as short aBuff(iBuffSz)
  var pSnd = AudioOpenRecord(iRate,16,1,8)
  screenres iScrWid,256
  palette 2,0,48,0: palette 10,0,192,0
  palette 4,64,0,0: palette 12,255,0,0
  palette 11,0,255,255: palette 13,255,0,255
  palette 14,255,255,0
  
  var pImg = cast(any ptr,0) 'ImageCreate(iBuffSz\4,256)
  do
    var iResu = AudioRead( pSnd , @aBuff(0) , (ubound(aBuff)+1)*sizeof(ushort) )
    if iResu = 0 then 
      print "Error on AudioRead"
      sleep:system
    end if
    if iResu < 0 then sleep 1,1: continue do
      
    dim as integer iOldLo=128,iOldHi=128,iOldMid=128
    screenlock    
    line pImg,(0,0)-(iBuffSz-1,255),0,bf  
    dim as integer iLast=0
    for N as integer = 0 to iScrWid-1
      'line(N+I,128+(aBuff(N) shr 8))-(N+1+I,128+(aBuff(N+1) shr 8)),10
      var iN = abuff(N) shr 8
      if iN < iMedLo then iMedLo = iN
      if iN > iMedHi then iMedHi = iN
      'if iN < -32 then iMedLo = (iMedLo*3+iN) shr 2
      'if iN >  32 then iMedHi = (iMedHi*3+iN) shr 2
      if iN < 0 then iMedLO = ((iMedLo*127)+iN) shr 7
      if iN > 0 then iMedHi = ((iMedHi*127)+iN) shr 7
      
      var iN2 = iN-((iMedLo+iMedHi) shr 1)
      'var iAmp = ((iMedHi-iMedLo) shr 1)
      if iN2 <= (iMedLO*.6) then '(iMedLo-(iMedLo shr 4)) then 
        iC = 12
        'iN = (iN*-100)/iMedLo
        'iN = -128
      elseif iN2 >= (iMedHi*.6) then ' (iMedHi-(iMedHi shr 4)) then
        'iN = 127
        iC = 10
        'iN = (iN*100)/iMedHi
      else
        'iN = 0        
        iC = iif(iN2<0,4,2)
      end if
      
      line pImg,(N,128)-step(0,iN),iC      
      'line pImg,(0,128)-(32767,128),iC,rgb(0,128,0)
      var iNewLo = 128+iMedLo, iNewHi = 128+iMedHi, iNewMid=128+((iMedLo+iMedHi) shr 1)
      line(N-1,iOldLo)-(N,iNewLo), 11,,&h5555
      line(N-1,iOldMid)-(N,iNewMid), 14,,&h5555
      line(N-1,iOldHi)-(N,iNewHi), 13,,&hAAAA
      iOldLo = iNewLo: iOldHi = iNewHi: iOldMid = iNewMid
    next N        
    
    locate 1,1: print iMedLo, iMedHi
    'put(0,0),pImg,alpha,240
    screenunlock
    
    
    'print ".";
  loop until len(inkey$)
  AudioClose( pSnd )
  print "Done."
  sleep
#endif

#if 0
  var pSnd = AudioOpen( 16000 , 8 , 1 , 1 )
  dim as ubyte bNoise( 15999 )
  
  for N as integer = 0 to 15999
    bNoise(N) = 128+(sin(N)*127)
  next N
  
  AudioWrite( pSnd , @bNoise(0) , 16000 )
  
  AudioWaitBuffers( pSnd )
  print "Done."
  sleep
  AudioClose( pSnd )
#endif


