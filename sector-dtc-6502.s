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
;   all tib (84 bytes), locals (14 cells), data (36 cells) and 
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
;   words must be between spaces, begin and end spaces are wise;
;
;   if locals not used, data stack could be 50 cells 
;
;   For 6502:
;
;   hardware stack (page $100) not used as forth stack, free for use;
;
;   6502 is a byte processor, no need 'pad' at end of even names;
; 
;   no multiuser, no multitask, no faster;
;
;   24/01/2024 for comparison with x86 code, 
;       rewrite using standart direct thread code;
;
;   by easy, stack operations are backwards but slightly different
;
;   usually push is 'store and decrease', pull is 'increase and fetch',
;
;   here: push is 'decrease and store', pull is 'fetch and increase',
;
;----------------------------------------------------------------------
;
; stuff for ca65 
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
.endmacro

;----------------------------------------------------------------------

hcount .set 0

H0000 = 0

debug = 1

;----------------------------------------------------------------------
; alias

; cell size
CELL = 2     ; two bytes, 16 bits

; highlander
FLAG_IMM = 1<<7

; "all in" page $200

; terminal input buffer, 84 bytes, forward
tib = $0200

; locals, 14 cells, forward
lcs = $54

; strange ? is a 8-bit system, look at push code ;)

; data stack, 36 cells, backward
dsb = $B9

; return stack, 36 cells, backward
rsb = $00

;----------------------------------------------------------------------
; no values here or must be BSS
.segment "ZERO"

* = $E0
; default pseudo registers
nil:    .word $0 ; reserved reference offset
sp0:    .word $0 ; holds data stack base,
rp0:    .word $0 ; holds return stack base

; inner pseudo registers for SITC
lnk:    .word $0 ; link
wrk:    .word $0 ; work

; scratch pseudo registers
fst:    .word $0 ; first
snd:    .word $0 ; second
trd:    .word $0 ; third

; default Forth variables
state:  .word $0 ; state, only lsb used
toin:   .word $0 ; toin, only lsb used
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell
; extras
base:   .word $0 ; base radix, define before use
back:   .word $0 ; hold for debug

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
    sty sp0 + 1
    sty rp0 + 1
    ldy #<dsb
    sty sp0 + 0
    ldy #<rsb
    sty rp0 + 0
    ; y == \0
; clear tib stuff
    sty toin + 0
    sty tib + 0
; state is 'interpret' == \0
    sty state + 0

;---------------------------------------------------------------------
; the outer loop
outer:

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
; save the flag 
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
; implict ldx #(fst - nil)
    jsr addwx

    .if debug 
    jsr showord
    .endif

; again 
    lda #<parse_
    sta lnk + 0
    lda #>parse_
    sta lnk + 1

; immediate ? if < \0
    lda state + 1   
    bmi execute      ; bit 7 set 

; executing ? if == \0
    lda state + 0   
    beq execute

compile:
    .if debug
    lda #'C'
    jsr putchar
    .endif

    jsr copy

    jmp next

execute:
    .if debug
    lda #'E'
    jsr putchar
    .endif

    lda fst + 0
    sta wrk + 0
    lda fst + 1
    sta wrk + 1

    jmp exec

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
    lda #'?'
    jsr putchar
    lda #'?'
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
; 7-bit ascii, also mask flag
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
; mark \0
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
    ldx #(rp0 - nil)
    .byte $2c   ; mask two bytes, nice trick !
spush:
    ldx #(sp0 - nil)
push:
    jsr decwx
    lda nil + 1, y
    sta (nil, x)

    jsr decwx
    lda nil + 0, y
    sta (nil, x)

    rts 

;---------------------------------------------------------------------
; pull a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
rpull:
    ldx #(rp0 - nil)
    .byte $2c   ; mask ldy, nice trick !
spull:
    ldx #(sp0 - nil)
pull:
    lda (nil, x)    
    sta nil + 0, y   
    jsr incwx        
    
    lda (nil, x)    
    sta nil + 1, y  
    jmp incwx 

;---------------------------------------------------------------------
; move a cell
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
; default case
copy: 
    ldy #(fst - nil)
each:
    ldx #(here - nil)
;---------------------------------------------------------------------
; n2z
poke:
    lda nil + 0, y
    sta (nil,x)
    jsr incwx
    lda nil + 1, y
    sta (nil, x)
    jmp incwx

