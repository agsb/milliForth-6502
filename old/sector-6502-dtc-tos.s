;----------------------------------------------------------------------
;
;   A MilliForth for 6502 
;
;   original for the 6502, by Alvaro G. S. Barcellos, 2023
;
;   https://github.com/agsb 
;   see the disclaimer file in this repo for more information.
;
;   SectorForth and MilliForth was made for x86 arch 
;   and uses full 16-bit registers 
;
;   The way at 6502 is use page zero and lots of lda/sta
;
;   Focus in size not performance.
;
;   Changes:
;
;   all data (36 cells) and return (36 cells) stacks, PAD (16 cells)
;       and TIB (80 bytes) are in same page $200, 256 bytes; 
;
;   TIB and PAD grows forward, stacks grows backwards;
;
;   no overflow or underflow checks;
;
;   the header order is LINK, SIZE+FLAG, NAME.
;
;   only IMMEDIATE flag used as $80, no hide, no compile, no extras;
;
;   As Forth-1994: FALSE is $0000 ; TRUE  is $FFFF ;
;
;   Remarks:
;
;       this code uses Minimal Indirect Thread Code, no DTC.
;
;       if PAD not used, data stack could be 52 cells; 
;
;       words must be between spaces, before and after, must;
;
;       no line wrap then use a maximum of 72 bytes of tib;
;
;       no need 'pad' at end of even names;
;
;       TIB (terminal input buffer) is like a stream;
;
;       be wise, Chuck Moore used 64 columns, obey rule 72 CPL;
;
;       only 7-bit ASCII characters, plus \n, no controls;
;
;       no multiuser, no multitask, no faster;
;
;
;   For 6502:
;
;       is a 8-bit processor with 16-bit address space;
;
;       in address space, most significant byte is the page count;
;
;       page zero and page one hardware reserved;
;
;       hardware stack not used for this Forth;
;
;   For stacks:
;
;   "when the heap moves forward, move the stack backward" 
;
;   push is 'store and decrease', pull is 'increase and fetch',
;
;   common memory model organization of Forth: 
;   [tib->...<-spt: user forth dictionary :here->pad...<-rpt]
;   then backward stacks allow to use the slack space ... 
;
;   this 6502 Forth memory model blocked in pages of 256 bytes:
;   [page0][page1][page2][core ... forth dictionary ...here...]
;   
;   at page2: 
;   [tib 40 cells>] [<spt 36 cells] [pad 16 cells>] [<rpt 36 cells]
;
;----------------------------------------------------------------------
;
; this source is for Ca65
;
; stuff for ca65 compiler
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

; header for primitives
; the entry point for dictionary is f_~name~
; the entry point for code is ~name~
.macro def_word name, label, flag
makelabel "f_", label
.ident(.sprintf("H%04X", hcount + 1)) = *
.word .ident (.sprintf ("H%04X", hcount))
hcount .set hcount + 1
.byte .strlen(name) + flag + 0 ; nice trick !
.byte name
makelabel "", label
; only need in M.I.T.C.
; .word 0
.endmacro

;----------------------------------------------------------------------
.macro shows cc
    lda #cc
    jsr putchar
.endmacro

;----------------------------------------------------------------------
.macro saveregs
    php
    pha
    tya
    pha
    txa
    pha
.endmacro

;----------------------------------------------------------------------
.macro loadregs
    pla
    tax
    pla
    tay
    pla
    plp
.endmacro

;----------------------------------------------------------------------

hcount .set 0

H0000 = 0

debug = 1

;----------------------------------------------------------------------
; alias

; cell size, two bytes, 16-bit
CELL = 2    

; highlander, immediate flag
FLAG_IMM = 1<<7

; "all in" page $200

; terminal input buffer, 80 bytes, forward
; must start at begin of a page
tib = $0200

; old tib#
tib_end = $40

; data stack, 36 cells, backward
sp0 = $98

; pad, 16 cells, forward
pad = sp0 + 1

; return stack, 36 cells, backward
rp0 = $FF

;----------------------------------------------------------------------
; no values here or must be a BSS
.segment "ZERO"

* = $E0

; default pseudo registers

nil:    .word $0 ; reserved reference offset
spt:    .word $0 ; holds data stack base,
rpt:    .word $0 ; holds return stack base

tos:    .word $0 ; top of Forth parameter data stack
lnk:    .word $0 ; link
wrk:    .word $0 ; work

snd:    .word $0 ; second
trd:    .word $0 ; third

* = $F0

; default Forth variables, order matters for HELLO.forth !

