' ************************************************************************
' ************************* COCO cassette generator **********************
' ************************************************************************

#define cCasDouble iCfgDouble

type WaveFileBlock field=1
  pzName as zstring*8
  bType  as ubyte
  bAscii as ubyte
  bGap   as ubyte  
  wExec  as ushort
  wAddr  as ushort
end type
enum WaveBlockType
  wbtName = &h00
  wbtData = &h01
  wbtEOF  = &hFF
end enum
enum WaveFileType
  wftBasic  = &h00
  wftData   = &h01
  wftBinary = &h02
end enum
enum WaveFileEncoding
  wfeBinary = &h00
  wfeAscii  = &hFF
end enum
enum WaveFileMulti
  wfmFalse  = &h00
  wfmTrue   = &hFF
end enum

sub CAS_WriteBits(CHAR as ubyte)  
  dim as integer Wave1200 = ((SoundFreq+(1200\2))\1200)*cCasDouble
  for iBits as long = 0 to 7    
    for iN as long = 0 to Wave1200-1 step (1+((CHAR shr iBits) and 1))
      pCurBuff[lBuffPos] = ((iN<(Wave1200 shr 1)) or 1)*32767 'FRQ(iN)
      lBuffPos = lBuffPos+1
      if lBuffPos >= lBuffLen then SwapAudioBuffer()      
    next iN
  next iBits
end sub
sub CAS_WriteLeader()
  const LeaderLen = 128
  for iN as long = 1 to LeaderLen
    CAS_WriteBits(&h55)
  next iN
end sub
sub CAS_WriteBlock( iType as WaveBlockType , iSize as long = 0 , pData as ubyte ptr = 0, iTotal as long = -1 )  
  'Magic IN
  CAS_WriteBits(&h55) 
  CAS_WriteBits(&h3C)
  'Type
  CAS_WriteBits(iType)
  CAS_WriteBits(iSize)
  'Data
  var iSum = iType+iSize
  if pData then
    for iN as long = 0 to iSize-1
      CAS_WriteBits( pData[iN] )
      iSum += pData[iN]      
    next iN
  end if
  'CheckSum
  CAS_WriteBits( iSum )
  'Magic Out
  CAS_WriteBits(&h55)
end sub

sub UploadBIN(SNAME8 as string, pBin as ubyte ptr, iFileSz as long)
  
  const fDelay = 0.33
  
  dim as long BTOT,TOTB
  dim as long UPFILE,COUNT
  dim as zstring*9 FNAME = ucase$(left$(SNAME8+"        ",8))
  dim as ubyte FTYP,BSUM,CHAR
  dim as ushort MCLA,MCSA,OFFS
  dim as long LNT,BLNT,FSIZE
    
  dim as long iPos = 0, iTotal = 0,iParts=0
  dim as long wExec=-1, wAddr=-1, wMayExec=-1  
  if cuint(iFileSz-5) > 65530 then exit sub  
  
  DebugShowLine()
  
  while iPos <= iFileSz-sizeof(BlockHdr)
    with *cptr(BlockHdr ptr,pBin+iPos)
      iPos += sizeof(BlockHdr)
      var WSize = wSwap(.WSize), WOffs = wSwap(.wOffs) 
      if .bID then 'FF
        .bID = &hFF
        if wExec = -1 and .wOffs=0 and wMayExec <> -1 then 
          .wOffs = wMayExec: WOffs = wSwap(.wOffs)
        end if        
        if wExec <> -1 then exit while
        wExec = .wOffs
      else
        .bID = &h00
        if WSize then          
          iParts += 1: wAddr = .wOffs: iTotal += WSize
          if wMayExec=-1 then wMayExec = .wOffs
        end if
      end if
      iPos += WSize
    end with    
  wend
  
  DebugShowLine()
  
  if iParts > 1 then iTotal += iParts*5
    
  'Open OUTPUT
  PlayBuff(psOpen)
  
  DebugShowLine()
  
  'Send SYNC header
  CAS_WriteLeader()
  
  DebugShowLine()
  
  if iParts > 1 then wExec=&hFFFF:wAddr=&hFFFF
  dim tFile as WaveFileBlock = type(FNAME,wftBinary,wfeBinary,(iParts>1) and wfmTrue,wExec,wAddr)
  CAS_WriteBlock( wbtName , sizeof(tFile) , cast(ubyte ptr, @tFile) )
  
  DebugShowLine()
  iPos = 0  
  
  if iParts > 1 then  
    DebugShowLine()
    var iStart = 0, iSize = 0, iTotal = iFileSz
    while iPos < iFileSz
      with *cptr(BlockHdr ptr,pBin+iPos)
        var WSize = wSwap(.WSize)
        iSize += WSize+sizeof(BlockHdr)
        if iSize >= 255 then                    
          while iSize > 255
            WriteSilence(fDelay*cCasDouble) : CAS_WriteLeader()            
            var WNext = iif(iSize > 255, 255, iSize)            
            CAS_WriteBlock( wbtData , WNext , pBin+iStart , iTotal )
            iStart += WNext: iSize -= WNext: iTotal -= WNext
          wend                    
        end if
        
        if .bID andalso iSize then                    
          WriteSilence(fDelay*cCasDouble) : CAS_WriteLeader()
          CAS_WriteBlock( wbtData , iSize , pBin+iStart, iTotal )          
          iTotal -= iSize
        end if
        
        iPos += sizeof(BlockHdr)+WSize
        if .bID then exit while

      end with
    wend
    
    WriteSilence(fDelay*cCasDouble) : CAS_WriteLeader()
    CAS_WriteBlock( wbtEOF )    
    
  else  
    DebugShowLine()
    WriteSilence(fDelay*cCasDouble) : CAS_WriteLeader()    
    while iPos <= iFileSz-sizeof(BlockHdr)      
      with *cptr(BlockHdr ptr,pBin+iPos)
        
        var WSize = wSwap(.WSize), WOffs = wSwap(.WOffs)              
        iPos += sizeof(BlockHdr)
        
        if .bID then 'FF
          CAS_WriteBlock( wbtEOF ): exit while
        else       
          while WSize
            var WNext = iif(WSize > 255, 255, WSize)          
            CAS_WriteBlock( wbtData , WNext , pBin+iPos, iTotal )
            iTotal -= WNext: WSize -= WNext: iPos += WNext
          wend        
        end if
        iPos += WSize
        
      end with    
    wend
  
  end if
  
  DebugShowLine()
  
  WriteSilence(fDelay*cCasDouble/10)
  'CAS_PlayBuff( psClose )
  
end sub
