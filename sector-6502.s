
;----------------------------------------------------------------------
;   MilliForth for 6502 
;
;   original for the 6502, by Alvaro G. S. Barcellos, 2023
;
;   https://github.com/agsb 
;   see the disclaimer file in this repo for more information.
;
;   SectorForth wnd MilliForth was made for x86 arch 
;   and uses full 16-bit registers 
;
;   The way at 6502 is use a page zero and lots of lda/sta bytes
;   Focus in size not performance.
;
;   Changes:
;   data and return stacks and tib are 256 bytes 
;   only immediate flag used as $80, no hide, no compile
;
;----------------------------------------------------------------------
; for ca65 
.p02
.feature c_comments
.feature string_escapes
.feature org_per_seg
.feature dollar_is_pc
.feature pc_assignment

;---------------------------------------------------------------------
; label for primitives
.macro makelabel arg1, arg2
.ident (.concat (arg1, arg2)):
.endmacro

H0000 = 0
hcount .set 0

; header for primitives
.macro def_word name, label, flag
;this = *
makelabel "is_", label
    .ident(.sprintf("H%04X", hcount + 1)) = *
	.word .ident (.sprintf ("H%04X", hcount))
    hcount .set hcount + 1
    .byte .strlen(name) + flag + 0
    .byte name
makelabel "", label
.endmacro

;----------------------------------------------------------------------
; alias
CELL   =  2     ; 16 bits
SIZES  = $100

FLAG_IMM  =  1<<7

;----------------------------------------------------------------------
.segment "ZERO"

* = $E0
nil:    .word $0 ; reference, do not touch ! 
lnk:    .word $0 ; link, do not touch !
dta:    .word $0 ; holds data stack base,
ret:    .word $0 ; holds return stack base,

tos:    .word $0 ; top
nos:    .word $0 ; nos
wrk:    .word $0 ; work

state:  .word $0 ; state
toin:   .word $0 ; toin
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell

;----------------------------------------------------------------------
.segment "ONCE" 

;----------------------------------------------------------------------
.segment "VECTORS" 

;----------------------------------------------------------------------
.segment "CODE" 

;---------------------------------------------------------------------
main:

    lda #<semis
    sta last + 0
    lda #>semis
    sta last + 1

    lda #<init
    sta here + 0
    lda #>init
    sta here + 1
    
    ; that does the trick
    lda #<nil
    sta nil + 0
    lda #>nil
    sta nil + 1

error:

	lda #13
	jsr putchar

quit:

    lda #<dsb
    sta dta + 0
    lda #>dsb
    sta dta + 1

    lda #<rsb
    sta ret + 0
    lda #>rsb
    sta ret + 1
    
    ; clear tib stuff
    lda #0
    sta toin + 0
    sta toin + 1
    sta tib + 0

    ; state interpret
    lda #1
    sta state + 0

find:

    ; get a token, (nos)
    jsr tok_
  
    ; load last link
    lda #<last
    sta wrk + 0
    lda #>last
    sta wrk + 1

@loop:

    ; linked list
    lda wrk + 0
    sta tos + 0
    lda wrk + 1
    sta tos + 1
    
    ldx #(tos - nil)
    ldy #(wrk - nil)
    jsr pull

    ; verify is zero
    lda wrk + 0
    ora wrk + 1
    beq error ; no more words

    ; bypass link
    ldx #(tos - nil)
    jsr incw
    jsr incw

    ; compare words
    ; must mask the flags
    ldy #0
    lda (tos), y
    and #$80
    sta wrk + 0

@equal:
    lda (nos), y
    cmp #32
    beq @done
    sbc (tos), y
    and #$7F    ; 7-bit ascii
    bne @loop
    iny
    bne @equal
@done:
    
    ; update 
    tya
    ldx #(tos - nil)
    jsr add2w

    ; compile or execute
    lda wrk + 0     ; immediate ? 
    bne @execw
    lda state + 0   ; executing ?
    bne @execw

    jmp compile

@execw:
    jmp (tos)

getline_:
    ldy #0

@loop:  
	jsr getchar
    ;   and #$7F    ; 7-bit ascii
	cmp #10         ; lf ?
	beq @ends
    ;	cmp #13     ; cr ?
	;   beq @ends
    ;   cmp #8      ; bs ?
    ;   bne @puts
    ;   dey
    ;   jmp @loop
@puts:
    sta tib, y
    iny
    ;   cpy #254
    ;   beq @ends   ; leave ' \0'
	bne @loop
@ends:
    ; grace ends
    lda #32
    sta tib, y
    iny
    lda #0
    sta tib, y
    sta toin + 1
    rts

try_:
    lda tib, y
    beq getline_    ; if \0 
    iny
    cmp #32
    rts

tok_:
    ; last position on tib
	ldy toin + 1

@skip:
    ; skip space
    jsr try_
    beq @skip

    ; keep start 
    dey
    sty toin + 0    

@scan:
    ; scan space
    jsr try_
    bne @scan

    ; keep stop 
    dey
    sty toin + 1    ; save position

    ; strlen
    sec
    lda toin + 1
    sbc toin + 0

    ; place strlen
    ldy toin + 0
    dey
    sty toin + 0
    sta tib, y    ; store size ahead 

    lda toin + 0
    sta nos + 0
    lda #>tib
    sta nos + 1

    rts

;---------------------------------------------------------------------

; add a byte to a word in page zero. offset by X
add2w:
    clc
    adc nil + 0, x
    sta nil + 0, x
    bcc @incc
    inc nil + 1, x
@incc:
    rts

; decrement a word in page zero. offset by X
decw:
    lda nil + 0, x
    bne @none
    dec nil + 1, x
