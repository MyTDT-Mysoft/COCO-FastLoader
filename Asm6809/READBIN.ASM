	pragma newsource
	opt 6809
	opt cd	
	
	*PRAGMAPUSH nolist
	PRAGMA nolist 
	
	include const.asm

	
cHState	equ (R01_HSyncFlag|R01_MuxSelLSB);|R01_HSyncIrq) ;R01_HDirection|
cVState	equ (R03_VsyncFlag|R03_MuxSelMSB);|R03_VsyncIrq) ;R03_VDirection|

pNewStack   equ $400-(1+2+2)
cScratch    equ 0
cIoState    equ 1
cOldStack   equ 3
cIndicator  equ 5

	*PRAGMAPOP nolist
		
	org $2DD+8 ;$1DA 741
	
; ***** Setup DP to I/O and prepare for casette 1bit input ******		
BEGIN:	ldb #$7E
	stb >$176
	dec 11,S

	sts >pNewStack+cOldStack
	lds #pNewStack
	
	lda #$FF
	tfr A,DP			; DP = 0xFF??
	SETDP $FF
	orcc #(cFirqMask|cIrqMask)	; Disable Interrupts   ; Disable IRQs
		
	lda <$01			;
	ldb <$03			;	
	std cIoState,S		; store I/O changes to restore later
	anda #(^cHState)		; Disable Hsync Interrupt / Clear Flag	
	ora  #(R01_MuxSelLSB)		; (Sound Source Cassette)
	sta <$01			; (Sound Source cassette)	
	andb #(^cVState)		; Disable Vsync Interrupt / Clear Flag
	;orb  #(R03_VsyncIrq)
	stb <$03 			; 
	
	ldb #$3C                            ; default BITS and MOTOR ON
	stb cIndicator,S                    ; show that on the left/top of the screen
	stb <$21                            ; and perform the action sending to 0xFF21
			
RESYNC:	;synchronize signal and jump to "MAIN"
	
	include syncup.asm
	;first thing must be a "bsr GETBYTE"	
	;must repeat the "bsr" at cycle 28   

; ******** in Sync can start reading bytes *********
;RESYNC1:	bra RESYNC

@GETBYTEX:	abx			;~03|15 add last byte to checksum
	mul			;~11|26 +
	tfr D,D			;~06|32 > sync to 28+4
	bra GETBYTE			;~03|00 next byte and return to caller
MAIN:	bsr GETBYTE			;~07|00 ---- first byte
;; =============================================================================================	
	cmpb #1			;~02|02 option is 0 or 1?
	bhi RESYNC			;~03|05 no? then go resync
	ldx #0			;~03|08 X storing checksum
	stb cScratch,S		;~04|12 store command on stack
	abx			;~03|15 add to header checksum
	nop			;~02|17 +
	mul			;~11|28 > sync to 28
	bsr GETBYTE			;~07|00 ---- second byte
;; =============================================================================================	
	stb @AMOUNT+2,PCR		;~05|05 set MSB of size (or none)	
	bsr @GETBYTEX		;~07|00 07+13 > then get new byte
;; =============================================================================================		
	stb @AMOUNT+3,PCR		;~05|05 set LSB of size (or none)	
	bsr @GETBYTEX		;~07|00 07+13 > then get new byte
;; =============================================================================================
	stb @ADDR+1,PCR		;~05|05 set MSB of address (or none)	
	bsr @GETBYTEX		;~07|00 07+13 > then get new byte
;; =============================================================================================		
	stb @ADDR+2,PCR		;~05|05 set LSB of address (or none)	
	bsr @GETBYTEX		;~07|00 07+13 > then get new byte
;; =============================================================================================
	abx			;~03|03 add checksum to x
	tfr X,D			;~06|09 now B should be 0
	tstb			;~02|11 is B=0?
	bne FNERR                           ;~03|14 no? then checksum error...
@AMOUNT:	ldy #0			;~04|18 how much bytes to read
@ADDR:	ldu #0			;~03|21 where to read?
	ldb cScratch,S		;~04|25 option was 0 or 1?
	beq FNEOF			;~03|28 0? then load complete
@NEXTBYTE:	bsr GETBYTE			;~07|00 get data byte
;; =============================================================================================
	abx			;~03|03 add it to checksum
	stb ,U+			;~06|09 store received byte
	mul			;~11|20 > delay 11 cycles
	;inc 3,S>$402
	;leax ,X
	leay -1,Y			;~05|25 one byte stored
	bne @NEXTBYTE		;~03|28 go get another byte
	bsr GETBYTE			;~07|00 get data checksum byte
;; =============================================================================================
	abx			;~03|03 add checksum to x
	tfr X,D			;~06|09 now B should be
	tstb			;~02|11 is B=0?
	bne FNERR			;~03|14 no? then checksum error...
	
	;ldb cIndicator,S                    ;~05|19
	;eorb #64                            ;~02|21
	;stb cIndicator,S                    ;~05|26
	
	;com >$400			;~07|21 invert indicator
	
	mul                                 ;~11|25	
	
	;bra RESYNC1		;~03|24 another sync for another command
	
	;leax ,X			;~04|25	
	bra MAIN                            ;~03|28

;; =============================================================================================		
FNERR:	lda #69			;       A = "E"rror
	std cIndicator,S	            ;       store on screen and finish	
FNEOF:	ldd cIoState,S		;       original I/O
ORGSTK:     lds cOldStack,S                     ;       original stack
	sta <$01			;       store part A
	stb <$03			;       store Part B	
	ldb #$34                            ;       "default bits an MOTOR OFF"	
	stb <$21                            ;       on 0xFF21
	rti			;       restore changed registers and return	
	
	org $106			; auto-run
	jmp BEGIN
	
	org $176
	swi
		
	end BEGIN
	