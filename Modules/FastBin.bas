enum FunctionName
  fnEof
  fnData  
  fnSync = 255
end enum

dim shared as ulong uDataChecksum=0

' ************************************************************************
' ************************ COCO fast byte generator **********************
' ************************************************************************
#define ClearCheckSum() uDataChecksum=0
#define WriteCheckSum() WriteBits(256-uDataChecksum)

sub WriteSamples(iSampleCount as long,iSample as long)  
  'if iSample = cMaxSam then print "1 "; else print "0 ";
  'if iSample = cMinSam then iSample = 0
  for iN as long = 1 to iSampleCount
    'if iSample > iLastSample then iLastSample += 16000
    'if iSample < iLastSample then iLastSample -= 16000
    'var iSam = iLastSample+(sin(PI2-((PI2*iN)/(iSampleCount)))*(iSample-iLastSample))
    pCurBuff[lBuffPos] = iSample '32000-iLastSample
    lBuffPos += 1
    if lBuffPos >= lBuffLen then SwapAudioBuffer()    
  next iN      
end sub
sub WriteSilence(fDuration as single)  
  for iN as long = 0 to cint(SoundFreq*fDuration)-1
    pCurBuff[lBuffPos] = SilenceSample
    lBuffPos += 1
    if lBuffPos >= lBuffLen then SwapAudioBuffer()
  next iN    
end sub
sub WriteBits(CHAR as ubyte)     
  uDataChecksum = (uDataChecksum+CHAR) and &hFF
  CHAR xor= &h1A
  
  static as long iMU
  static as long iWaveSum, iRepeat 'when to reset?
  dim as long iSample = any
  
  for N as long = 0 to 8    
    select case N
    case 8      
      iSample = iif(CHAR and 128,cMinSam,cMaxSam)      
    case else      
      iSample = iif(CHAR and (1 shl N),cMaxSam,cMinSam)      
    end select    
    
    while iWaveSum < SoundFreq*1000
      iWaveSum += cInitFreq: iRepeat = iRepeat+1      
    wend    
    WriteSamples(iRepeat,iSample)
    iWaveSum -= SoundFreq*1000: iRepeat = 0
  next N    
end sub
sub WriteCommand(bCmd as ubyte,wSize as ushort,wAddr as ushort)
  ClearCheckSum()
  WriteBits(bCmd)
  WriteBits((wSize shr 8) and &hFF)
  WriteBits((wSize shr 0) and &hFF)
  WriteBits((wAddr shr 8) and &hFF)
  WriteBits((wAddr shr 0) and &hFF)
  WriteCheckSum()
end sub
sub WriteSync(iLen as long = 4,iRep as long = 2)
  'dim as string sSync
  
  '"\84\169\255JJ\255JJ\255JJ\255JJJ\255JJJ\255JJJ\255JJJ\255JJJ\254"
  
  for N as long = 0 to iRep  
    WriteBits(85)
    WriteBits(170)
    for N as long = 0 to iLen\2
      WriteBits(0)
      WriteBits(asc("K"))
      WriteBits(asc("K"))
    next N
    for N as long = 0 to iLen
      WriteBits(0)
      WriteBits(asc("K"))
      WriteBits(asc("K"))
      WriteBits(asc("K"))
    next N  
  next N
  
  WriteBits(255)
  
end sub
sub WriteData( pData as ubyte ptr , iSize as long , iOffset as long )  
  WriteCommand(fnData,iSize,iOffset)
  for N as long = 0 to iSize-1
    WriteBits(pData[N])
  next N   
  WriteCheckSum()
end sub

