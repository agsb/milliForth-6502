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
;   6502 is a byte processor, no need 'pad' at end of even names
;
;   As Forth-1994: ; FALSE is $0000 ; TRUE  is $FFFF ;
;
;----------------------------------------------------------------------
; for ca65 
;
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

; cell size
CELL   =  2     ; 16 bits

; highlander
FLAG_IMM  =  1<<7

; stack size
SIZES  = $100

; terminal input buffer, 80 bytes forward
tib = $0200
; .res SIZES, $0   

; locals, 16 words forward
lcs = $0250

; data stack base, 36 words deep backward
dsb = $02DC 
; .res SIZES, $0

; return stack base, 36 words deep backward
rsb = $02FF
; .res SIZES, $0

;----------------------------------------------------------------------
.segment "ZERO"

* = $E0
; default pseudo registers
nil:    .word $0 ; reserved reference offset
dta:    .word $0 ; holds data stack base,
rte:    .word $0 ; holds return stack base
lnk:    .word $0 ; link return

; default Forth pseudo registers
tos:    .word $0 ; tos first at top of stack
nos:    .word $0 ; nos second at top of stack
wrk:    .word $0 ; work holder
tmp:    .word $0 ; temporary holder

; default Forth variables
state:  .word $0 ; state, only lsb used
toin:   .word $0 ; toin, only lsb used
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell

;----------------------------------------------------------------------
;.segment "ONCE" 
; no rom code

;----------------------------------------------------------------------
;.segment "VECTORS" 
; no boot code

;----------------------------------------------------------------------
.segment "CODE" 
;
; leave space for page zero, hard stack, buffer and forth stacks
;
* = $300

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
    
    ; self pointer
    lda #<nil
    sta nil + 0
    lda #>nil
    sta nil + 1

    ; stacks MSBs
    ldy #>rte
    sty dta + 1
    sty rte + 1

;---------------------------------------------------------------------
error:

    lda #13
    jsr putchar

;---------------------------------------------------------------------
quit:

    ; reset stacks
    ldy #$DC
    sty dta + 0
    ldy #$FF
    sty rte + 0

    ; clear tib stuff
    iny
    sty toin + 0
    sty tib + 0

    ; state is 'interpret' == 0
    sty state + 0

;---------------------------------------------------------------------
; the outer loop
outer:

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
    beq error ; end of dictionary, no more words to search, quit

    ; update link list
    lda wrk + 1
    sta tos + 1
    
    ; get that link, wrk = [tos]
    ; bypass the link tos+2
    ldx #(tos - nil) ; from 
    ldy #(wrk - nil) ; into
    jsr pull

    ; save the flag at size byte
    lda tos + 0
    pha

    ; compare words
    ldy #0
@equal:
    lda (nos), y
    ; space ends token
    cmp #32  
    beq @done
    ; verify 
    sec
    sbc (tos), y     
    ; 7-bit ascii, also mask flag
    and #$7F        
    bne @loop
    ; next char
    iny
    bne @equal
@done:
    
    ; update tos
    tya
    ; implict ldx #(tos - nil)
    jsr addw

    ; compile or execute
    pla             ; immediate ? 
    bmi @execw      ; if < 0 bit 7 set

    lda state + 0   ; executing ?
    bne @execw

; zzzz how does return ? need a branch or jump to outer

@compw:

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
    ;
    ; unix like
    ;
    cmp #10         ; \n ?
    beq @endline
    ;
    ; dos like
    ;
    ;   cmp #13     ; \r ?
    ;   beq @endline
    ;
    ; clear to start of line
    ;   cmp #15     ; \u ?
    ;   beq 
    ;   jmp @fill
    ;
@puts:
    and #$7F        ; 7-bit ascii
    sta tib, y
    iny
    bne @loop
; must panic if y eq \0 ?
; or
@endline:
    ; grace 
    lda #32
    sta tib + 0 ; start with space
    sta tib, y  ; ends with space
    ; and end of line
    lda #0
    iny
    sta tib, y
    sta toin + 0

;---------------------------------------------------------------------
; 
; toin + 0 effective offset
; toin + 1 scratch for size
;
token:
    ; last position on tib
    ldy toin + 0

@skip:
    ; skip spaces
    jsr try_
    beq @skip

    ; keep start 
    dey
    sty toin + 1    

@scan:
    ; scan spaces
    jsr try_
    bne @scan

    ; keep stop 
    dey
    sty toin + 0 

    ; strlen
    sec
    tya
    sbc toin + 1

    ; keep size
    ldy toin + 1
    dey
    sta tib, y  ; store size ahead 

    ; setup token, pass pointer
    sty nos + 0
    lda #>tib
    sta nos + 1

    rts

;---------------------------------------------------------------------
; increment a word in page zero, offset by X
incw:
    lda #1
; add a byte to a word in page zero. offset by X
addw:
    clc
    adc nil + 0, x
    sta nil + 0, x
    bcc @noinc
    inc nil + 1, x
@noinc:
    rts

;---------------------------------------------------------------------
; decrement a word in page zero. offset by X
decw:
    lda nil + 0, x
    bne @nodec
    dec nil + 1, x
