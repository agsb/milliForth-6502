;----------------------------------------------------------------------
;   MilliForth for 6502 
;
;   original for the 6502, by Alvaro G. S. Barcellos, 2023
;
;   https://github.com/agsb 
;   see the disclaimer file in this repo for more information.
;
;   SectorForth and MilliForth was made for x86 arch 
;   and uses full 16-bit registers 
;
;   The way at 6502 is use a page zero and lots of lda/sta bytes
;
;   Focus in size not performance.
;
;   Changes:
;   data and return stacks and tib are 256 bytes 
;   only immediate flag used as $80, no hide, no compile, no extras
;
;   Forth-1994:
;   FALSE is $0000
;   TRUE  is $FFFF
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
; default pseudo registers
nil:    .word $0 ; reference, do not touch ! 
lnk:    .word $0 ; link, do not touch !

dta:    .byte $7F ; holds data stack base 64 words
rte:    .byte $FF ; holds return stack base 64 words

; default Forth pseudo registers
tos:    .word $0 ; top
nos:    .word $0 ; nos
wrk:    .word $0 ; work
tmp:    .word $0 ; temp for hold here while in compile state

; default Forth variables
state:  .word $0 ; state
toin:   .word $0 ; toin
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell

;----------------------------------------------------------------------
;.segment "ONCE" 

;----------------------------------------------------------------------
;.segment "VECTORS" 

;----------------------------------------------------------------------
.segment "CODE" 

* = $200

; terminal input buffer, 256 bytes
tib:
.res SIZES, $0   

; stack base, 128 words deep, half data, half return
.res SIZES, $0
stk:            

;----------------------------------------------------------------------

opush:
    dey
    lda tos + 0
    sta stk, y
    dey
    lda tos + 1
    sta stk, y
    rts

opull:
    lda stk, y
    sta tos + 0
    iny
    lda stk, y
    sta tos + 1
    iny
    rts

rpush:
    ldy rte
    jsr opush
    sty rte
    rts

rpull:    
    ldy rte
    jsr opull
    sty rte
    rts
    
spush:
    ldy dta
    jsr opush
    sty dta
    rts

spull:    
    ldy dta
    jsr opull
    sty dta
    rts
    
copys:
    lda tos
    sta nos
    lda tos + 1
    sta nos + 1
    rts

spull2:
    ldy dta
    jsr opull
    jsr copys
    jsr opull
    sty dta
    rts

; add a byte to a word in page zero. offset by X
add2w:
    clc
    adc nil + 0, x
    sta nil + 0, x
    bcc @noinc
    inc nil + 1, x
@noinc:
    rts

;---------------------------------------------------------------------
; for lib6502  emulator
getchar:
    lda $E000

putchar:
    sta $E000
    rts

;---------------------------------------------------------------------
main:

    ; latest link
    lda #<semis
    sta last + 0
    lda #>semis
    sta last + 1

    ; next free memory cell
    lda #<init
    sta here + 0
    lda #>init
    sta here + 1
    
error:

    lda #13
    jsr putchar

;---------------------------------------------------------------------
quit:

    ; stacks grows backwards

    ldy #$7F
    sty dta 

    ldy #$FF
    sty rte 

    ; clear tib stuff
    ldy #$0
    sty toin + 0
    sty toin + 1
    sty tib + 0

    ; state is 'interpret'
    iny   
    sty state + 0

;---------------------------------------------------------------------
outer:

    ; ????
    ; magic loop
    lda #<outer
    sta lnk + 0
    lda #>outer
    sta lnk + 1

    ; get a token, (nos)
    jsr token
  
find:
    ; load lastest link
    lda #<last
    sta wrk + 0
    lda #>last
    sta wrk + 1

@loop:

    ; update link list
    lda wrk + 0
    sta tos + 0

    ; verify is zero
    ora wrk + 1
    beq error ; end of dictionary, no more words

    ; update link list
    lda wrk + 1
    sta tos + 1
    
    ; wrk = [tos] ?
    ldy #$0
    lda (tos), y
    sta wrk
    iny
    lda (tos), y
    sta wrk + 1

    ; bypass link
    ldx #(tos - nil)
    lda #2
    jsr add2w

    ; save the flag at size byte
    lda tos + 0
    sta wrk + 0

    ; compare words
    ldy #0
@equal:
    lda (nos), y
    cmp #32         ; space ends token
    beq @done
    ; verify 
    sec
    sbc (tos), y    ; 
    and #$7F        ; 7-bit ascii, also mask flag
    bne @loop
    ; next char
    iny
    bne @equal
@done:
    
    ; update 
    tya
    ldx #(tos - nil)
    jsr add2w

    ; compile or execute
    lda wrk + 0     ; immediate ? 
    bmi @execw      ; if < 0

    lda state + 0   ; executing ?
    bne @execw

    jmp compile

@execw:

    jmp next_

;---------------------------------------------------------------------
try_:
    lda tib, y
    beq newline_    ; if \0 
    iny
    eor #32
    rts

;---------------------------------------------------------------------
; a page of 254 for buffer, but reserve 3 bytes. (but 72 is enough)
; no edits, no colapse spcs, no continue between lines

newline_:
    ; drop rts of try_
    pla
    pla

    ; leave a space
    ldy #1
@loop:  
    jsr getchar
    cmp #10         ; lf ?
    beq @endline
    ;    cmp #13     ; cr ?
    ;   beq @ends
    ;   cmp #8      ; bs ?
    ;   bne @puts
    ;   dey
    ;   jmp @loop
@puts:
    and #$7F        ; 7-bit ascii
    sta tib, y
    iny
    ;   cpy #254
    ;   beq @ends   ; leave ' \0'
    bne @loop
