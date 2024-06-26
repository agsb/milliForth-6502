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
; need for M.I.T.C.
.word 0
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
; note: getline, token, skip, scan depends on page boundary
tib = $0200

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

lnk:    .word $0 ; link
wrk:    .word $0 ; work

fst:    .word $0 ; first
snd:    .word $0 ; second
trd:    .word $0 ; third

; * = $F0

; default Forth variables, order matters for HELLO.forth !

mode:   .word $0 ; state, only lsb used
toin:   .word $0 ; toin, only lsb used
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell

; future expansion
back:   .word $0 ; hold here while compile
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

; parse is a headless primitive, need a 0x0
parse_: 
    .word 0

; like a begin-again
parse:

    lda #>parse_
    sta fst + 1
    lda #<parse_
    sta fst + 0
    ldy #(fst - nil)
    jsr rpush

; get a token
    jsr token

    jsr showdic

    jsr dumpnil

find:
; load last
    lda last + 1
    sta trd + 1
    lda last + 0
    sta trd + 0
    
@loop:
; lsb linked list
    lda trd + 0
    sta fst + 0

; verify null
    ora trd + 1
    beq mirror ; end of dictionary, no more words to search, quit

; msb linked list
    lda trd + 1
    sta fst + 1

; update link 
    ldx #(fst - nil) ; from 
    ldy #(trd - nil) ; into
    jsr copyfrom

; compare words
    ldy #0
; save the flag, first byte is size and flag 
    lda (fst), y
    sta mode + 1

; compare chars
@equal:
    lda (snd), y
; space ends
    cmp #32  
    beq @done
; verify 
    sec
    sbc (fst), y     

; clean 7-bit ascii
    and #$7F        
    bne @loop

; next char
    iny
    bne @equal

@done:
; update fst
    tya
    ldx #(fst - nil)
    jsr addwx
    
eval:
;  wherever 
    ldy #(fst - nil)

; executing ? if == \0
    lda mode + 0   
    beq execute

; immediate ? if < \0
    lda mode + 1   
    bmi execute      

compile:
    .if debug
    lda #'C'
    jsr putchar
    .endif

    ; jsr dumpnil

    jsr comma

    jmp unnest

execute:
    .if debug
    lda #'E'
    jsr putchar
    .endif

;  wherever two

    ; jsr dumpnil

    jsr rpush

    jmp unnest

;---------------------------------------------------------------------
okeys:
    lda #'O'
    jsr putchar
    lda #'K'
    jsr putchar
    lda #10
    jsr putchar
    jmp parse

;---------------------------------------------------------------------
mirror:
    lda #'Z'
    jsr putchar
    lda #'Z'
    jsr putchar
    lda #10
    jsr putchar
    jmp quit

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
    beq getline    ; if \0 
    iny
    eor #' '
    rts

;---------------------------------------------------------------------
getline:
; drop rts of try
    pla
    pla

    lda #10
    jsr putchar
    lda #'_'
    jsr putchar

; leave a space
    ldy #1
@loop:  
    jsr getchar
;
; unix \n
;
    cmp #10
    beq @ends
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
; in place. TIB changed every token
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
    sta toin + 1
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
spull2:
    ldy #(snd - nil)
    jsr spull

spull1:
    ldy #(fst - nil)
    jmp spull

;---------------------------------------------------------------------
; primitives, a address, c byte ascii, w signed word, u unsigned word 
;
; ( -- c )
def_word "key", "key", 0
    jsr getchar
    sta fst + 0
    jmp keep
    
;---------------------------------------------------------------------
; ( c -- )
def_word "emit", "emit", 0
    jsr spull1
    lda fst + 0
    jsr putchar
    jmp unnest

;---------------------------------------------------------------------
; shift right
; ( w -- w/2 )
def_word "2/", "asr", 0
    jsr spull1
    lsr fst + 1
    ror fst + 0
    jmp keep

;---------------------------------------------------------------------
; ( w2 w1 -- w1 + w2 ) 
def_word "+", "plus", 0
    jsr spull2
    clc
    lda snd + 0
    adc fst + 0
    sta fst + 0
    lda snd + 1
    adc fst + 1
    jmp only

;---------------------------------------------------------------------
; ( w2 w1 -- NOT(w1 AND w2) )
def_word "nand", "nand", 0
    jsr spull2
    lda snd + 0
    and fst + 0
    eor #$FF
    sta fst + 0
    lda snd + 1
    and fst + 1
    eor #$FF
    jmp only

;---------------------------------------------------------------------
; ( 0 -- $FFFF) | ( n -- $0000)
def_word "0#", "zeroq", 0
    jsr spull1
; lda fst + 1, implicit
    ora fst + 0
    beq istrue  ; is \0
isfalse:
    lda #$00
    .byte $2c   ; mask next two bytes, nice trick !
istrue:
    lda #$FF
rest:
    sta fst + 0
    jmp only

;---------------------------------------------------------------------
; ( w a -- ) ; [a] = w
def_word "!", "store", 0
storew:
    jsr spull2
    ldx #(snd - nil) 
    ldy #(fst - nil) 
    jsr copyinto
    jmp unnest

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    jsr spull1
    ldx #(fst - nil)
    ldy #(snd - nil)
    jsr copyfrom
    jmp this

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
    lda nil + 0, y
    sta fst + 0
    lda nil + 1, y