@nodec:
    dec nil + 0, x
    rts

;---------------------------------------------------------------------
; pull a word 
; from a page zero address indexed by X
; into a absolute page zero address indexed by y
spull2:
    jsr tspull 

nspull:
    ldy #(nos - nil)
    .byte $2c   ; mask ldy, nice trick !

; pull from data stack
tspull:
    ldy #(tos - nil)

; pull from data stack
spull:
    ldx #(dta - nil)

pull:
    lda (nil, x)    
    sta nil + 0, y   
    jsr incw        
    lda (nil, x)    
    sta nil + 1, y  
    jmp incw 

; pull from return stack
rpull:
    ldx #(rte - nil)
    jmp pull

;---------------------------------------------------------------------
; push a word 
; from an absolute page zero address indexed by Y
; into a page zero address indexed by X
rpush:
    ldx #(rte - nil)
    .byte $2c   ; mask ldx, nice trick !
spush:
    ldx #(dta - nil)

tpush:
    ldy #(tos - nil)

push:
    jsr decw
    lda nil + 1, y
    sta (nil, x)
    jsr decw
    lda nil + 0, y
    sta (nil, x)
    rts 

;---------------------------------------------------------------------
; for lib6502  emulator
; does echo
getchar:
    lda $E000

putchar:
    sta $E000

    rts

;---------------------------------------------------------------------
; all primitives ends with jmp link_
;

;---------------------------------------------------------------------
def_word "emit", "emit", 0
   jsr tspull
   lda tos + 0
   jsr putchar
   jmp link_

;---------------------------------------------------------------------
def_word "key", "key", 0
   jsr getchar
   sta tos + 0
   jmp used

;---------------------------------------------------------------------
; [tos] = nos
def_word "!", "store", 0
storew:
    jsr spull2
    ldx #(tos + 2 - nil) ; push starts with decw, then it works
    ldy #(nos - nil)
    jsr push
    jmp link_

;---------------------------------------------------------------------
; tos = [nos]
def_word "@", "fetch", 0
fetchw:
    jsr nspull
    ldx #(nos - nil)
    ldy #(tos - nil)
    jsr pull
    jmp used

;---------------------------------------------------------------------
copy:
    lda nil + 0, x
    sta tos + 0
    lda nil + 1, x
back:
    sta tos + 1
used:
    jsr spush
    jmp link_

;---------------------------------------------------------------------
def_word "s@", "statevar", 0 
    ldx #(state - nil)
    jmp copy

;---------------------------------------------------------------------
def_word "rp@", "rpfetch", 0
    ldx #(rte - nil)
    jmp copy

;---------------------------------------------------------------------
def_word "sp@", "spfetch", 0
    ldx #(dta - nil)
    jmp copy

;---------------------------------------------------------------------
; ( nos tos -- nos + tos )
def_word "+", "plus", 0
    jsr spull2
    clc
    lda nos + 0
    adc tos + 0
    sta tos + 0
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
    lda nos + 1
    and tos + 1
    eor #$FF
    jmp back

;---------------------------------------------------------------------
; test if tos == \0
def_word "0=", "zeroq", 0
    jsr tspull
    ; lda tos + 1, implicit
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
; shift right
def_word "2/", "asr", 0
    jsr tspull
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
    ; pull tos = [rte], rte+2
    ldy #(tos - nil)
    jsr rpull

next_:
    ; lnk = [tos], tos+2
    ldy #(lnk - nil)
    ldx #(tos - nil)
    jsr pull

    ; is a primitive ? 
    lda lnk + 1
    cmp #>init    ; magic high byte page of init:
    bcc jump_

nest_:
    ; push into return stack
    jsr rpush

link_:
    lda lnk + 0
    sta tos + 0
    lda lnk + 1
    sta tos + 1
    jmp next_

jump_:
    ; pull from return stack
    ldy #(lnk - nil)
    jsr rpull
    jmp (tos)

;---------------------------------------------------------------------
def_word ":", "colon", 0
    ; save here 
    lda here + 0
    pha
    lda here + 1
    pha

    ; save link
    lda last + 0
    sta here + 0
    lda last + 1
    sta here + 1

    ; setup here
    ldx #(here - nil)

    ; update here
    lda #$2
    jsr addw

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
    ; implicit ldx #(here - nil)
    jsr addw

    ; state is 'compile'

    lda #1
    sta state + 0
    
    jmp link_

;---------------------------------------------------------------------
def_word ";", "semis", FLAG_IMM

    ; update last

    pla
    sta last + 1
    pla
    sta last + 0

    ; state is 'interpret'
    lda #0
    sta state + 0

    ; compounds words must ends with 'unnest'
    lda #<unnest_
    sta tos + 0
    lda #>unnest_
    sta tos + 1

    ; jsr spush

    ; jmp compile

    ; def_word ",", "comma",

compile:
    
    ; jsr spull

    ldx #(here - nil)
    jsr tpush

    jmp link_

;---------------------------------------------------------------------
ends:

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

.align $100
; for anything above is not a primitive
init:   


