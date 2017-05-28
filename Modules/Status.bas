function sGetFilename( sPathFile as string ) as string
  var iPosiA = instrrev(sPathFile,"\"), iPosiB = instrrev(sPathFile,"/")
  if iPosiB > iPosiA then iPosiA = iPosiB
  return mid$(sPathFile,iPosiA+1)
end function
function GenIntroString( sFile as string , iIndicator as long ) as string
  var sIntro = string$(32,64 or asc(" "))
  sIntro[0] = iIndicator
  sIntro[29] = asc("0") or 64
  sIntro[30] = asc("%") or 64
  var iPosiA = instrrev(sFile,"\"), iPosiB = instrrev(sFile,"/")
  if iPosiB > iPosiA then iPosiA = iPosiB
  iPosiB=2
  for N as long = iPosiA to len(sFile)-1
    var iC = sFile[N]
    select case iC
    case 0 to 31,127 to 255: sIntro[iPosiB] = asc("?")
    case asc("a") to asc("z"): sIntro[iPosiB] = (iC-32) or 64
    case else: sIntro[iPosiB] = iC or 64
    end select
    iPosiB += 1
  next N
  return sIntro
end function
sub PrintHelp()
  print "Mysoft TRS-COLOR audio fast loader v1.0"
  print "Usage: "+sGetFilename(command$(0))+!" options BinaryFile\r\n"  
  print " -O# Output Speakers (0=Front Speakers(default),1=Back Speakers)"
  print " -D# Device ID for audio output (automatic if ommited)"
  print " -R# Select speed rate (0=normal 44khz,1=double 58khz,2=double 88khz)"
  print " -V# Verbosity level (0=quiet,1=errors only,2=normal,3=verbose)"
  print " -C  Enable compression"
  print " -U  Disable compression"
  print " -S  Show statistics while fast loading"
  print " -A  Autoexecute loaded file"
  print " -W  Dump output to BinaryFile.Ext.Wav"
  print " -P  Play the Binary File"
  print " -I  Interactive mode (same as not using -P or -W)"
  print " -H  Show this help and quit"  
end sub
sub InvalidParameters(sParm as string)
  PrintHelp()  
  color 12:print !"\r\nInvalid parameter: '"+sParm+!"'"
  color 7: system 1
end sub

function InteractiveMenu() as integer  
    
  CleanOptLine(0)
  PrintOpt(0,0,"Rate..: ")
  if iCfgDouble=2 then print "Double (1.7mhz "; else print "Normal (0.9mhz ";
  print (SoundFreq*iCfgDouble)\1000 & "khz)";    
  PrintOpt(0,2,"Compress: ")
  if iCfgPack then print "Yes"; else print "No ";
  
  CleanOptLine(1)
  PrintOpt(1,0,"Device: ")
  if iCfgAudioDevice = -1 then print "Auto"; else print str$(iCfgAudioDevice);    
  PrintOpt(1,1,"Stats.: ")
  if iCfgStatus then print "Yes"; else print "No ";
  PrintOpt(1,2,"Autoexec: ")
  if iCfgAutorun then print "Yes"; else print "No ";
  
  CleanOPtLine(2)
  PrintOpt(2,0,"Output: ")
  if iCfgOutputSpeakers=-1 then print "Back speakers"; else print "Front speakers";  
  
  PrintOpt(2,2,"Wav Dump: ")
  if iCfgFileDump then print "Yes"; else print "No ";
  
  color 15: print !"\r\n\r\n";
  color 7: print  !"Select one option: ";
  color 14: print "(P)";: color 15: print "roceed";
  color 14: print "  (Q)";: color 15: print "uit";
  color 7: print " ? ";  
  do
    var sKey = inkey$
    if len(sKey)=0 then sleep 50,1: continue do
    var iKey = clng(sKey[0])        
    select case iKey
    case asc("r"),asc("R") 'Rate
      if iCfgDouble=1 then 
        iCfgDouble=2: iFreqMult=2
      elseif iFreqMult=2 then
        iFreqMult=3
      else
        iCfgDouble=1
      end if
      SoundFreq = (cInitFreq*iFreqMult)\1000
      return 0
    case asc("c"),asc("C") 'Compress
      iCfgPack = ((iCfgPack=0) and 1)
      return -1
    case asc("d"),asc("D") 'Device
      locate iOptLine+1, 9
      color 15: print "?   "      
      locate iOptLine+1, 11
      do
        sKey = inkey$
        if len(sKey)=0 then sleep 50,1: continue do
        select case sKey[0]
        case asc("0") to asc("9")
          iCfgAudioDevice = sKey[0]-asc("0")
          return 0
        case 13
          iCfgAudioDevice = -1
          return 0
        case 27
          return 0
        end select
      loop
    case asc("s"),asc("S") 'Stats
      iCfgStatus = ((iCfgStatus=0) and 1)
      return 0
    case asc("a"),asc("A") 'Autoexec
      iCfgAutorun = (iCfgAutorun=0) and 1
      return 0
    case asc("w"),asc("W") 'Wav dump
      iCfgFileDump = (iCfgFileDump=0) and 1
      return 0
    case asc("o"),asc("O") 'Output
      iCfgOutputSpeakers = -iCfgOutputSpeakers
      return 0
    case asc("p"),asc("P") 'Proceed
      color 10: print "Proceed"
      iCfgDoPlay = 1
      return 1
    case asc("q"),asc("Q") 'Quit
      color 10: print "Quit"
      color 7: system
    end select
  loop      

end function

function ParseParameters( sInputFile as string ) as integer    
  
  const cNoParm = -asc("0")
  var iParm = 1 : sInputFile = ""
  
  do
    var sParm = trim$(command$(iParm)): iParm += 1
    if len(sParm)=0 then exit do     
    if sParm[0] = asc("-") then 'it's a parameter
      if len(sParm) < 2 or len(sParm)>3 then InvalidParameters(sParm)
      var iParmNum = cint(sParm[2])+cNoParm
      if iParmNum <> cNoParm andalso iParmNum < 0 or iParmNum > 9 then InvalidParameters(sParm)
      select case sParm[1]
      case asc("O"),asc("o") 'Output Speakers (0=Front Speakers(default),1=Back Speakers)"
        if iParmNum < 0 or iParmNum > 1 then InvalidParameters(sParm)
        iCfgOutputSpeakers = iif(iParmNum=0,1,-1)
      case asc("D"),asc("d") 'Device ID for audio output (automatic if ommited)
        if iParmNum < 0 or iParmNum > 9 then InvalidParameters(sParm)
        iCfgAudioDevice = iParmNum
      case asc("R"),asc("r") 'Select speed rate (0=normal 44khz,1=double 58khz,2=double 88khz)
        if iParmNum < 0 or iParmNum > 2 then InvalidParameters(sParm)
        select case iParmNum
        case 0: iFreqMult=3: iCfgDouble = 1
        case 1: iFreqMult=2: iCfgDouble = 2
        case 2: iFreqMult=3: iCfgDouble = 2
        end select
        SoundFreq = (cInitFreq*iFreqMult)\1000
      case asc("V"),asc("v") 'Verbosity level (0=quiet,1=errors only,2=normal,3=verbose)
        if iParmNum < vlQuiet or iParmNum > vlMaximum then InvalidParameters(sParm)
        iCfgVerbose = iParmNum
      case asc("C"),asc("c") 'Enable compression
        if iParmNum <> cNoParm then InvalidParameters(sParm)
        iCfgPack = 1
      case asc("U"),asc("u") 'Disable compression
        if iParmNum <> cNoParm then InvalidParameters(sParm)
        iCfgPack = 0
      case asc("S"),asc("s") 'Show statistics while fast loading
        if iParmNum <> cNoParm then InvalidParameters(sParm)        
        iCfgStatus = 1
      case asc("A"),asc("a") 'Autoexecute loaded file
        if iParmNum <> cNoParm then InvalidParameters(sParm)
        iCfgAutorun = 1
      case asc("W"),asc("w") 'Dump output to BinaryFile.Ext.Wav
        if iParmNum <> cNoParm then InvalidParameters(sParm)
        iCfgFileDump = 1: if iCfgInteractive = -1 then iCfgInteractive = 0        
      case asc("P"),asc("p") 'Play the Binary File
        if iParmNum <> cNoParm then InvalidParameters(sParm)
        iCfgDoPlay = 1: if iCfgInteractive = -1 then iCfgInteractive = 0
      case asc("I"),asc("i") 'Interactive mode (same as not using -P or -W)
        if iParmNum <> cNoParm then InvalidParameters(sParm)
        iCfgInteractive = 1
      case asc("H"),asc("h") 'Show this help and quit
        if iParmNum <> cNoParm then InvalidParameters(sParm)
        PrintHelp() : system 0
      case else
        InvalidParameters(sParm)
      end select
    else
      sInputFile = sParm
      do
        sParm = command$(iParm): iParm += 1
        if len(sParm)=0 then exit do
        sInputFile += " "+sParm
      loop
      exit do
    end if
  loop
        
  if len(sInputFile)=0 then    
    line input "File to fastload? ", sInputFile
    sInputFile = trim$(sInputFile)
    if len(sInputFile)=0 then
      print "No file specified, quitting..."
      return 0
    end if    
  end if
  
  if iCfgInteractive <> -1 then
    if iCfgStatus = -1 then iCfgStatus = 0
    if iCfgPack = -1 then iCfgPack = 0
  end if
  
  return 1
  
end function
