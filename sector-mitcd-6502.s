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
;
;   all tib (80 bytes), locals (16 cells), data (36 cells) and 
;       return (36 cells) stacks are in page $200; 
;
;   tib and locals grows forward, stacks grows backwards;
;
;   none overflow or underflow checks;
;
;   only immediate flag used as $80, no more flags;
;
;   As Forth-1994: FALSE is $0000 and TRUE is $FFFF ;
;
;   Remarks:
;
;   this code uses Minimal Indirect Thread Code, no DTC.
;
;   terminal input buffer (tib) is like a stream; 
;
;   be wise, Chuck Moore used 64 columns, rule 72 cpl is mandatory;
;
;   words must be between spaces, begin and end spaces are wise;
;
;   only 7-bit ASCII characters, plus \n, no controls, maybe \b later;
;
;   better use by reading a text file source;
;
;   if locals not used, data stack could be 50 cells; 
;   
;   no multiuser, no multitask, no faster;

;   For 6502:
;
;   * hardware stack (page $100) not used as forth stack, free for use;
;
;   * 6502 is a byte processor, no need 'pad' at end of even names;
; 
;   * push is 'store and increase', pull is 'decrease and fetch',
;
;   For stacks:
;
;   stack operations slightly different: works forwards.
;
;   push is 'store and increase', pull is 'decrease and fetch',
;
;   why ? this way could use push for update here without extra code. 
;
;   best reason to use a backward stack is when it can grows thru 
;       end of another area.
;
;   common memory model organization of Forth: 
;   [tib->...<-spt: user forth dictionary :here->...<-rpt]
;   then backward stacks allow to use the slack space ... 
;
;   this 6502 Forth memory model blocked in pages of 256 bytes:
;   [page0][page1][page2][core ... forth dictionary ...here...]
;   
;   at page2, no rush over then stacks can go forwards:
;   [tib 40 cells][locals 16 cells][spt 36 cells][rpt 36 cells]

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
tib = $0200

; locals, 16 cells, forward
lcs = $50

; strange ? is a 8-bit system, look at push code ;)

; data stack, 36 cells, backward
sp0 = $B9

; strange ? is a 8-bit system, look at push code ;)

; return stack, 36 cells, backward
rp0 = $00

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

; default Forth variables
state:  .word $0 ; state, only lsb used
last:   .word $0 ; last link cell

here:   .word $0 ; next free cell
back:   .word $0 ; here while compile

toin:   .word $0 ; toin, only lsb used
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

;   enable interrupts
    cli

;   set real stack
    ldx #$FF
    txs

; link list
    lda #>f_exit
    sta last + 1
    lda #<f_exit
    sta last + 0

; next free memory cell, must be $page aligned 
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
    iny             ; magics !
    sty rpt + 1
    ldy #<sp0
    sty spt + 0
    ldy #<rp0
    sty rpt + 0

    ; y == \0
; clear tib stuff
    sty tib + 0
; clear cursor
    sty toin + 0
; state is 'interpret' == \0
    sty state + 0

;---------------------------------------------------------------------
; the outer loop
outer:

; begin
parse:
; get a token
    jsr token

find:
; load last
    lda last + 0
    sta trd + 0
    lda last + 1
    sta trd + 1

@loop:
; linked list
    lda trd + 0
    sta fst + 0
; verify null
    ora trd + 1
    beq error ; end of dictionary, no more words to search, quit
; linked list
    lda trd + 1
    sta fst + 1

; update link 
    ldx #(fst - nil) ; from 
    ldy #(trd - nil) ; into
    jsr pull

; compare words
    ldy #0
; save the flag, first byte is size plus flag 
    lda (fst), y
    sta state + 1

@equal:
    lda (snd), y
; space ends token
    cmp #32  
    beq @done
; verify 
    sec
    sbc (fst), y     
; 7-bit ascii, also mask flag
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
    
    jsr showord

; immediate ? if < \0
    lda state + 1   
    bmi execute      

; executing ? if == \0
    lda state + 0   
    beq execute

compile:
    .if debug
    lda #'C'
    jsr putchar
    .endif

    jsr copy

; again

    jmp parse

execute:
    .if debug
    lda #'E'
    jsr putchar
    .endif

    lda fst + 0
    sta wrk + 0
    lda fst + 1
    sta wrk + 1

    jsp pick

; again

    jmp parse

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
    bne @loop