sub FastUploadBIN( sFile as string , pBlocks as BinPartStruct ptr )
  
  dim as double StartTimer = any, TotTimer = timer
  dim as long iIndicator = asc("F") or 64
  
  'dim as long iFreq=cInitFreq,iDoQuit
  'dim as long uLastBit
  'dim as long iSync,iBitCnt,iAuto=0
  
  'modify loader code, to enable/disable double speed (0.895/1.79mhz)
  'pbLoader(_pSpeedA) = iif(iCfgDouble>1,&hD9,&h21)
  'pbLoader(_pSpeedB) = iif(iCfgDouble>1,&hD8,&h21)
  pbLoader(_pSpeedA) = iif(iCfgDouble>1,&hD9,&h03)
  pbLoader(_pSpeedB) = iif(iCfgDouble>1,&hD8,&h03)

  'send the fastloader program using normal casette signal
  vprint(vlMinimum,11) "Sending Loader (normal casette speed)"
  var sTitle = "LOADER  "
  if iCfgPack > 1 then sTitle[5] = asc("p")
  if iCfgDouble > 1 then sTitle[6] = asc("d")
  UploadBIN(sTitle,@pbLoader(0),ubound(pbLoader)-1)        
  vprint(vlMinimum,10) "Loader Sent..."
  vprint(vlMinimum,11) "Sending Binary..."        
  
  'open the soundcard (again) for sending fastload data
  'actually this will be ignored but it's here for consistency
  'SYNC data is sent to the device opened for the loader
  PlayBuff(psOpen):WriteSync()    
  
  'if status is enabled then send the initial bar
  'so it can be disabled in case one want to load
  'from inside a BASIC program.
  if iCfgStatus then
    var sIntro = GenIntroString( sFile , iIndicator )
    WriteData(strptr(sIntro),len(sIntro),1024)        
  end if
  
  'now send the blocks of code/data
  StartTimer = timer  
  
  dim as long iLastPosi = 0
  do
    
    'print "0x"+hex$(pBlocks)
    
    with *pBlocks
      
      DebugShowLine()      
      var iSize = .uSize, iOffs = .uAddr
      DebugShowLine()
      
      select case .uType 
      case bptData       'DATA block
        DebugShowLine()
        var pDataOut = cptr(ubyte ptr,pBlocks+1)
        dim iCompress as long = (.uFlags and bpfPacked), iBlkOff as long = 0        
        dim iSizeOut as long = iSize, iPosiOut as long = 0, iCycles as long = 0
        dim fRatio as single = 1
        
        ' Prepare for compression if enabled for this block...
        if iCompress then 
          'Block is compressed so modify decompressor code for source/target/size/last bytes
          iBlkOff = .tPack.uUnpackSz-iSize 'storing at end of uncompressed region
          fRatio = .tPack.fRatio : iCycles = .tPack.uCycles
          
          pbDecompress(_pExt01+0) = .tPack.EndBytes(0):pbDecompress(_pExt01+1) = .tPack.EndBytes(1)
          pbDecompress(_pExt23+0) = .tPack.EndBytes(2):pbDecompress(_pExt23+1) = .tPack.EndBytes(3)
          pbDecompress(_pExt4 +0) = .tPack.EndBytes(4) 'maximum 5 bytes required (could be 4? ;_;)
          pbDecompress(_PSource+0) = (iOffs+iBlkOff) shr 8 'source HI
          pbDecompress(_PSource+1) = (iOffs+iBlkOff)       'Source LO
          pbDecompress(_PTarget+0) = iOffs shr 8           'Target HI
          pbDecompress(_PTarget+1) = iOffs and &hFF        'Target LO
          
          if (.uFlags and bpfCompressorLoaded) then            
            'Compressor is loaded? so just update parts
            WriteData(@pbDecompress(_PSource),(_PTarget-_PSource)+2,DecompAddr+_PSource)
            WriteData(@pbDecompress(_pExt01),(_pExt4-_pExt01)+2,DecompAddr+_pExt01)
          else
            'not loaded? so set "jump/return" parameters and fully load it
            *cptr(ushort ptr,@pbDecompress(_pRestore01)) = LdrOrgA
            *cptr(ushort ptr,@pbDecompress(_pRestore23)) = LdrOrgB
            pbDecompress(_pResOff+0) = LdrAddr shr 8 'ResOff is also return addr...
            pbDecompress(_pResOff+1) = LdrAddr and &hFF
            WriteData(@pbDecompress(0),ubound(pbDecompress)+1,DecompAddr)          
          end if
        end if
        
        ' Upload block in smaller parts... (to detect error earlier?)
        while iSizeOut > 0
          var iCurPosi = clng(.uFileOff+iif(iCompress,iPosiOut*fRatio,iPosiOut))
          var iWriteSz = iif(iSizeOut>=iCfgPartSz,iCfgPartSz,iSizeOut)
          iSizeOut -= iWriteSz
          WriteCommand(fnData,iWriteSz,iOffs+iBlkOff)
          for N as long = 0 to iWriteSz-1
            WriteBits(pDataOut[iPosiOut]): iPosiOut += 1
          next N   
          WriteCheckSum() : iBlkOff += iWriteSz
          if iCfgStatus andalso (iPosiOut-iLastPosi) >= 1024 then
            iLastPosi += 1024
            var iCurPosiB = iCurPosi'-cBytesOnBuff
            if iCurPosiB < 1 then iCurPosiB = 1
            var iBYS = cint(iCurPosiB/(timer-StartTimer))
            if iBYS > 9999 then iBYS = 9999
            var iPct = (iCurPosi*100)\iBinFileSize
            if iPct > 100 then iPct = 100          
            var sTemp = iBYS & "/S " & right$("  " & iPct,3)
            var iSz = len(sTemp)
            WriteCommand(fnData,iSz,(1024+30)-iSz)          
            for N as long = 0 to iSz-1
              WriteBits(sTemp[N] or 64)
            next N
            WriteCheckSum()            
            iIndicator xor= 64
            WriteCommand(fnData,1,1024)          
            WriteBits(iIndicator):WriteChecksum()
          end if          
          
          if iCompress then
            'printf !"%i %i (packed %i%%)   \r",iCurPosi,iFSz,cint(100-(100/fCompMul))
            vprint(vlMinimum,7) iCurPosi & " " & iBinFileSize & " (packed " & cint(100-(100/fRatio)) & !"%)    \r";
          else          
            'printf !"%i %i \r",iCurPosi,iFSz
            vprint(vlMinimum,7) iCurPosi & " " & iBinFileSize & !" (unpacked)      \r";
          end if
          DebugShowLine()
        wend
        
        if iCompress then 'data was sent compressed to must decompress it
          DebugShowLine()
          static as ubyte pbRunUnpack(2) = {&h7E,DecompAddr shr 8,DecompAddr and &hFF}
          WriteData( @pbRunUnpack(0) , 3 , LdrAddr )
          WriteBits(fnSync): WriteBits(fnSync) 'force resync which will cause it to jump to unpack
          WriteSilence( ((iCycles+893)/894886)*2 + .05 )' 
          WriteSync()          
        end if
        DebugShowLine()
        
      case bptEof         'EOF  block
        DebugShowLine()
        vprint(vlMinimum,7) iBinFileSize & " " & iBinFileSize & !" (EOF)           \r";
        vprint(vlMinimum,11) !"\r\nExecute address: 0x" + hex$(iOffs,4)      
        WriteCommand(fnData,2,&h9D)
        WriteBits((iOffs shr 8) and &hFF) 'Execute Address HI
        WriteBits(iOffs and &hFF)         'Execute Address LO
        WriteCheckSum()        
      end select          
      pBlocks = .pNext
    end with
  loop while pBlocks
  
  'Show final status? (100% :D)
  var sTemp = "100%", iSz = len(sTemp)-1
  WriteData( strptr(sTemp) , iSz , (1024+30)-iSz )  
  WriteData( @!"\04\31" , 2 , &h88 )
  
  #if 0
  'Autoexec binary?
  if iExec <> -1 then
    dim as ubyte pbRunUnpack(...) = {&hD7,&hD8,&h7E,iExec shr 8,iExec and &hFF}
    WriteData( @pbRunUnpack(0) , ubound(pbRunUnpack)+1 , LdrAddr )
    WriteBits(fnSync): WriteBits(fnSync)
  end if
  #endif
  
  'last command to finish fast loader
  WriteCommand(fnEof,0,0)
  WriteSilence(0.5)
  PlayBuff(psClose)
  vprint(vlMinimum,10) !"Binary Sent in " & left$(str$((timer-TotTimer)+.00001),5) & " seconds."

end sub


  
  
