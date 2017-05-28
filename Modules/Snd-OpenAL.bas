#include "AL/al.bi"
#include "AL/alc.bi"
#include "AL/alext.bi"

#ifndef AL_FORMAT_QUAD16  
  const AL_FORMAT_QUAD16 = &h1205
  #print "no QUAD16 extension found on headers... (back speaker may not work)"  
#endif 

type WaveOutStruct
  dwMagic as ulong  'cvl("WvOS")
  hWave as ALCdevice ptr
  iBuffers as long  
  iCurBuf as long  
  iFrequency as long
  iBits as long
  iChan as long
  pContext as ALCcontext ptr
  iFmtOut as ALenum
  iSource as ALuint  
  piBuffers as ALuint ptr  
  pTempBuff as any ptr  
  iOldBuffer as long
  iBufferCount as long
end type  

function int_alGetError() as ALenum
  var iResu = alGetError()
  if iResu = AL_INVALID_OPERATION then return AL_NO_ERROR
  return iResu
end function

function AudioOpen( iHz as integer = 44100 , iBits as integer = 16, iChan as integer = 2, iBuffers as integer = 2, iDevice as integer=-1) as WaveOutStruct ptr
  
  dim as ALenum iSamFmt
  dim as WaveOutStruct ptr pResult
  dim as zstring ptr pDevice = 0
  
  if iDevice <> -1 andalso alcIsExtensionPresent(0, "ALC_ENUMERATION_EXT") then
    var iEnum = iif(alcIsExtensionPresent(0, "ALC_ENUMERATE_ALL_EXT") , ALC_ALL_DEVICES_SPECIFIER , ALC_DEVICE_SPECIFIER )
    var iNum=0,pDev = cptr(zstring ptr,AlcGetString( 0 , iEnum ) ) 'ALC_DEVICE_SPECIFIER ))
    while (*pDev)[0]  
      if iDevice=iNum then pDevice = pDev: exit while
      'print *pDev
      pDev += len(*pDev)+1: iNum += 1      
    wend
    if pDevice = 0 then print "OpenAL: device " & iDevice & " not found":return 0
  end if
  
  do

    select case iChan
    case -2  : iSamFmt = AL_FORMAT_QUAD16
    case -1  : iSamFmt = AL_FORMAT_QUAD16
    case  1  : iSamFmt = iif(iBits=8,AL_FORMAT_MONO8,AL_FORMAT_MONO16)
    case  2  : iSamFmt = iif(iBits=8,AL_FORMAT_STEREO8,AL_FORMAT_STEREO16)
    case  3  : iSamFmt = AL_FORMAT_QUAD16
    case  4  : iSamFmt = AL_FORMAT_QUAD16
    case else: return 0
    end select
        
    if iBits <> 8 and iBits <> 16 then print "OpenAL: invalid bitsize " & iBits:return 0
    if cuint(iBuffers-1) > 255 then print "OpenAL: invalid buffer count" & iBuffers: return 0
    pResult = cptr( WaveOutStruct ptr , callocate(sizeof(WaveOutStruct)) )
    if pResult = 0 then print "OpenAL: failed to allocate WaveOut structure": return 0
    
    with *pResult
      dim as ALCint iFreq, iParms(...) = {ALC_FREQUENCY, iHz, 0, 0}
      .hWave = alcOpenDevice(0)
      if .hWave = 0 then print "OpenAL: failed to open device":exit do
      .pContext = alcCreateContext( .hWave , 0 ) '@iParms(0) )      
      if .pContext = 0 orelse int_alGetError() then print "OpenAL: failed to create context.":exit do
      alcMakeContextCurrent(.pContext)      
      if int_alGetError() then .pContext=0: print "OpenAL: failed to make context current.": exit do
      alcGetIntegerv( .hWave , ALC_FREQUENCY , sizeof(iFreq), @iFreq )
      if int_alGetError() then print "OpenAL: failed to get base frequency": exit do
      if iFreq < iHz then print "OpenAL: requested frequency of " & iHz & " is bigger than base " & iFreq:exit do
      .piBuffers = callocate(sizeof(aluint)*iBuffers)
      if .piBuffers = 0 then print "OpenAL: failed to allocate buffers" :exit do
      .pTempBuff = callocate( 65536 )    
      if .pTempBuff = 0 then print "OpenAL: failed to allocate auxiliar buffer space": exit do
      alGenBuffers( iBuffers , .piBuffers )
      if int_alGetError() then print "OpenAL: failed to generate auxiliary buffers": exit do
      alGenSources( 1 , @.iSource )
      if int_alGetError() then print "OpenAL: failed to generate source":exit do    
      .dwMagic = cvl("WvOS") 
      .iFmtOut = iSamFmt
      .iFrequency = iHZ : .iBits = iBits: .iChan = iChan
      .iBuffers = iBuffers : .iCurBuf = 0 
      .iOldBuffer = 0 : .iBufferCount = 0
    end with
    
    return pResult
  loop
  
  'Error Happened
  with *pResult
    if .piBuffers andalso .piBuffers[0] then alDeleteBuffers( iBuffers , .piBuffers )
    if .iSource then alDeleteSources( 1 , @.iSource )    
    if .pTempBuff then deallocate(.pTempBuff):.pTempBuff=0
    if .piBuffers then deallocate(.piBuffers):.piBuffers=0
    if .pContext then alcDestroyContext( .pContext ): .pContext=0
    if .hWave then alcCloseDevice(.hWave): .hWave=0
  end with
  return 0