;---------------------------------------------------------------------
; z2n
yank:
    jsr decwx
    lda (nil,x)
    sta nil + 1, y
    jsr decwx
    sta (nil, x)
    lda nil + 0, y
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
    ldx #(rp0 - nil)
    jmp both

;---------------------------------------------------------------------
; ( -- sp )
def_word "sp@", "spat", 0
    ldx #(sp0 - nil)
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
    pha
    lda here + 1
    pha
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
; implicit ldx #(here - nil), when 'each'
    jsr addwx

; att: address in data, here updated
    jmp next

;---------------------------------------------------------------------
def_word ";", "semis", FLAG_IMM
; update last, panic if comma not lead 
    pla
    sta last + 1
    pla
    sta last + 0
; state is 'interpret'
    lda #0
    sta state + 0

; compounds words must ends with 'unnest'
    lda #<unnest
    sta fst + 0
    lda #>unnest
    sta fst + 1

    jmp compile

;---------------------------------------------------------------------
; classic direct thread code
;   lnk is IP, wrk is W
;
def_word "exit", "exit", 0
inner:

unnest:
    .if debug
    lda #'U'
    jsr putchar
    .endif

; pull 
    ldy #(lnk - nil)
    jsr rpull

next:
    .if debug
    lda #'X'
    jsr putchar
    .endif

; wrk = (lnk) ; lnk = lnk + 2
    ldx #(lnk - nil)
    ldy #(wrk - nil)
    jsr pull

    .if debug
    jsr dump
    .endif

exec:
    .if debug
    lda #'Y'
    jsr putchar
    .endif

; minimal 
    lda wrk + 1
    cmp #>init
    bmi jump

nest:
    .if debug
    lda #'N'
    jsr putchar
    .endif

; push into return stack
    ldy #(lnk - nil)
    jsr rpush

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

    jmp (wrk)

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
    and #$7F
    tax
    jsr puthex

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

    loadregs

    rts

;----------------------------------------------------------------------
; show cfa
showcfa:

    lda #' '
    jsr putchar

    lda fst + 1
    sta wrk + 1
    jsr puthex

    lda fst + 0
    sta wrk + 0
    jsr puthex

    rts
;----------------------------------------------------------------------
showname:

    saveregs

; search backwards

    ldx #(wrk - nil)

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

    pla
    tay
    jsr puthex

; mask flag

    tya
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
showord:

    toinis

    ldy #0
@push:
    lda (nil), y
    pha

    iny
    cpy #(base - nil) 
    bne @push

@start:

    lda #10
    jsr putchar

    lda #'('
    jsr putchar

    jsr showsts

    jsr showcfa
    
    jsr showname

; show list

    lda fst + 1
    cmp #>init
    bmi @ends
    
    jsr alist

@ends:

    lda #')'
    jsr putchar

    ldy #(base - nil - 1)
@pull:
    pla
    sta (nil), y

    .if 0
    jsr ilist
    .endif

    dey
    cpy #$FF 
    bne @pull

    toends

    rts


;----------------------------------------------------------------------
dump:

    pha

    lda #10
    jsr putchar

    lda #'{'
    jsr putchar

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
    lda sp0 + 1
    jsr puthex
    lda sp0 + 0
    jsr puthex
    
    lda #' '
    jsr putchar
    lda #'R'
    jsr putchar
    lda #'='
    jsr putchar
    lda rp0 + 1
    jsr puthex
    lda rp0 + 0
    jsr puthex
    lda #' '
    jsr putchar

    lda #'}'
    jsr putchar

;;;    jsr showname

    pla

    rts
    
;----------------------------------------------------------------------
dumpr:
    
    lda #'R'
    jsr putchar

    sec
    lda #rsb
    sbc rp0 + 0
    tay

@rloop:
    lda #' '
    jsr putchar

    lda (rp0) , y
    jsr puthex
    dey
    bne @rloop
    
    rts

;----------------------------------------------------------------------
dumps:

    lda #'S'
    jsr putchar

    sec
    lda #dsb
    sbc sp0 + 0
    tay

@sloop:
    lda #' '
    jsr putchar

    lda (sp0) , y
    jsr puthex
    dey
    bne @sloop

    rts

;----------------------------------------------------------------------
; show list address, till 
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