mode:   .word $0 ; state, only lsb used
toin:   .word $0 ; toin, only lsb used
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell

; future expansion
back:   .word $0 ; hold 'here while compile
base:   .word $0 ; base radix, define before use

head:   .word $0 ; pointer to heap forward
tail:   .word $0 ; pointer to heap backward

;----------------------------------------------------------------------
;.segment "ONCE" 
; no rom code

;----------------------------------------------------------------------
;.segment "VECTORS" 
; no boot code

;----------------------------------------------------------------------
.segment "CODE" 

;
; leave space for page zero, hard stack, 
; and buffer, locals, forth stacks
;
* = $300

cold:
;   clear BCD
    cld

;   set real stack
    ldx #$FF
    txs

;   enable interrupts
    cli

; link list
    lda #>f_exit
    sta last + 1
    lda #<f_exit
    sta last + 0

; next heap free cell  
    lda #>init
    sta here + 1
    lda #<init
    sta here + 0

; self pointer
    lda #>nil
    sta nil + 1
    lda #<nil
    sta nil + 0

;---------------------------------------------------------------------
quit:
; reset stacks
    ldy #>tib
    sty spt + 1
    sty rpt + 1
    ldy #<sp0
    sty spt + 0
    ldy #<rp0
    sty rpt + 0

; reset tib
    ldy #0      
; clear tib stuff
    sty tib + 0
; clear cursor
    sty toin + 0
; mode is 'interpret' == \0
    sty mode + 0
    
    .byte $2c   ; mask next two bytes, nice trick !

;---------------------------------------------------------------------
; the outer loop


; like a begin-again
parse:

    lda #>parse_
    sta wrk + 1
    lda #<parse_
    sta wrk + 0
    ldy #(wrk - nil)
    jsr rpush

    jsr okeys

; get a token
    jsr token

; load last
    lda last + 1
    sta lnk + 1
    lda last + 0
    sta lnk + 0
    
@loop:

; lsb linked list
    lda lnk + 0
    sta wrk + 0

; verify null
    ora wrk + 1
    beq error ; end of dictionary, no more words to search, quit

; msb linked list
    lda lnk + 1
    sta wrk + 1

; update link 
    ldx #(wrk - nil) ; from 
    ldy #(lnk - nil) ; into
    jsr copyfrom

; compare words
    ldy #0
; save the flag, first byte is size and flag 
    lda (wrk), y
    sta mode + 1

; compare chars
@equal:
    lda (snd), y
; space ends
    cmp #32  
    beq @done
; verify 
    sec
    sbc (wrk), y     

; clean 7-bit ascii
    and #$7F        
    bne @loop

; next char
    iny
    bne @equal

; panic if y = \0

@done:

; update
    tya
    ldx #(wrk - nil)
    jsr addwx
    
;  wherever 
    ldy #(wrk - nil)

; executing ? if == \0
    lda mode + 0   
    beq execute

; immediate ? if < \0
    lda mode + 1   
    bmi execute      

compile:

    jsr comma

; ???
    jmp next

execute:

    jsr rpush

; ???
    jmp next

parse_: 
    .word parse

;---------------------------------------------------------------------
okeys:
    lda #'O'
    jsr putchar
    lda #'K'
    jsr putchar
    lda #10
    jsr putchar
    rts

;---------------------------------------------------------------------
error:
    lda #'N'
    jsr putchar
    lda #'O'
    jsr putchar
    lda #10
    jsr putchar
    jmp quit

;---------------------------------------------------------------------
try:
    lda tib, y
    beq newline    ; if \0 
    iny
    eor #' '
    rts

;---------------------------------------------------------------------
newline:
; drop rts of try
    pla
    pla

getline:
; leave a space
    ldy #1
@loop:  
    jsr getchar
;
; unix \n
;
@key_linefeed:
    cmp #10 ; line feed
    beq @ends

@key_backspace:    
    cmp #8  ; back space
    bne @key_cancel
    dey
    jmp @loop
@key_cancel:    
    cmp #24 ; cancel
    beq getline

@puts:
; 7-bit ascii only
    and #$7F      
    sta tib, y
    iny
    cmp tib_end
    bne @loop

; clear all if y eq \0
@ends:
; grace \b
    lda #32
    sta tib + 0 ; start with space
    sta tib, y  ; ends with space
; mark eot with \0
    iny
    lda #0
    sta tib, y
; start it
    sta toin + 0

;---------------------------------------------------------------------
; 
token:
; last position on tib
    ldy toin + 0
@skip:
; skip spaces
    jsr try
    beq @skip
; keep start 
    dey
    sty toin + 1    
