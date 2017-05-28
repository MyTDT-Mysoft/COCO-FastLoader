
; **************************************************
; **************** Initial Sync UP *****************
; **************************************************		
SYNCUP:	clr ,S			;~06     reset sync state
;==============================================================================
@RELOOP:	bsr GETBYTE			;~07|58 ? go sync	
;>>>>>>>>>>>>> RTS here at cycle 23... must BSR at cycle 58 <<<<<<<<<<<<<<
@BYTECHK:	
	cmpb #$4B 			;~02|25 $4B
	beq @STAGEA28		;~03|28 if char is 4B Assert Stage A	
	tstb			;~02|30 $00
	beq @STAGEB33		;~03|33 if char is 00 Check/Try Stage B	
	incb			;~02|35 $FF
	bne SYNCUP   		;~03|38 if char is FF Check/Try Stage C	
;;
@STAGEC38:	tst 0,S			;~07|45 check state	
	bpl @REUSE48		;~03|48 positive? then can't proceed
	bra MAIN			;~03|51 after sync, NEXT STAGE OF PROGRAM
@STAGEA28:	tst 0,S			;~07|35 check state
	bne @SYNCW38		;~03|38 non zero than already Stage A
	inc 0,S			;~07|45 Set state to Stage B (01)
	bra @REUSE48		;~03|48 and go read next byte
;;
@STAGEB33:	tst ,S			;~06|39 check state
	ble @SYNCW42		;~03|42 zero? negative? then can't proceed	
	neg ,S			;~06|48 Set state to Stage C (FF)
@REUSE48:	bra @RELOOP			;~03|51 and go read next byte
;;
@SYNCW38:	leas ,S			;~04|42 delay till cycle 42
@SYNCW42:	brn @SYNCW42		;~03|45 + 
	bra @REUSE48		;~03|48 > Go Read next byte

;==============================================================================
GETSYNCBIT:	bmi @IS1			;~03|56
;;
@IS0:	lda #1			;~02|58 load bit comparator
@RE0:	bita <$20			;~04|04 read 1st sample
	beq @RE0			;~03|07 it's 0? then not new sample	
	bita <$20			;~04|11 read 2nd sample
	beq @RE0			;~03|14 it's still 1? then new sample :)
	brn @RE0    		;~03|17 never...
;;	
@RETBYTE:	eorb $AA			;~02|19 [Self-Mod] TSTA/COMA	
	rts			;~05|24 return byte to program
;;
@IS1:	lda #1			;~02|58 load bit comparator
@RE1:	bita <$20			;~04|04 read 1st sample
	bne @RE1			;~03|07 it's 1? then not new sample	
	bita <$20			;~04|11 read 2nd sample
	bne @RE1			;~03|14 it's still 0? then new sample :)
	bra @RETBYTE		;~03|17
	
; ===============================================================================================
GETBYTE:	ldb #128			;~02|02 holds byte and rotate signal
@GETBIT:	lda <$20			;~04|06 read 1st sample
	anda #1			;~02|08 add carry to sum
;;
	nop			;~02|10
	lsr <$20			;~06|16 read 2nd sample
	adca #0			;~02|18
	;tst D,S
;;
	nop			;~02|20
	lsr <$20			;~06|26 read 3rd sample	
	adca #0			;~02|28
;;
	nop			;~02|30
	lsr <$20			;~06|36 read 4th sample
	adca #0			;~02|38 add carry to sum
	;tst D,S
	;;
	nop			;~02|40
	lsr <$20			;~06|46 read 5rd sample
	adca #253			;~02|48 add carry to sum
	rorb			;~02|50 rotate into byte buffer
	bcs GETSYNCBIT		;~03|53 rotated 8 bits? then go sync
;;
	tfr D,D			;~06|59
	bra @GETBIT			;~03|62 > go read next bit
	