; clear all if y eq \0
@ends:
; grace \b
    lda #32
    sta tib + 0 ; start with space
    sta tib, y  ; ends with space
; mark eot with \0
    lda #0
    iny
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
    sec
    tya
    sbc toin + 1
; keep it
    ldy toin + 1
    dey
    sta tib, y  ; store size ahead 
; setup token, pass pointer
    sty snd + 0
    lda #>tib
    sta snd + 1
    rts

;---------------------------------------------------------------------
; increment a word in page zero, offset by X
incwx:
    lda #1
; add a byte to a word in page zero. offset by X
addwx:
    clc
    adc nil + 0, x
    sta nil + 0, x
    bcc @ends
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
    jmp push
    ;.byte $2c   ; mask two bytes, nice trick !

spush:
    ldx #(rpt - nil)
    jmp push

;---------------------------------------------------------------------
; pull a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
rpull:
    ldx #(rpt - nil)
    jmp pull
    ;.byte $2c   ; mask ldy, nice trick !

spull:
    ldx #(spt - nil)
    jump pull

;---------------------------------------------------------------------
; copy a cell
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
copy: 
    ldy #(fst - nil)

each:
    ldx #(here - nil)

    jmp push

;---------------------------------------------------------------------
; X cursor moves forward
; address in X is incremented
push:
    lda nil + 0, y
    sta (nil,x)
    jsr incwx
    lda nil + 1, y
    sta (nil, x)
    jsr incwx
    rts ; extra ***

;---------------------------------------------------------------------
; X cursor moves backward
; address in X is decremented 
pull:
    jsr decwx
    lda (nil,x)
    sta nil + 1, y
    jsr decwx
    lda (nil, x)
    sta nil + 0, y
    rts

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
    jmp next

;---------------------------------------------------------------------
; ( w a -- ) ; [a] = w
def_word "!", "store", 0
storew:
    jsr spull2
    ldx #(snd - nil) 
    ldy #(fst - nil) 
    jsr poke
    jmp next

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    jsr spull1
    ldx #(fst - nil)
    ldy #(snd - nil)
    jsr pull
    jmp this

;---------------------------------------------------------------------
; ( -- rp )
def_word "rp@", "rpat", 0
    ldx #(rpt - nil)
    jmp both

;---------------------------------------------------------------------
; ( -- sp )
def_word "sp@", "spat", 0
    ldx #(spt - nil)
    jmp both

;---------------------------------------------------------------------
; ( -- state )
def_word "s@", "stat", 0 
    ldx #(state - nil)

;---------------------------------------------------------------------
; generic 
;
both:
    lda nil + 0, x
    sta fst + 0
    lda nil + 1, x
only:
    sta fst + 1
keep:
    ldy #(fst - nil)
this:
    jsr spush
    jmp next

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
; shift right
; ( w -- w/2 )
def_word "2/", "asr", 0
    jsr spull1
    lsr fst + 1
    ror fst + 0
    jmp keep

;---------------------------------------------------------------------
; ( 0 -- $FFFF) | ( n -- $0000)
def_word "0#", "zeroq", 0
    jsr spull1
; lda fst + 1, implicit
    ora fst + 0
    beq istrue  ; is \0
isfalse:
    lda #$00
    .byte $2c   ; mask two bytes, nice trick !
istrue:
    lda #$FF
rest:
    sta fst + 0
    jmp only

;---------------------------------------------------------------------
def_word ":", "colon", 0
; save here, panic if semis not follow elsewhere
    lda here + 0
    sta back + 0 ; pha
    lda here + 1
    sta back + 1 ; pha
; state is 'compile'
    lda #1
    sta state + 0

create:
; link last into (here)
    ldy #(last - nil)
    jsr each
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


; att: address in data, here updated
    jmp next

;---------------------------------------------------------------------
def_word ";", "semis", FLAG_IMM
; update last, panic if comma not lead 
    lda back + 1 ; pla
    sta last + 1
    lda back + 0 ; pla
    sta last + 0
; state is 'interpret'
    lda #0
    sta state + 0

; compounds words must ends with 'unnest'
    lda #<unnest
    sta fst + 0
    lda #>unnest
    sta fst + 1

    jsr showdic 

    jmp compile

;---------------------------------------------------------------------
; NON classic direct thread code
;   lnk is IP, wrk is W
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

    jsr dumpnil

