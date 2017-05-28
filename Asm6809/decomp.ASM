	pragma newsource
	opt 6809
	opt cd	
	
	*PRAGMAPUSH nolist
	PRAGMA nolist 

	*PRAGMAPOP nolist
		
	org $1DA ;$2DD+8 ;$1DA 741

; Methods
; 0 = Size Raw bytes
;     (if Size=0 then Size=Parm1+64 bytes...)
; 1 = RLE (repeat Parm1 bytes Size times)
; 2 = Window (copy from offset -Parm1... Size bytes)
; 3 = Window2 (copy form offset -(Parm1|Parm2)... Size bytes)

BEGIN:	;pshs CC
	;orcc #$50
	;ldy #pData     ; Y = pointer to compressed block
	;sts @OrgS+2, PCR ; save current S
	;lds #3584      ; S = pointer to target memory	
	sts @OrgS+2, PCR
	ldy #$AAAA	
	lds #$AAAA
@NXBYTE:	ldd ,Y++       ; B = size6|method2 A = parm/data
	lsra           ; method is... 0,2 or 1,3?
	bcs @Method13
@Method02:  lsra           ; method is 0 or 2?
	bcs @Method2
;; ===========================================================================
@Method0:   beq @Raw16
;; ===========================================================================
@Raw8:	stb ,S+        ; Parm1 was already first byte
	deca           ; one byte read
	beq @NXBYTE    ; yes? then go read next block
	bita #1        ; remaining is odd or even?
	beq @Raw8NX    ; even? so read in words	
	ldb ,Y+        ; load the odd byte
	stb ,S+        ; store the odd byte
	deca           ; a byte copied, there's more?
	beq @NXBYTE    ; no? then go read next block
@Raw8NX:	ldu ,Y++       ; load a word
	stu ,S++       ; store a word
	suba #2        ; 1 word copied, there's more?
	bne @Raw8NX    ; yes? then go read it
	bra @NXBYTE    ; no? then go read next block
;; ===========================================================================
@Raw16:	lda #32        ; size is B+64 (so loading first 32 words)
@Raw16NXA:	ldu ,Y++       ; load a word
	stu ,S++       ; store a word
	deca           ; a word copied
	bne @Raw16NXA  ; continue until all 32 words are copied
	tstb           ; size was exactly 64?
	beq @NXBYTE    ; yes? then go read next block
	bitb #1        ; remaining is odd or even?
	beq @Raw16NXB  ; even so read in words
	lda ,Y+        ; load a byte
	sta ,S+        ; store a byte
	decb           ; a byte copied, there's more?
	beq @NXBYTE    ; no? then go read next block
@Raw16NXB:	ldu ,Y++       ; load a byte
	stu ,S++       ; store a byte
	subb #2        ; 1 word copied, there's more?
	bne @Raw16NXB  ; continue until all bytes are copied
	bra @NXBYTE	   ; and go read next block
;; ===========================================================================
@Method2:   stb <@WndDiff+3,PCR ;store window offset on self-modified leau -xx, X
@WndDiff:   leau >-1, S    ; U = S-offset
@WndStart:	bita #1        ; remaining is odd or even?
	beq @WndNX     ; even? so copy in words
	ldb ,U+        ; load a byte
	stb ,S+        ; store a byte
	deca           ; a byte copied, there's more?
	beq @NXBYTE    ; no? then go read next block
@WndNX:	ldx ,U++       ; read a word
	stx ,S++       ; store a word
	suba #2        ; 1 word copied, there's more?
	bne @WndNX     ; continue until all bytes are copied
	bra @NXBYTE    ; and go read next block
;; ===========================================================================
@Method13:	lsra           ; method is 1 or 3?
	bcs @Method3
;; ===========================================================================
@Method1:   beq @Done      ; if RLE size is 0... then encoding is done	
	bita #1        ; remaining is odd or even?
	beq @Rle16     ; even? so copy in words
	stb ,S+        ; store byte
	deca           ; a byte was filled, there's more?
	beq @NXBYTE    ; no? then go read next block
@Rle16:	stb @RleH+1,PCR; store B on high byte of self-mod load X
@RleH:	ldx #$0000     ; X = B|0
	abx            ; X += B
@RleNx:	stx ,S++       ; store a word
	suba #2        ; 1 word stored, there's more?
	bne @RleNx     ; continue while there's more
	bra @NXBYTE    ; and go read next block
;; ===========================================================================
@Method3:   sta <@M3A+1,PCR ; Store old A for later recover
	lda ,Y+        ; A = MSB of offset
	leau D, S      ; U = S-offset16
@M3A:	lda #0         ; reload old A
	bra @WndStart  ; go copy bytes
;; ===========================================================================
@Done:	ldx #$5555
	ldu #$5555
	lda #$55
	stx ,S++
	stu ,S++	
	sta ,S+
	ldu #$6666
	ldd #$6666
	ldx #$7777
	stu ,X
	std 2,X		
@OrgS:	lds #0
	jmp ,X
	;puls CC
@Lock:	;rts ;bra @Lock

	;org 26000
pData:      
	;includebin "irc.pix.rlx"
	;includebin "racobin.pix.rlx"

	end BEGIN	