end function
function AudioWrite( pWave as WaveOutStruct ptr , pzBuff as any ptr , iSz as integer ) as integer
  if pWave=null orelse pWave->dwMagic <> cvl("WvOS") then return 0
  
  dim as any ptr pFreeBuffer 
  dim as ushort ptr pzFinalBuff = pzBuff
  dim as integer iFinalSz = iSz
  
  function = 0
  
  with *pWave  
    do      
      'Maybe convert sample to match target
      if iSz andalso (.iChan < 0 or .iChan=3) then 'Channel targets that need conversion
        pzFinalBuff = .pTempBuff
        if .iBits = 8 then '8->16 conversion plus rearrangement
          dim as ubyte ptr pInBuff = pzBuff
          iFinalSz = iSz*4*2
          if iFinalSz > 65536 then 'Pre-Allocated Temp buffer
            pFreeBuffer = allocate(iFinalSz)
            pzFinalBuff = pFreeBuffer
            if pzFinalBuff = 0 then return 0
          end if
          select case .iChan
          case -2 'Back Stereo
            for I as integer = 0 to iSz-1 step 2
              pzFinalBuff[I*2+0] = 0                   'Front Left
              pzFinalBuff[I*2+1] = 0                   'Front Right
              pzFinalBuff[I*2+2] = pInBuff[I+0] shl 8  'Back Left
              pzFinalBuff[I*2+3] = pInBuff[I+1] shl 8  'Back Right
            next I
          case -1 'Back Center
            for I as integer = 0 to iSz-1 step 1
              pzFinalBuff[I*4+0] = 0                   'Front Left
              pzFinalBuff[I*4+1] = 0                   'Front Right
              pzFinalBuff[I*4+2] = pInBuff[I] shl 8    'Back Left
              pzFinalBuff[I*4+3] = pInBuff[I] shl 8    'Back Right
            next I          
          case  3 'Front/Back Center
            for I as integer = 0 to iSz-1 step 2
              pzFinalBuff[I*2+0] = pInBuff[I+0] shl 8  'Front Left
              pzFinalBuff[I*2+1] = pInBuff[I+1] shl 8  'Front Right
              pzFinalBuff[I*2+2] = pInBuff[I+0] shl 8  'Back Left
              pzFinalBuff[I*2+3] = pInBuff[I+1] shl 8  'Back Right
            next I
          end select
        else 'just channel conversion then
          dim as ushort ptr pInBuff = pzBuff
          iFinalSz = (iSz\2)*4*2
          if iFinalSz > 65536 then 'Pre-Allocated Temp buffer
            pFreeBuffer = allocate(iFinalSz)
            pzFinalBuff = pFreeBuffer
            if pzFinalBuff = 0 then return 0
          end if
          select case .iChan
          case -2 'Back Stereo
            for I as integer = 0 to (iSz\2)-1 step 2
              pzFinalBuff[I*2+0] = 0                   'Front Left
              pzFinalBuff[I*2+1] = 0                   'Front Right
              pzFinalBuff[I*2+2] = pInBuff[I+0]        'Back Left
              pzFinalBuff[I*2+3] = pInBuff[I+1]        'Back Right
            next I
          case -1 'Back Center
            for I as integer = 0 to (iSz\2)-1 step 1
              pzFinalBuff[I*4+0] = 0                   'Front Left
              pzFinalBuff[I*4+1] = 0                   'Front Right
              pzFinalBuff[I*4+2] = pInBuff[I]          'Back Left
              pzFinalBuff[I*4+3] = pInBuff[I]          'Back Right
            next I          
          case  3 'Front/Back Center
            for I as integer = 0 to (iSz\2)-1 step 2
              pzFinalBuff[I*2+0] = pInBuff[I+0]        'Front Left
              pzFinalBuff[I*2+1] = pInBuff[I+1]        'Front Right
              pzFinalBuff[I*2+2] = pInBuff[I+0]        'Back Left
              pzFinalBuff[I*2+3] = pInBuff[I+1]        'Back Right
            next I
          end select
        end if
      end if      
      'possible wait for front buffer to finish
      do
        dim as aluint iBuffersDone
        alGetSourcei( .iSource , AL_BUFFERS_PROCESSED , @iBuffersDone)          
        if int_alGetError() then exit do      
        for N as integer = 0 to iBuffersDone-1
          alSourceUnqueueBuffers( .iSource , 1 , .piBuffers+.iOldBuffer )  
          if int_alGetError() then exit do
          .iOldBuffer = (.iOldBuffer+1) mod .iBuffers: .iBufferCount -= 1
        next N      
      loop while .iBufferCount = .iBuffers
      'if .iBufferCount = .iBuffers then return -1
      if iSz then        
        alBufferData( .piBuffers[.iCurBuf] , .iFmtOut , pzFinalBuff , iFinalSz , .iFrequency )
        if int_alGetError() then exit do        
        alSourceQueueBuffers( .iSource , 1 , .piBuffers+.iCurBuf )
        if int_alGetError() then exit do        
        .iCurBuf = (.iCurBuf+1) mod .iBuffers : .iBufferCount += 1    
        if .iBufferCount=1 then alSourcePlay( .iSource )
      end if
      function =(.iCurBuf+1)
      exit do      
    loop
  end with
  
  if pFreeBuffer then deallocate(pFreeBuffer):pFreeBuffer=0  
  