@scan:
; scan spaces
    jsr try
    bne @scan
; keep stop 
    dey
    sty toin + 0 
@done:
; sizeof
    tya
    sec
    sbc toin + 1
; keep it
    ldy toin + 1
    dey
    sta tib, y  ; store size ahead, as counted string 

; setup token, pass pointer
    sty snd + 0
    lda #>tib
    sta snd + 1

    rts

;---------------------------------------------------------------------
; add a byte to a word in page zero. offset by X
; incwx:
;   lda #01
addwx:
    clc
    adc nil + 0, x
    sta nil + 0, x
    bcc @ends
    inc nil + 1, x
@ends:
    rts

;---------------------------------------------------------------------
; increment a word in page zero. offset by X
incwx:
    inc nil + 0, x
    bne @ends
    inc nil + 1, x
@ends:
    rts

;---------------------------------------------------------------------
; decrement a word in page zero. offset by X
decwx:
    lda nil + 0, x
    bne @ends
    dec nil + 1, x
@ends:
    dec nil + 0, x
    rts

;---------------------------------------------------------------------
; push a cell 
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
rpush:
    ldx #(rpt - nil)
    .byte $2c   ; mask next two bytes, nice trick !

spush:
    ldx #(spt - nil)

;---------------------------------------------------------------------
; classic stack backwards
push:
    lda nil + 1, y
    sta (nil, x)
    jsr decwx
    lda nil + 0, y
    sta (nil, x)
    jsr decwx
    rts ; extra ***

;---------------------------------------------------------------------
; pull a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
rpull:
    ldx #(rpt - nil)
    .byte $2c   ; mask next two bytes, nice trick !

spull:
    ldx #(spt - nil)

;---------------------------------------------------------------------
; classic stack backwards
pull:
    jsr incwx
    lda (nil, x)
    sta nil + 0, y
    jsr incwx
    lda (nil, x)
    sta nil + 1, y
    rts

;---------------------------------------------------------------------
; classic heap moves always forward
;
comma: 
    ldx #(here - nil)

copyinto:
    lda nil + 0, y
    sta (nil, x)
    jsr incwx
    lda nil + 1, y
    sta (nil, x)
    jsr incwx
    rts ; extra ***

copyfrom:
    lda (nil, x)
    sta nil + 0, y
    jsr incwx
    lda (nil, x)
    sta nil + 1, y
    jsr incwx
    rts ; extra ***

;---------------------------------------------------------------------
; for lib6502  emulator
; always does echo
getchar:
    lda $E000

putchar:
    sta $E000

    .if debug

; EOF ?

    cmp #$FF
    bne rets

; return (0)

    lda #'$'
    jsr putchar
    lda #'$'
    jsr putchar
    lda #'$'
    jsr putchar

    jmp $0000

    .endif

rets:
    rts

;---------------------------------------------------------------------
;
spullwrk:
    ldy #(wrk - nil)
    .byte $2c   ; mask next two bytes, nice trick !

spulltos:
    ldy #(tos - nil)
    jmp spull

spushtos:
    ldy #(tos - nil)
    jmp spush

;---------------------------------------------------------------------
; primitives, a address, c byte ascii, w signed word, u unsigned word 
;
; ( -- c )
def_word "key", "key", 0
    jsr getchar
    sta tos + 0
    jmp next
    
;---------------------------------------------------------------------
; ( c -- )
def_word "emit", "emit", 0
    lda tos + 0
    jsr putchar
    jsr spulltos
    jmp next

;---------------------------------------------------------------------
; shift right
; ( w -- w/2 )
def_word "2/", "asr", 0
    lsr tos + 1
    ror tos + 0
    jmp next

;---------------------------------------------------------------------
; ( w2 w1 -- w1 + w2 ) 
def_word "+", "plus", 0
    jsr spullwrk
    clc
    lda tos + 0
    adc wrk + 0
    sta tos + 0
    lda tos + 1
    adc wrk + 1
    sta tos + 1
    jmp next

;---------------------------------------------------------------------
; ( w2 w1 -- NOT(w1 AND w2) )
def_word "nand", "nand", 0
    jsr spullwrk
    lda tos + 0
    and wrk + 0
    eor #$FF
    sta tos + 0
    lda tos + 1
    and wrk + 1
    eor #$FF
    sta tos + 1
    jmp next

;---------------------------------------------------------------------
; ( 0 -- $FFFF) | ( n -- $0000)
def_word "0#", "zeroq", 0
; lda tos + 1, implicit
    ora tos + 0
    beq istrue  ; is \0
