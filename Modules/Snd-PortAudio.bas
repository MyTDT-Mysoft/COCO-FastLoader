#include "..\inc\PortAudio19.bi"

type WaveOutStruct
  dwMagic as ulong  'cvl("WvOS")
  hWave as PortAudioStream ptr
  iBuffers as long  
  iCurBuf as long  
  iFrequency as long
  iBits as long
  iChan as long
  iChanCnt as long
  pTempBuff as any ptr
end type  

'--- Initialize here to avoid unecessary console output ---
color 0
Pa_Initialize()
cls: color 7

function AudioOpen( iHz as integer = 44100 , iBits as integer = 16, iChan as integer = 2, iBuffers as integer = 2, iDevice as integer=-1) as WaveOutStruct ptr
  
  #define IfError() if iErrChk <> paNoError then print "PortAudio Error: " & iErrChk & " at line " & __LINE__ & " ["+*Pa_GetErrorText(iErrChk)+"]":
  
  dim as long iChanCnt
  dim as WaveOutStruct ptr pResult
  dim as PaDeviceIndex iDeviceID = -99
  dim as paError iErrChk
  
  if iDevice = -1 then
    iDeviceID = Pa_GetDefaultOutputDevice()
  else
    var iNum = 0
    for N as PaDeviceIndex = 0 to Pa_GetDeviceCount()-1
      var pTemp = Pa_GetDeviceInfo( N )
      if pTemp andalso pTemp->maxOutputChannels then
        if iDevice=iNum then iDeviceID = N: exit for
        iNum += 1
      end if
    next N
    if iDeviceID = -99 then print "PortAudio: device " & iDevice & " not found":return 0
  end if
    
  do

    select case iChan
    case -2  : iChanCnt = 4
    case -1  : iChanCnt = 4
    case  1  : iChanCnt = 1
    case  2  : iChanCnt = 2
    case  3  : iChanCnt = 4
    case  4  : iChanCnt = 4
    case else: return 0
    end select
        
    if iBits <> 8 and iBits <> 16 then print "PortAudio: invalid bitsize " & iBits:return 0
    if cuint(iBuffers-1) > 255 then print "PortAudio: invalid buffer count" & iBuffers: return 0
    pResult = cptr( WaveOutStruct ptr , callocate(sizeof(WaveOutStruct)) )
    if pResult = 0 then print "PortAudio: failed to allocate WaveOut structure": return 0
    
    with *pResult
      dim as PaSampleFormat iFmt = iif(.iBits=8,paUInt8,paInt16)
      dim as PaStreamParameters tParms = type(iDeviceID,iChanCnt,iFmt,1/10,0)
      iErrChk = Pa_OpenStream(@.hWave,0,@tParms,iHz,0,paClipOff,0,0)
      IfError() exit do      
      .pTempBuff = callocate( 65536 )    
      if .pTempBuff = 0 then print "PortAudio: failed to allocate auxiliar buffer space": exit do      
      .dwMagic = cvl("WvOS") 
      .iChanCnt = iChanCnt
      .iFrequency = iHZ : .iBits = iBits: .iChan = iChan
      .iBuffers = iBuffers : .iCurBuf = -1
    end with
    
    return pResult
  loop
  
  'Error Happened
  with *pResult    
    if .pTempBuff then deallocate(.pTempBuff):.pTempBuff=0
    if .hWave then Pa_CloseStream(.hWave): .hWave=0
    deallocate(pResult): pResult = 0
  end with
  return 0

