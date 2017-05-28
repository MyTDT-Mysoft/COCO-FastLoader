' =============================================================================
' =============================================================================

const WndLen = 65535, WndSpc = 255  
const MaxBlock = 63, AlgoBits = 2
const EndBytes = 5

type WindowStruct
  as long uOff(WndSpc) 
  as long iCur, iCount
end type
enum AlgoID
  aiRaw      = 0
  aiRLE      = 1
  aiWindow   = 2
  aiWindow2  = 3  
end enum

static shared tWinSearch(255) as WindowStruct

function RLX_FindLargestWindowSize(pFile as ubyte ptr, uCurOff as long, uFileSize as long, byref iOffset as long) as long  
  dim as long iResuL,iResuH,iOffL,iOffH
  with tWinSearch( pFile[uCurOff] )    
    var iCnt = 0, pCur = pFile+uCurOff
    var iMax = iif( uCurOff+MaxBlock > uFileSize , uFileSize-uCurOff , MaxBlock )
    for N as long = 0 to .iCount-1
      var pPrev = pFile+.uOff((.iCur-N) and MaxBlock)      
      var iDist = cint(pCur)-cint(pPrev)
      if iDist > WndLen then exit for
      for iCnt = 1 to iMax      
        if pPrev[iCnt] <> pCur[iCnt] then exit for        
      next iCnt      
      #ifdef Enable2ByteWindow
        if iCnt < 256 then        
          if iCnt > iResuL then iOffL = iDist: iResuL = iCnt      
        else
          if iCnt > iResuH then iOffH = iDist: iResuH = iCnt      
        end if      
      #else
        if iCnt > iResuL then iOffL = iDist: iResuL = iCnt      
      #endif
    next N  
    if (iResuL+(iResuL shr 6)) > iResuH then      
      iOffset = iOffL: return iResuL-1
    else      
      iOffset = iOffH: return iResuH-1
    end if    
  end with
end function
function RLX_FindLargestRepeat(pFile as ubyte ptr, uCurOff as long, uFileSize as long) as long
  dim as long iMax=any,iResu=any
  iMax = iif( uCurOff+MaxBlock > uFileSize , uFileSize-uCurOff , MaxBlock )
  var pCur = pFile+uCurOff,iVal = pCur[0]
  for iResu = 1 to iMax
    if pCur[iResu] <> iVal then exit for
  next iResu  
  return iResu-1
end function
function RlxCompress( pIN as ubyte ptr , iSize as long , pOUT as ubyte ptr , byref iCycles as long = 0) as long  
  
  dim as long iMode,iSz,iChkSz,iRaw
  dim as long iWndOff,iSeqAdd,uRawOff
  dim as long uCurOff=0,iOffOut=0
  
  memset(@tWinSearch(0),0,sizeof(WindowStruct)*256)  
  iCycles=28
  
  #define EmitByte(_N) pOUT[iOffOut] = _N: iOffOut += 1
  #define EmitHeader() pOUT[iOffOut] = (iSz shl AlgoBits)+iMode: iOffOut += 1
  #macro EmitRaw()
    if iRaw then     
      while iRaw > MaxBlock
        var iTmpSz = iif(iRaw > (255+(MaxBlock+1)),255+(MaxBlock+1),iRaw)        
        var iParm = iTmpSz-(MaxBlock+1)
        pOUT[iOffOut] = (0 shl AlgoBits): iOffOut += 1
        pOUT[iOffOut] = iParm: iOffOut += 1      
        memcpy(pOUT+iOffOut,pIN+uRawOff,iTmpSz)
        iOffOut += iTmpSz: uRawOff += iTmpSz: iRaw -= iTmpSz
        iCycles += 18+679+8+(21*(iParm shr 1))+iif(iParm and 1,14,0)            
      wend
      while iRaw
        var iTmpSz = iif(iRaw > MaxBlock, MaxBlock, iRaw)
        pOUT[iOffOut] = (iTmpSz shl AlgoBits): iOffOut += 1
        memcpy(pOUT+iOffOut,pIN+uRawOff,iTmpSz): iOffOut += iTmpSz
        iRaw -= iTmpSz: iCycles += 14
        if iRaw > 1 andalso (iTmpSz and 1)=0 then iCycles += (8+14+((iTmpSz-2) shr 1)*21)
        if iRaw > 1 andalso (iTmpSz and 1)   then iCycles += (8+((iTmpSz-1) shr 1)*21)
      wend
    end if
  #endmacro

  while uCurOff < iSize and iOffOut < iSize
    iSz = RLX_FindLargestRepeat(pIN, uCurOff, iSize): iMode=1
    if iSz < MaxBlock then
      iChkSz = RLX_FindLargestWindowSize(pIN, uCurOff, iSize, iWndOff)
      if iChkSz > iSz then 
        iSz = iChkSz: iMode = 2        
        if iWndOff > 255 then iMode = 3                
      end if      
    end if  
    
    if iMode then 'decide if algorith wins over raw
      var iEmit = 0  
      select case iMode
      case aiRle    : iEmit = 2
      case aiWindow : iEmit = 2
      case aiWindow2: iEmit = 3
      end select
      if iRaw then iEmit -= (iSz) else iEmit -= (iSz+1)
      if iRaw=63 then iEmit += 1
      if iEmit>=0 then iMode=0: iSz=1
    end if
      
    select case iMode
    case aiRaw 
      iRaw += 1: if iRaw=1 then uRawOff = uCurOff    
    case aiRLE     
      EmitRaw()    
      EmitHeader()
      EmitByte( pIN[uCurOff] )      
      iCycles += (8+((iSz and 1)*8)+11+(13*(iSz shr 1)))
    case aiWindow 
      EmitRaw()    
      EmitHeader()        
      EmitByte( -iWndOff )                
      iCycles += (13+8+((iSz and 1)*14)+(21*(iSz shr 1)))
    case aiWindow2
      EmitRaw()    
      EmitHeader()      
      EmitByte( (-iWndOff) )
      EmitByte( ((-iWndOff) shr 8) )      
      iCycles += (24+8+((iSz and 1)*14)+(21*(iSz shr 1)))
    end select
    
    'AdvanceBytes( iSz )  
    for N as long = 0 to iSz-1
    with tWinSearch(pIN[uCurOff])
      if .iCount < WndSpc then .iCount += 1
      .iCur = (.iCur+1) and MaxBlock
      .uOff(.iCur) = uCurOff
    end with
    uCurOff += 1
  next N
  wend
  EmitRaw()
  EmitByte(aiRLE) 'EOF
  iCycles += 3+48
  
  return iOffOut
  
end function