only:
    sta fst + 1
keep:
    ldy #(fst - nil)
this:
    jsr spush
    jmp unnest

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

; compound words must ends with exit
    lda #<exit
    sta fst + 0
    lda #>exit
    sta fst + 1
    
    ; jmp compile

    lda #'K'
    jsr putchar

    ldy #(fst - nil)
    jsr comma

    lda last+0
    sta fst+0
    lda last+1
    sta fst+1

    jsr showord

    jmp unnest

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
    beq @ends
    sta (here), y
    iny
    bne @loop
@ends:
; update here 
    tya
    ldx #(here - nil)
    jsr addwx

; done
    jmp unnest

;---------------------------------------------------------------------
; NON classic direct thread code
;   lnk is IP, wrk is W
;
; for reference: nest is docol, unnest is semis;
;
; using MITC, minimum indirect thread code
;
def_word "exit", "exit", 0
inner:

unnest:
    .if debug
    lda #'U'
    jsr putchar
    .endif

; pull, lnk = *(rpt), rpt += 2 
    ldy #(lnk - nil)
    jsr rpull

next:
; wrk = (lnk) ; lnk = lnk + 2
    ldy #(wrk - nil)
    ldx #(lnk - nil)
    jsr copyfrom

pick:
; minimal test, no words at page 0
    lda wrk + 1
    beq jump

nest:
    .if debug
    lda #'N'
    jsr putchar
    .endif

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
; wrk is NULL
jump:
    .if debug
    lda #'J'
    jsr putchar
    .endif

    lda lnk+1
    jsr puthex

    lda lnk+0
    jsr puthex

    jmp (lnk)

ends:

;---------------------------------------------------------------------

; debug stuff
.if debug

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
savenils:
    ldy #0
@loop:
    lda $00E0, y
    sta $00C0, y
    iny
    cpy #16
    bne @loop
    rts

;----------------------------------------------------------------------
loadnils:
    ldy #0
@loop:
    lda $00C0, y
    sta $00E0, y
    iny
    cpy #16
    bne @loop
    rts

;----------------------------------------------------------------------
erro:
    pha
    lda #'?'
    jsr putchar
    lda #'?'
    jsr putchar
    lda #10
    jsr putchar
    pla
    rts

okey:
    pha
    lda #'O'
    jsr putchar
    lda #'K'
    jsr putchar
    lda #10
    jsr putchar
    pla
    rts

;---------------------------------------------------------------------
showdic:

    saveregs

    jsr savenils

    lda #10
    jsr putchar

    lda #'{'
    jsr putchar

; load lastest link
    lda last + 0
    sta trd + 0
    lda last + 1
    sta trd + 1

@loop:

; update link list
    lda trd + 0
    sta fst + 0
    
; verify is zero
    ora trd + 1
    beq @ends ; end of dictionary, no more words to search, quit

; update link list
    lda trd + 1
    sta fst + 1

    lda #10
    jsr putchar

    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex

; get that link, wrk = [fst]
    ldx #(fst - nil) ; from 
    ldy #(trd - nil) ; into
    jsr copyfrom

    lda #' '
    jsr putchar
    
    ldy #0
    lda (fst), y
    jsr puthex

    lda (fst), y
    and #$7F
    tax

    lda #' '
    jsr putchar
    
@loopa:
    iny
    lda (fst), y
    jsr putchar
    dex
    bne @loopa

    lda #' '
    jsr putchar
    
    iny
    tya
    ldx #(fst - nil)
    jsr addwx

    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex

    ldx #(fst - nil) ; from 
    ldy #(snd - nil) ; into
    jsr copyfrom

    lda snd + 0
    ora snd + 1
    beq @primitive

@compound:
    
@primitive:
    jmp @loop

@ends:

    lda #10
    jsr putchar

    lda #'}'
    jsr putchar

    jsr loadnils

    loadregs

    rts

;----------------------------------------------------------------------
; show mode
showsts:

    lda #' '
    jsr putchar

    lda mode + 1
    jsr puthex

    lda mode + 0
    jsr puthex

    rts

;----------------------------------------------------------------------
; show here
showhere:

    lda #' '
    jsr putchar

    lda here + 1
    jsr puthex

    lda here + 0
    jsr puthex

    rts

;----------------------------------------------------------------------
; show last
showlast:

    lda #' '
    jsr putchar

    lda last + 1
    jsr puthex

    lda last + 0
    jsr puthex

    rts

;----------------------------------------------------------------------
; show lst
showfst:

    lda #' '
    jsr putchar

    lda fst + 1
    jsr puthex

    lda fst + 0
    jsr puthex

    rts

;----------------------------------------------------------------------
showref:

    lda #' '
    jsr putchar
    
; view
    lda (fst), y
    sta wrk + 0
    iny
    lda (fst), y
    sta wrk + 1
    iny

; show
    lda wrk + 1
    jsr puthex
    lda wrk + 0
    jsr puthex

    rts