; pull, lnk = *(rpt), rpt += 2 
    ldy #(lnk - nil)
    jsr rpull

    jsr dumpnil
    
    jsr dumpr

    jsr dumps

    lda #10
    jsr putchar

next:
    .if debug
    lda #'X'
     jsr putchar
    .endif

; wrk = (lnk) ; lnk = lnk + 2
    ldx #(lnk - nil)
    ldy #(wrk - nil)
    jsr pull

pick:
    .if debug
    lda #'P'
    jsr putchar
    .endif

; minimal test, no words at page 0
    lda wrk + 1
    beq jump

nest:
    .if debug
    lda #'N'
    jsr putchar
    .endif

    jsr dumpnil

; push, *rp = lnk, rp -=2
    ldy #(lnk - nil)
    jsr rpush

    jsr dumpnil

    jsr dumpr

    jsr dumps

    lda #10
    jsr putchar

link:
    .if debug
    lda #'L'
    jsr putchar
    .endif

    lda wrk + 0
    sta lnk + 0
    lda wrk + 1
    sta lnk + 1
    
    jmp next

; historical JMP @(W)+
jump:
    .if debug
    lda #'J'
    jsr putchar
    .endif

;   wrk is NULL
    jmp (lnk)
    ; ???? where to return ? unnest


;---------------------------------------------------------------------
; pseudo
;
docol_:
    .word nest

semis_:
    .word unnest

parse_:
    .word parse

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

    lda #10
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

    lda #'~'
    jsr putchar
    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex

; get that link, wrk = [fst]
; bypass the link fst+2
    ldx #(fst - nil) ; from 
    ldy #(trd - nil) ; into
    jsr pull

    lda #'#'
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

    lda #10
    jsr putchar

    jmp @loop

@ends:

    lda #'}'
    jsr putchar

    lda #10
    jsr putchar

    jsr loadnils

    loadregs

    rts

;----------------------------------------------------------------------
; show state
showsts:

    lda #' '
    jsr putchar

    lda state + 0
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
showname:

; search backwards

    ldx #(fst - nil)

@loop1:
    jsr decwx
    lda (nil, x)
    pha
    and #$7F
    cmp #' '
    bpl @loop1

; show size+flag

    lda #' '
    jsr putchar

; size
    pla
    pha
    jsr puthex

; mask flag

    pla
    and #$7F
    tay 

; show name

    lda #' '
    jsr putchar

@loop2:
    pla
    jsr putchar
    dey
    bne @loop2

    rts

;----------------------------------------------------------------------
showord:

    saveregs

    jsr savenils

@start:

    lda #10
    jsr putchar

    lda #'('
    jsr putchar

    jsr showsts

    jsr showhere

    jsr showlast
    
    jsr showfst 

    jsr showname

    lda #' '
    jsr putchar

; show list

    lda fst + 1
    cmp #>init
    bmi @ends
    
; only compiled

    ; jsr alist

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
    lda #'H'
    jsr putchar
    lda #'='
    jsr putchar
    lda here + 1
    jsr puthex
    lda here + 0
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

    lda #'}'
    jsr putchar

    lda #10
    jsr putchar

    pla

    rts

;----------------------------------------------------------------------
; show hard stack
dumpk:

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

    lda #' '
    jsr putchar

    sec
    lda #rp0
    sbc rpt + 0
    beq @ends
    tay

@rloop:
    lda #' '
    jsr putchar

    tya
    jsr puthex

    lda #'='
    jsr putchar

    lda (rpt), y
    jsr puthex

    dey
    bne @rloop

@ends:

    rts

;----------------------------------------------------------------------
dumps:
    
    lda #10
    jsr putchar

    lda #'S'
    jsr putchar

    lda #' '
    jsr putchar

    sec
    lda #sp0
    sbc spt + 0
    beq @ends
    tay

@sloop:
    lda #' '
    jsr putchar

    tya
    jsr puthex

    lda #'='
    jsr putchar

    lda (spt) , y
    jsr puthex

    dey
    bne @sloop

@ends:

    rts


;----------------------------------------------------------------------
; show compiled list address
;
alist:

    ldy #$0

@loop:
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

; stop
    lda wrk + 0
    cmp #<unnest
    bne @loop
    lda wrk + 1
    cmp #>unnest
    bne @loop

@ends:

    rts

;----------------------------------------------------------------------
; value:offset
ilist:
    jsr puthex
    lda #':'
    jsr putchar
    tya
    jsr puthex
    lda #' '
    jsr putchar
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


