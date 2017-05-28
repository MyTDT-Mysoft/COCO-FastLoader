function wSwap(N as ushort) as ushort
  return (N shr 8) or ((N and &hFF) shl 8)
end function
function sRPad(SS as string, iPad as long) as string
  return right$(space(iPad)+SS,iPad)
end function
function sLPad(SS as string, iPad as long) as string
  return left$(SS+space(iPad),iPad)
end function

sub CleanOptLine(iY as long)
  locate iOptline+iY: color 7,0
  print string$(iConWid," ");
end sub

sub PrintOpt(iY as long,iX as long,sOpt as string)
  locate iOptLine+iY, 1+(iX*16): color 14
  print left$(sOpt,1);
  color 7: print mid$(sOpt,2);
  color 10
end sub