;----------------------------------------------------------------------
showname:

    lda #' '
    jsr putchar
    
    lda (fst), y
    pha
    jsr puthex
    
    lda #' '
    jsr putchar
    
    pla
    and #$7F
    tax

@loop:
    iny
    lda (fst),y
    jsr putchar
    dex
    bne @loop

    rts

;----------------------------------------------------------------------
; show compiled list address
; all compound words ends with exit:
showlst:

@loop:
    lda #' '
    jsr putchar

    jsr showref

; stop
    lda wrk + 0
    cmp #<exit
    bne @loop
    lda wrk + 1
    cmp #>exit
    bne @loop

@ends:

    rts

;----------------------------------------------------------------------
showbck:

; search backwards

    ldx #(fst - nil)

@loop:
    jsr decwx
    lda (nil, x)
    and #$7F
    cmp #' '
    bpl @loop

    jsr decwx
    jsr decwx
    
    rts

;----------------------------------------------------------------------
showord:

    saveregs

    jsr savenils

    lda #10
    jsr putchar

    lda #'('
    jsr putchar

    ldy #0

    jsr showfst

    jsr showref

    jsr showname

; show list

    lda (fst), y
    iny
    ora (fst), y
    beq @ends
    
; only compiled
    
    jsr showlst

@ends:

    lda #')'
    jsr putchar

    ; jsr dump
    
    ; jsr dumps

    ; jsr dumpr

    jsr loadnils

    loadregs

    rts


;----------------------------------------------------------------------

showstk:

    lda #' '
    jsr putchar

    tsx
    inx
    inx
    txa
    jsr puthex

    rts

;----------------------------------------------------------------------
dumpnil:

    php
    pha
    tya
    pha
    txa
    pha

    lda #10
    jsr putchar
    lda #'='
    jsr putchar

    ldy #0
@loop:
    lda #' '
    jsr putchar
    lda nil+1, y
    jsr puthex
    lda nil+0, y
    jsr puthex
    iny
    iny

    cpy #16
    bne @byes
    lda #' '
    jsr putchar
    lda #'_'
    jsr putchar

@byes:    
    cpy #32
    bne @loop
    
    lda #10
    jsr putchar

    pla
    tax
    pla
    tay
    pla
    plp

    rts

;----------------------------------------------------------------------
dumpext:

    pha

    lda #10
    jsr putchar

    lda #'{'
    jsr putchar

    lda #' '
    jsr putchar
    lda #'S'
    jsr putchar
    lda #'='
    jsr putchar
    lda spt + 1
    jsr puthex
    lda spt + 0
    jsr puthex
    
    lda #' '
    jsr putchar
    lda #'R'
    jsr putchar
    lda #'='
    jsr putchar
    lda rpt + 1
    jsr puthex
    lda rpt + 0
    jsr puthex

    lda #' '
    jsr putchar
    lda #'L'
    jsr putchar
    lda #'='
    jsr putchar
    lda lnk + 1
    jsr puthex
    lda lnk + 0
    jsr puthex

    lda #' '
    jsr putchar
    lda #'W'
    jsr putchar
    lda #'='
    jsr putchar
    lda wrk + 1
    jsr puthex
    lda wrk + 0
    jsr puthex

    lda #' '
    jsr putchar
    lda #'T'
    jsr putchar
    lda #'='
    jsr putchar
    lda last + 1
    jsr puthex
    lda last + 0
    jsr puthex

    lda #' '
    jsr putchar
    lda #'H'
    jsr putchar
    lda #'='
    jsr putchar
    lda here + 1
    jsr puthex
    lda here + 0
    jsr puthex

    lda #'}'
    jsr putchar

    lda #10
    jsr putchar

    pla

    rts

;----------------------------------------------------------------------
; show hard stack
dumph:

    php
    pha
    txa
    pha
    tya
    pha

    tsx

    lda #'S'
    jsr putchar
    txa
    jsr puthex

    lda #' '
    jsr putchar

    inx
    inx
    inx
    inx

@loop:

    txa
    jsr puthex
    lda #':'
    jsr putchar
    lda $100, x
    jsr puthex
    lda #' '
    jsr putchar
    inx
    bne @loop

    pla
    tay
    pla
    tax
    pla
    plp

    rts
    
;----------------------------------------------------------------------
dumpr:
    
    lda #10
    jsr putchar

    lda #'R'
    jsr putchar

    lda #'='
    jsr putchar

    sec
    lda #rp0
    sbc rpt + 0
    beq @ends
    tax

    jsr puthex

    ldy #0

@loop:
    lda #' '
    jsr putchar

    iny
    lda (rpt), y
    jsr puthex

    dex
    bne @loop

@ends:

    rts

;----------------------------------------------------------------------
dumps:
    
    lda #10
    jsr putchar

    lda #'S'
    jsr putchar

    lda #'='
    jsr putchar

    sec
    lda #sp0
    sbc spt + 0
    beq @ends
    tax

    jsr puthex
    
    ldy #0

@loop:
    lda #' '
    jsr putchar

    iny
    lda spt, y
    jsr puthex

    dex
    bne @loop

@ends:

    rts

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