isfalse:
    lda #$00
    .byte $2c   ; mask next two bytes, nice trick !
istrue:
    lda #$FF
rest:
    sta tos + 0
    sta tos + 1
    jmp next

;---------------------------------------------------------------------
; ( w a -- ) ; [a] = w
def_word "!", "store", 0
storew:
    jsr spullwrk
    ldx #(tos - nil) 
    ldy #(wrk - nil) 
    jsr copyinto
    jsr spulltos
    jmp next

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    ldx #(tos - nil)
    ldy #(wrk - nil)
    jsr copyfrom
    lda wrk + 0
    sta tos + 0
    lda wrk + 1
    sta tos + 1
    jmp next

;---------------------------------------------------------------------
; ( -- rp )
def_word "rp@", "rpat", 0
    ldy #(rpt - nil)
    jmp both

;---------------------------------------------------------------------
; ( -- sp )
def_word "sp@", "spat", 0
    ldy #(spt - nil)
    jmp both

;---------------------------------------------------------------------
; ( -- mode )
def_word "s@", "stat", 0 
    ldy #(mode - nil)

;---------------------------------------------------------------------
; generic 
;
both:
    jsr spushtos
    lda nil + 0, y
    sta tos + 0
    lda nil + 1, y
    sta tos + 1
    jmp next

;---------------------------------------------------------------------
def_word ";", "semis", FLAG_IMM
; update last, panic if colon not lead elsewhere 
    lda back + 0 
    sta last + 0
    lda back + 1 
    sta last + 1
; mode is 'interpret'
    lda #0
    sta mode + 0

; compound words ends
    ldy #0

    lda #4C ; isa code for jmp
    sta (here), y
    iny

    lda #<exit
    sta (here), y
    iny
    
    lda #>exit
    sta (here), y
    iny

    jmp uphere

;---------------------------------------------------------------------
def_word ":", "colon", 0
; save here, panic if semis not follow elsewhere
    lda here + 0
    sta back + 0 
    lda here + 1
    sta back + 1 
; mode is 'compile'
    lda #1
    sta mode + 0

create:
; copy last into (here)
    ldy #(last - nil)
    jsr comma

; get token
    jsr token

; copy size and name
    ldy #0
@loop:    
    lda (snd), y
    cmp #32    ; stops at space
    beq ends
    sta (here), y
    iny
    bne @loop

;---------------------------------------------------------------------
; compound words start 
    ldy #0
    
    lda #4C ; isa code for jmp
    sta (here), y
    iny

    lda #<docol
    sta (here), y
    iny
    
    lda #>docol
    sta (here), y
    iny

uphere:
; update here 
    tya
    ldx #(here - nil)
    jsr addwx

    jmp unnest

;---------------------------------------------------------------------
; NON classic direct thread code
;   lnk is IP, wrk is W
;
; for reference: nest is docol, unnest is semis;
;
; using MITC, minimum indirect thread code
;
;---------------------------------------------------------------------
; drop top of return stack
def_word "exit", "exit", 0
    lda #(rpt - nil)
    jsr incwx
    jsr incwx
    ; jmp unnest

;---------------------------------------------------------------------
; inner interpreter

unnest:
; pull, lnk = *(rpt), rpt += 2 
    ldy #(lnk - nil)
    jsr rpull

next:
; wrk = (lnk) ; lnk = lnk + 2
    ldy #(wrk - nil)
    ldx #(lnk - nil)
    jsr copyfrom

    jmp (wrk)

nest:
; push, *rp = lnk, rp -=2
    ldy #(lnk - nil)
    jsr rpush

link:
    lda wrk + 0
    sta lnk + 0
    lda wrk + 1
    sta lnk + 1
    
    jmp next

; historical JMP @(W)+
; but wrk is NULL
jump:
    jmp (lnk)

ends:

;---------------------------------------------------------------------

; debug stuff
.if 0

;----------------------------------------------------------------------
; dumps terminal input buffer
showtib:
    lda #'_'
    jsr putchar
    ldy #0
    @loop:
    lda tib, y
    beq @done
    jsr putchar
    iny
    bne @loop
    @done:
    lda #'_'
    jsr putchar
    rts

;----------------------------------------------------------------------
; print a 8-bit HEX
puthex:
    pha
    lsr
    ror
    ror
    ror
    jsr @conv
    pla
@conv:
    and #$0F
    clc
    ora #$30
    cmp #$3A
    bcc @ends
    adc #$06
@ends:
    jmp putchar

;----------------------------------------------------------------------
.endif

; for anything above is not a primitive
.align $100

init:   