@none:
    dec nil + 0, x
    rts

; increment a word in page zero, offset by X
incw:
    inc nil + 0, x
    bne @none
    inc nil + 1, x
@none:
    rts 

; pull a word 
; from a page zero address indexed by X
; into a absolute page zero address indexed by y
pull:
    lda (nil, x)    
    sta nil + 0, y   
    jsr incw        
    lda (nil, x)    
    sta nil + 1, y  
    jmp incw

; push a word 
; from an absolute page zero address indexed by Y
; into a page zero address indexed by X
push:
    jsr decw
    lda nil + 1, y
    sta (nil, x)
    jsr decw
    lda nil + 0, y
    lda (nil, x)
    rts

; push into data stack
spush:
    ldx #(dta - nil)
    ldy #(tos - nil)
    jmp push

; pull from data stack
spull:
    ldx #(dta - nil)
    ldy #(tos - nil)
    jmp pull

spull2:
    jsr spull 
dta2nos:
    ; ldx #(dta - nil)
    ldy #(nos - nil)
    jmp pull

; fetch from
; store into

;---------------------------------------------------------------------
; for lib6502  emulator
getchar:
    lda $E000

putchar:
    sta $E000
    rts

;---------------------------------------------------------------------
; primitives ends with jmp link_
;def_word "emit", "emit", 0
;def_word "key", "key", 0
;---------------------------------------------------------------------
def_word "!", "store", 0
storew:
    jsr spull2
    ldx #(tos - nil)
    ldy #(nos - nil)
    jsr push
    jmp link_

def_word "@", "fetch", 0
fetchw:
    jsr dta2nos
    ldx #(nos - nil)
    ldy #(tos - nil)
    jsr pull
    jmp topsh

def_word "s@", "statevar", 0 
    lda #<state
    sta tos + 0
    lda #>state
back:
    sta tos + 1
topsh:
    jsr spush
    jmp link_

def_word "rp@", "rpfetch", 0
    lda ret + 0
    sta tos + 0
    lda ret + 1
    jmp back

def_word "sp@", "spfetch", 0
    lda dta + 0
    sta tos + 0
    lda dta + 1
    jmp back

def_word "+", "plus", 0
    jsr spull2
    clc
    lda nos + 0
    adc tos + 0
    sta tos + 0
    lda nos + 1
    adc tos + 1
    jmp back

def_word "nand", "nand", 0
    jsr spull2
    lda nos + 0
    and tos + 0
    eor #$FF
    sta tos + 0
    lda nos + 1
    and tos + 1
    eor #$FF
    jmp back

def_word "0=", "zeroq", 0
    jsr spull
    lda tos + 0
    ora tos + 1
    bne isfalse
istrue:
    lda #$FF
rest:    
    sta tos + 0
    jmp back
isfalse:
    lda #$0
    beq rest

;def_word "shr", "shr", 0
;    jsr spull
;    lsr tos + 1
;    ror tos + 0
;    jmp spush

; minimal indirect thread code
; lnk must be preserved, as IP
;
def_word "exit", "exit", 0
unnest_:

    ; pull from return stack
    ldx #(ret - nil)
    ldy #(tos - nil)
    jmp pull

next_:
    ldx #(tos - nil)
    ldy #(lnk - nil)
    jsr pull

    ; is a primitive ? 
    lda lnk + 1
    cmp #$08    ; magic high byte of init:
    bcc jump_

nest_:

; push into return stack
    ldx #(ret - nil)
    ldy #(tos - nil)
    jmp push

link_:
    lda lnk + 0
    sta tos + 0
    lda lnk + 1
    sta tos + 1
    jmp next_

jump_:
    ldx #(ret - nil)
    ldy #(lnk - nil)
    jsr pull
    jmp (tos)

def_word ":", "colon", 0
    ; save here, for update last later

;jsr okey

    ldx #(dta - nil)
    ldy #(here - nil)
    jsr push

    ; update the link field with last

    ldx #(here - nil)
    ldy #(last - nil)
    jsr push

    ; get the token, at nos
	jsr tok_

    ;copy size and name ????
    ldy #0
@loop:    
    lda (nos), y
    cmp #32     ; stops at space
    beq @ends
    sta (here), y
    iny
    bne @loop
@ends:

    ; update here
    tya
    ldx #(here - nil)
    jsr add2w

    ; update state as 'compile'

	lda #0
    sta state + 0
    
    jmp link_

def_word ";", "semis", FLAG_IMM

    ; update last

    ldx #(dta - nil)
    ldy #(last - nil)
    jsr pull

    ; update state as 'interpret'
	lda #1
    sta state + 0

    ; compounds ends with pointer to 'unnest'
    lda #<unnest_
    sta tos + 0
    lda #>unnest_
    sta tos + 1

compile:
    
    ldx #(here - nil)
    ldy #(tos - nil)
    jsr push
    jmp link_

ends:

.if 0

erro:
    lda #'?'
    jsr putchar
    lda #'?'
    jsr putchar
	lda #10
	jsr putchar
	lda #13
	jsr putchar
    rts

okey:
    lda #'O'
    jsr putchar
    lda #'K'
    jsr putchar
	lda #10
	jsr putchar
	lda #13
	jsr putchar
    rts

.endif


.align $100

; $200 to $2FF terminal input buffer
tib:
.res SIZES, $0   

; $3FF to $300 return stack base, 128w deep
.res SIZES, $0
rsb:            

; $4FF to $400 data stack base, 128w deep
.res SIZES, $0
dsb:            

; for anything above is not a primitive
* = $800
init:   