end function
sub AudioWaitBuffers( pWave as WaveOutStruct ptr)
  if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub
  with *pWave    
    do
      dim as aluint iBuffersDone
      alGetSourcei( .iSource , AL_BUFFERS_PROCESSED , @iBuffersDone)          
      if int_alGetError() then exit sub
      if iBuffersDone < .iBufferCount then sleep 1,1: continue do           
      for N as integer = 0 to iBuffersDone-1
        alSourceUnqueueBuffers( .iSource , 1 , .piBuffers+.iOldBuffer )  
        if int_alGetError() then exit do
        .iOldBuffer = (.iOldBuffer+1) mod .iBuffers: .iBufferCount -= 1
      next N      
      exit sub
    loop      
  end with
end sub
sub AudioClose( byref pWave as WaveOutStruct ptr )  
  if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub
  AudioWaitBuffers( pWave )
  with *pWave    
    if .piBuffers andalso .piBuffers[0] then alDeleteBuffers( .iBuffers , .piBuffers )
    if .iSource then alDeleteSources( 1 , @.iSource )    
    if .pTempBuff then deallocate(.pTempBuff):.pTempBuff=0
    if .piBuffers then deallocate(.piBuffers):.piBuffers=0
    if .pContext then alcDestroyContext( .pContext ): .pContext=0
    if .hWave then alcCloseDevice(.hWave): .hWave=0
    .iOldBuffer = 0: .iBufferCount = 0
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