end function
function AudioWrite( pWave as WaveOutStruct ptr , pzBuff as any ptr , iSz as integer ) as integer
  
  #define IfError() if iErrChk <> paNoError then print "PortAudio Error: " & iErrChk & " at line " & __LINE__ & " ["+*Pa_GetErrorText(iErrChk)+"]":
  
  if pWave=null orelse pWave->dwMagic <> cvl("WvOS") then 
    print "OpenAL AudioWrite: bad handle": return 0
  end if
  
  dim as any ptr pFreeBuffer 
  dim as any ptr pzFinalBuff = pzBuff
  dim as integer iFinalSz = iSz
  dim as paError iErrChk
  
  function = 0
  
  with *pWave  
    do      
      'Maybe convert sample to match target
      if iSz andalso (.iChan < 0 or .iChan=3) then 'Channel targets that need conversion
        pzFinalBuff = .pTempBuff
        if .iBits = 8 then '8->16 conversion plus rearrangement
          dim as ubyte ptr pInBuff = pzBuff, pzOutBuff = pzBuff
          iFinalSz = iSz*4*1
          if iFinalSz > 65536 then 'Pre-Allocated Temp buffer
            pFreeBuffer = allocate(iFinalSz)
            pzOutBuff = pFreeBuffer: pzFinalBuff = pFreeBuffer
            if pzFinalBuff = 0 then print "PortAudio: failed to generate source": return 0
          end if
          select case .iChan
          case -2 'Back Stereo
            for I as integer = 0 to iSz-1 step 2
              pzOutBuff[I*2+0] = 0                   'Front Left
              pzOutBuff[I*2+1] = 0                   'Front Right
              pzOutBuff[I*2+2] = pInBuff[I+0]        'Back Left
              pzOutBuff[I*2+3] = pInBuff[I+1]        'Back Right
            next I
          case -1 'Back Center
            for I as integer = 0 to iSz-1 step 1
              pzOutBuff[I*4+0] = 0                   'Front Left
              pzOutBuff[I*4+1] = 0                   'Front Right
              pzOutBuff[I*4+2] = pInBuff[I]          'Back Left
              pzOutBuff[I*4+3] = pInBuff[I]          'Back Right
            next I          
          case  3 'Front/Back Center
            for I as integer = 0 to iSz-1 step 2
              pzOutBuff[I*2+0] = pInBuff[I+0]        'Front Left
              pzOutBuff[I*2+1] = pInBuff[I+1]        'Front Right
              pzOutBuff[I*2+2] = pInBuff[I+0]        'Back Left
              pzOutBuff[I*2+3] = pInBuff[I+1]        'Back Right
            next I
          end select
        else 'just channel conversion then
          dim as ushort ptr pInBuff = pzBuff, pzOutBuff = pzBuff
          iFinalSz = (iSz\2)*4*2
          if iFinalSz > 65536 then 'Pre-Allocated Temp buffer
            pFreeBuffer = allocate(iFinalSz)
            pzOutBuff = pFreeBuffer: pzFinalBuff = pFreeBuffer
            if pzFinalBuff = 0 then print "PortAudio: failed to generate source": return 0
          end if
          select case .iChan
          case -2 'Back Stereo
            for I as integer = 0 to (iSz\2)-1 step 2
              pzOutBuff[I*2+0] = 0                   'Front Left
              pzOutBuff[I*2+1] = 0                   'Front Right
              pzOutBuff[I*2+2] = pInBuff[I+0]        'Back Left
              pzOutBuff[I*2+3] = pInBuff[I+1]        'Back Right
            next I
          case -1 'Back Center
            for I as integer = 0 to (iSz\2)-1 step 1
              pzOutBuff[I*4+0] = 0                   'Front Left
              pzOutBuff[I*4+1] = 0                   'Front Right
              pzOutBuff[I*4+2] = pInBuff[I]          'Back Left
              pzOutBuff[I*4+3] = pInBuff[I]          'Back Right
            next I          
          case  3 'Front/Back Center
            for I as integer = 0 to (iSz\2)-1 step 2
              pzOutBuff[I*2+0] = pInBuff[I+0]        'Front Left
              pzOutBuff[I*2+1] = pInBuff[I+1]        'Front Right
              pzOutBuff[I*2+2] = pInBuff[I+0]        'Back Left
              pzOutBuff[I*2+3] = pInBuff[I+1]        'Back Right
            next I
          end select
        end if
      end if            
      if iSz then
        if .iCurBuf = -1 then
          iErrChk = Pa_StartStream( .hWave )
          IfError() exit do
          .iCurBuf = 0
        end if        
        'print .iChanCnt , .iBits
        iErrChk = Pa_WriteStream( .hWave , pzFinalBuff , iFinalSz\(.iChanCnt*(.iBits shr 3)) )
        IfError() exit do
        .iCurBuf = (.iCurBuf+1) mod .iBuffers
      end if
      function =(.iCurBuf+1)
      exit do      
    loop
  end with
  
  if pFreeBuffer then deallocate(pFreeBuffer):pFreeBuffer=0  
  
end function
sub AudioWaitBuffers( pWave as WaveOutStruct ptr)
  if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub
  exit sub
end sub
sub AudioClose( byref pWave as WaveOutStruct ptr )  
  if pWave=0 orelse pWave->dwMagic <> cvl("WvOS") then exit sub  
  with *pWave        
    if .pTempBuff then deallocate(.pTempBuff):.pTempBuff=0    
    if .hWave then 
      Pa_StopStream(.hWave)
      Pa_CloseStream(.hWave): .hWave=0
    end if
    .iChanCnt = 0: .dwMagic = 0: .iBuffers = 0
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