;
; must panic if y eq \0
; or
@endline:
    ; grace 
    lda #32
    sta tib + 0 ; start with space
    sta tib, y  ; ends with space
    iny
    lda #0      ; mark end of line
    sta tib, y
    ; reset line
    sta toin + 1

token:
    ; last position on tib
    ldy toin + 1

@skip:
    ; skip spaces
    jsr try_
    beq @skip

    ; keep start 
    dey
    sty toin + 0    

@scan:
    ; scan spaces
    jsr try_
    bne @scan

    ; keep stop 
    dey
    sty toin + 1    ; save position

    ; strlen
    sec
    tya
    sbc toin + 0

    ; place size
    dec toin + 0
    ldy toin + 0
    sta tib, y    ; store size ahead 

    ; setup token
    sty nos + 0
    lda #>tib
    sta nos + 1

    rts

;---------------------------------------------------------------------
; primitives ends with jmp link_
;

;---------------------------------------------------------------------
def_word "emit", "emit", 0
   jsr spull
   lda tos + 0
   jsr putchar
   jmp link_

;---------------------------------------------------------------------
def_word "key", "key", 0
   jsr getchar
   sta tos + 0
   jsr spush
   jmp link_

;---------------------------------------------------------------------
; [tos] = nos
def_word "!", "store", 0
storew:
    jsr spull2
    lda tos
    ldy #$0
    sta (nos), y
    lda tos + 1
    iny
    sta (nos), y
    jmp link_

;---------------------------------------------------------------------
; tos = [nos]
def_word "@", "fetch", 0
fetchw:
    jsr spull2
    ldy #$0
    lda (nos), y
    sta tos
    iny
    lda (nos), y
    sta tos + 1
    jmp used

;---------------------------------------------------------------------
def_word "s@", "statevar", 0 
    lda #<state
    sta tos + 0
    lda #>state
back:
    sta tos + 1
used:
    jsr spush
    jmp link_

;---------------------------------------------------------------------
def_word "rp@", "rpfetch", 0
    lda rte + 0
    sta tos + 0
    ;
    lda rte + 1
    jmp back

;---------------------------------------------------------------------
def_word "sp@", "spfetch", 0
    lda dta + 0
    sta tos + 0
    ;
    lda dta + 1
    jmp back

;---------------------------------------------------------------------
; ( nos tos -- nos + tos )
def_word "+", "plus", 0
    jsr spull2
    clc
    lda nos + 0
    adc tos + 0
    sta tos + 0
    ;
    lda nos + 1
    adc tos + 1
    jmp back

;---------------------------------------------------------------------
; ( nos tos -- NOT(nos AND tos) )
def_word "nand", "nand", 0
    jsr spull2
    lda nos + 0
    and tos + 0
    eor #$FF
    sta tos + 0
    ;
    lda nos + 1
    and tos + 1
    eor #$FF
    jmp back

;---------------------------------------------------------------------
def_word "0#", "zeroq", 0
    jsr spull
    ; lda tos + 1
    ora tos + 0
    beq istrue  ; is \0
isfalse:
    lda #$00
rest:
    sta tos + 0
    beq back
istrue:
    lda #$FF
    bne rest 

;---------------------------------------------------------------------
def_word "2/", "asr", 0
    jsr spull
    lsr tos + 1
    ror tos + 0
    jmp used

;---------------------------------------------------------------------
; minimal indirect thread code
; lnk must be preserved, as IP
;
def_word "exit", "exit", 0
inner:

unnest_:
    ; pull from return stack
    jsr rpull

next_:
    ; lnk = [tos]
    ldy #0
    lda (tos), y
    sta lnk
    iny
    lda (tos), y
    sta lnk + 1

    ; tos + 2
    lda #2
    jsr add2w

    ; is a primitive ? 
    lda lnk + 1
    cmp #>init    ; magic high byte page of init:
    bcc jump_

nest_:
    jsr rpush

link_:
    lda lnk + 0
    sta tos + 0
    lda lnk + 1
    sta tos + 1
    jmp next_

jump_:
    ; pull from return stack
    jsr copys
    ; zzzz
    ldx #(rte - nil)
    ldy #(lnk - nil)
    jsr spull
    jmp (tos)

;---------------------------------------------------------------------
def_word ":", "colon", 0
    ; save here
    ldy here
    sty tmp
    ldy here + 1
    sty tmp + 1

    ; update the link field with last
    ldy last
    sty here
    ldy last + 1
    sty here + 1

    ; update here
    lda #$2
    ldx #(here - nil)
    jsr add2w

    ; get the token, at nos
    jsr token

    ;copy size and name
    ldy #0
@loop:    
    lda (nos), y
    cmp #32     ; stops at space
    beq @endname
    sta (here), y
    iny
    bne @loop
@endname:

    ; update here 
    tya
    ldx #(here - nil)
    jsr add2w

    ; state is 'compile'

    lda #0
    sta state + 0
    
    jmp link_

;---------------------------------------------------------------------
def_word ";", "semis", FLAG_IMM

    ; update last

    ldy tmp
    sty last
    ldy tmp + 1
    sty last + 1

    ; state is 'interpret'
    lda #1
    sta state + 0

    ; compounds ends with 'unnest'
    lda #<unnest_
    sta tos + 0
    lda #>unnest_
    sta tos + 1

    jsr spush

    jmp compile

def_word ",", "comma",
compile:
    
    jsr spull
    lda tos
    ldy #0
    sta (here), y
    lda tos + 1
    iny 
    sta (here), y

    ; zzz here + 2
    jmp link_

;---------------------------------------------------------------------
; debug stuff
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

;---------------------------------------------------------------------
init:

