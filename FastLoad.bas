#define fbc -gen gcc -O 3 -asm intel
'-x F:\FB15\Projetos\Emulators\CP-400\Roms\FastLoad.exe

#include "crt.bi"

'#define DebugShowLine() print __FILE__ & " - " & __FUNCTION__ & " - " & __LINE__
#define DebugShowLine() rem

#define vprint(_N,_C) if iCfgVerbose >= (_N) then color (_C): print
#define vlevel(_N) (iCfgVerbose >= (_N))
#define ErrorExit(_N) color 7:sleep: system (_N)

#ifdef __FB_WIN32__
  #include once "windows.bi"
  #if __FB_DEBUG__ <> 0    
    #include "MyTDT\Exceptions.bas"
    StartExceptions()
  #endif
#endif

type sample as short

'------------------------
enum Verbosity
  vlQuiet = 0
  vlErrors
  vlMinimum
  vlMaximum
end enum

dim shared as long iCfgStatus = -1, iFreqMult=3, iCfgDouble=1, iCfgAutorun=0
dim shared as long iCfgFileDump=0, iCfgPack=-1, iCfgDoPlay, iCfgPartSz = 1024
dim shared as long iCfgVerbose = vlMaximum, iCfgAudioDevice=-1, iCfgInteractive=-1
dim shared as long iCfgOutputSpeakers = 1

'iCfgDouble=2:iCfgPack=1:iCfgOutputSpeakers=-1

dim shared as string sInputFile
dim shared as long iBinFileSize, iConWid, iConHei, iOptLine
static shared as ubyte pbPacked(65536*2)

declare sub UploadBIN(SNAME8 as string, pBin as ubyte ptr, iFileSz as long)

#include "Modules/Roms.bas"
#include "Modules/Functions.bas"
#include "Modules/WavFile.bas"
#include "Modules/Audio.bas"
#include "Modules/Status.bas"
#include "Modules/Compress.bas"
#include "Modules/Evaluate.bas"
#include "Modules/FastBin.bas"
#include "Modules/LoadBin.bas"

'Getting console size... for some (and future) improvements
iConWid = width() and &hFFFF
iConHei = (width() shr 16) and &hFFFF

dim as BinPartStruct ptr pBlocks
SoundFreq = (cInitFreq*iFreqMult)\1000

sInputFile = trim$(command$)
if ParseParameters( sInputFile ) = 0 then system

do 'restart for interactive mode
  if iCfgInteractive then color 7,0: cls
  pBlocks = GetFileParts(sInputFile, iBinFileSize)
  vprint(vlMaximum,7) string$(iConWid,"-")
  if iCfgInteractive = 0 then exit do
  
  print !"\r\n\r\n\r\n";
  iOptLine = csrlin()-3  
  
  while iCfgInteractive    
    select case InteractiveMenu()
    case -1
      deallocate(pBlocks):pBlocks=0
      continue do
    case  1: exit do
    end select
  wend
loop

#ifdef SetPriorityClass
SetPriorityClass(GetCurrentProcess,REALTIME_PRIORITY_CLASS)
#endif
#ifdef SetThreadPriority
SetThreadPriority(GetCurrentThread,THREAD_PRIORITY_TIME_CRITICAL)
#endif

color 7
FastUploadBIN(sInputFile, pBlocks)

if iCfgInteractive then
  if iCfgVerbose < vlMinimum then color 10:print !"\r\nDone.";
  while len(inkey$): wend
  sleep
end if
color 7
