#ifdef sndforce_mmsystem
  #ifndef SndOk
    #define SndOk
    #include once "Modules\Snd-w32-mmsystem.bas"
    #print " Compiling with 'mmsystem' sound library (forced)"
  #endif
#endif
#ifdef sndforce_libao
  #ifndef SndOk
    #define SndOk
    #include "Modules\Snd-LibAO.bas"
    #print " Compiling with 'LibAO' sound library (forced)"
  #endif
#endif
#ifdef sndforce_openal
  #ifndef SndOk
    #define SndOk
    #include "Modules\Snd-OpenAL.bas"    
    #print " Compiling with 'OpenAL' sound library (forced)"
  #endif
#endif  

#ifndef SndOk
  #ifdef __FB_WIN32__  
    #include "Modules\Snd-w32-mmsystem.bas"
    '#print " Compiling with 'mmsystem' sound library"
  #else  
    #include "Modules\Snd-OpenAL.bas"
    '#print " Compiling with 'OpenAL' sound library"
  #endif
#endif

const cInitFreq=14700000, SilenceSample = 0
const cMaxSam=32767,cMinSam=-32767

enum PlayState
  psOpen  
  psFlush
  psClose
end enum

dim shared pDumpWav as WavFileStruct ptr
dim shared pWaveOut as WaveOutStruct ptr
dim shared as sample ptr pCurBuff
dim shared as ulong lBuffPos,lBuffLen
dim shared as long SoundFreq = (cInitFreq*3)\1000
'(cInitFreq*(4-iCfgDouble)*1)\1000
'(cInitFreq*3)\1000

dim shared as long iOpened

sub SwapAudioBuffer()
  if lBuffPos then
    if iCfgFileDump andalso pDumpWav then
      WaveFileWrite(pDumpWav,pCurBuff,lBuffPos*sizeof(sample))
    end if
    if iCfgDoPlay then      
      do
        var iResu = AudioWrite( pWaveOut , pCurBuff , lBuffPos*sizeof(sample) )
        if iResu < 0 then sleep 1,1: continue do
        if iResu > 0 then exit do
        puts("error writing samples..")
        sleep: system        
      loop         
    end if
    lBuffPos = 0    
  end if
end sub

' *****************************************************************************
' ***************** Playing Cassete BUffer generated and swap *****************
' *****************************************************************************
function PlayBuff(iState as long) as long
  
  const cBuffSz=1024,WaveBitSz=2,WaveBlockSz=WaveBitSz*cBuffSz*9
  
  DebugShowLine()
  select case iState
  case psFlush
    if pWaveOut=0 then return 0
    SwapAudioBuffer()
    return 1    
  case psOpen
    if pWaveOut then return 1
    
    pCurBuff = Allocate(WaveBlockSz)    
    if pCurBuff = 0 then
      puts "Failed to allocate buffers..."      
      return 0
    end if
    
    DebugShowLine()
    
    if iCfgFileDump then pDumpWav = WaveFileCreate(sInputFile+".wav",SoundFreq*iCfgDouble, sizeof(sample)*8,1)
    
    if iCfgDoPlay then
      DebugShowLine()
      pWaveOut = AudioOpen( SoundFreq*iCfgDouble , sizeof(sample)*8, iCfgOutputSpeakers, 2, iCfgAudioDevice) '-1 channels so they are mono/back
      DebugShowLine()
      if pWaveOut = 0 then 
        puts "Failed to initialize sound..."
        return 0
      end if   
    else
      pWaveOut = cast(any ptr,@iCfgDoPlay)
    end if
    
    DebugShowLine()
    
    lBuffPos = 0: iOpened=1
    lBuffLen = WaveBlockSz\sizeof(sample)    
    
  case psClose
    if iCfgFileDump andalso pDumpWav then
      WaveFileClose(pDumpWav): pDumpWav=0
    end if
    if pWaveOut=0 then return 1
    DebugShowLine()
    SwapAudioBuffer()    
    DebugShowLine()
    if iCfgDoPlay then AudioClose( pWaveOut )
    DebugShowLine()
    deallocate( pCurBuff )    
    DebugShowLine()
    pCurBuff = null: lBuffPos = 0    
    pWaveOut=0:iOpened=0    
  end select    
  
  return 1

end function

