
type BlockHdr field=1
  bID   as ubyte
  wSize as ushort
  wOffs as ushort
end type

type PackedPartStruct
  fRatio      as single
  uCycles     as long
  uUnpackSz   as long
  EndBytes(7) as ubyte
end type

enum BinPartType
  bptData = 0
  bptEof = 255
end enum
enum BinPartFlags
  bpfPacked = 1
  bpfCompressorLoaded = 2
  bpfMerged = 4
end enum  

type BinPartStruct
  pNext  as BinPartStruct ptr
  uType    : 8 as ulong
  uFlags   : 4 as ulong  
  uFileOff :20 as ulong
  uSize    :16 as ulong
  uAddr    :16 as ulong  
  tPack     as PackedPartStruct
  uMerges  :16 as ulong
  uPad     :16 as ulong
end type

function GetFileParts( sFile as string , byref iFileSize as long = -1) as BinPartStruct ptr
  var f = freefile() 
  vprint(vlMaximum,15) "Filename: '"+sFile+"'"
  
  'Trying to open filename...
  if open(sFile for binary access read as #f) then
    vprint(vlErrors,12) !"\r\nError: Failed to open '"+sFile+"'"
    ErrorExit(1)
  end if
  var iFSz = clng(lof(f))
  if iFSz < sizeof(BlockHdr) or iFSz >= 1024*1024 then
    vprint(vlErrors,12) !"\r\nError: Bad File size"
    ErrorExit(1)
  end if
  
  'Allocating block for file and reading
  var pData = cptr(ubyte ptr,allocate(iFSz)), iPosi = 0
  var pParts = cptr(BinPartStruct ptr,callocate(iFSz*2))
  if pData = 0 orelse pParts = 0 then
    close #f
    if pData then deallocate(pData):pData=0
    if pParts then deallocate(pParts):pParts=0
    vprint(vlErrors,12) !"\r\nError: Failed to allocate memory for binary."
  end if
  get #f,1,*cptr(ubyte ptr,pData), iFSz
  close #f
  
  'Processing blocks (validate and check for compression)
  vPrint(vlMaximum,10) !"\r\nType SizeD AddrH Info"
  
  dim as BinPartStruct DummyPart 
  dim as BinPartStruct ptr pCurPart = @DummyPart, pNewPart = pParts  
  dim as long iCompressorLoaded=0, iMayExec = -1
  do
    
    'accessing after buffer protection
    if (iPosi+sizeof(BlockHdr)) > iFSz then
      vprint(vlErrors,14) !"\r\nWarning: Premature end of file (bad file? cropped?)"
      
      'add an EOF block if there isnt one
      if iMayExec <> -1 then
        if pNewPart then 
          pCurPart->pNext = pNewPart: pCurPart = pNewPart: pNewPart = 0
          memset(pCurPart, 0, sizeof(BinPartStruct) )
        end if
        pCurPart->uFileOff = iPosi: pCurPart->uType = bptEof
        pCurPart->uSize = 0 : pCurPart->uAddr = iMayExec
      end if
      
      exit do
    end if  
    
    'validate block
    var pBlock = cast(BlockHdr ptr,pData+iPosi)
    dim as ulong uSize = 0, uAddr = wSwap(pBlock->wOffs)      
    dim as ulong uTotalSize=0,iMerges=0,uMergeOff=0
    
    do      
      'header is BIG endian... so swap and advance position to after header
      uSize = wSwap(pBlock->wSize): uTotalSize += uSize      
      iPosi += sizeof(BlockHdr)
      
      if pBlock->bID then 'this block is EOF
        
        vprint(vlMaximum,7) "EOF  "+sRPad(str(uSize),5)+" "+hex$(uAddr,4)
        if iPosi < iFSz then vprint(vlErrors,14) "Warning: EOF found but not at end of file..."
        'add to block array
        if pNewPart then 
          pCurPart->pNext = pNewPart: pCurPart = pNewPart: pNewPart = 0
          memset(pCurPart, 0, sizeof(BinPartStruct) )
        end if
        pCurPart->uFileOff = iPosi: pCurPart->uType = bptEof
        pCurPart->uSize = 0 : pCurPart->uAddr = uAddr        
        exit do,do 'this is always last block...
        
      else         'this block is DATA
        
        ' it's a bad block... bad file?        
        if (iPosi+uSize) > iFSz then
          vprint(vlMaximum,7) "Data "+sRPad(str(uTotalSize),5)+" "+hex$(uAddr,4)
          vprint(vlErrors,12) !"\r\nError: data size extends beyond file (corrupted file?)"
          exit do,do
        end if
        
        ' there's a sequential block?
        if (iPosi+sizeof(BlockHdr)) <= iFSz then
          var pTemp = cast(BlockHdr ptr,pData+iPosi+uSize)
          var uTempAddr = wSwap(pTemp->wOffs)
          if pTemp->bID = pBlock->bID andalso uTempAddr=(uAddr+uTotalSize) then
            if iMerges=0 then 'will be storing merges on output block for later compression
              if pNewPart then 
                pCurPart->pNext = pNewPart: pCurPart = pNewPart: pNewPart = 0
                memset(pCurPart, 0, sizeof(BinPartStruct) )
              end if
              pCurPart->uFileOff = iPosi
            end if
            memcpy( cast(any ptr,pCurPart+1)+uMergeOff , pData+iPosi , uSize )
            uMergeOff += uSize: iPosi += uSize
            pBlock = cast(BlockHdr ptr,pData+iPosi)
            iMerges += 1: continue do
          end if
        end if
        
        'add to block array
        if pNewPart then 
          pCurPart->pNext = pNewPart: pCurPart = pNewPart: pNewPart = 0
          memset(pCurPart, 0, sizeof(BinPartStruct) )
          pCurPart->uFileOff = iPosi
        end if                
        if iMayExec = -1 then iMayExec = uAddr
        pCurPart->uType = bptData: pCurPart->uFlags=0
        pCurPart->uSize = uTotalSize : pCurPart->uAddr = uAddr
        memcpy( cast(any ptr,pCurPart+1)+uMergeOff , pData+iPosi , uSize )     

        'trying to compress
        if iCfgPack andalso uTotalSize > 127 then 
          dim iCycles as long = any
          var dTime = timer
          var iPackSz = RlxCompress( cast(any ptr,pCurPart+1) , uTotalSize-EndBytes , @pbPacked(0) , iCycles )        
          var iBytes = cint((iCycles/894886)*1550)
          'if iCompressorLoaded=0 then iBytes += ubound(pbDecompress)+1 
          var fPct = (uTotalSize)/(iPackSz+iBytes)
          if fPct > 1.05 then 'Worth compression
            with *pCurPart
              .uFlags or= bpfPacked or iCompressorLoaded
              .uSize = iPackSz: .tPack.fRatio = fPct
              .tPack.uCycles = iCycles: .tPack.uUnpackSz = uTotalSize              
              memcpy( @.tPack.EndBytes(0) , cast(any ptr,pCurPart+1)+uTotalSize-EndBytes, EndBytes)
              memcpy( cast(any ptr,pCurPart+1) , @pbPacked(0) , iPackSz )
            end with
            'show decompressor code addr/size data...
            if iCompressorLoaded=0 then
              vprint(vlMaximum,3) "Data "+sRPad(str(ubound(pbDecompress)+1),5)+" "+hex$(DecompAddr,4)+"  Unpacker routine."
              iCompressorLoaded=bpfCompressorLoaded
            end if
             'so next block already have compressor
          end if
        end if
        
        pNewPart = cast(any ptr, pCurPart+1)+pCurPart->uSize : iPosi += uSize        
        
        'show info
        dim as string sInfo        
        if (pCurPart->uFlags) and bpfPacked then
          sInfo = "  Packed to " & pCurPart->uSize & " ("
          sInfo += 100-(((pCurPart->uSize)*100)\uTotalSize) & !"%)"
        end if
        if iMerges then 
          if len(sInfo)=0 then sInfo = " "
          sInfo += " [Merged " & iMerges+1 & " blocks]"
        end if
        vprint(vlMaximum,7) "Data "+sRPad(str(uTotalSize),5)+" "+hex$(uAddr,4)+sInfo        
        
      end if
      
      exit do 'loop never :P
    loop
    
    'print "0x"+hex$(pCurPart->pNext)
    
  loop  
    
  print ""; '< don't delete... @_@
  
  'delete file block and return array with parts...
  if pData then deallocate(pData):pData=0  
  
  iFileSize = iFSz : return pParts

end function
