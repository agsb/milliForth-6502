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
;       this code uses Direct Thread Code, aka DTC.
;
;       no TOS register, all in stacks
;
;       if PAD not used, data stack could be 52 cells; 
;
;       words must be between spaces, before and after;
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
;       words are case-sensitivy no longer than 15 characters;
;
;       no multiuser, no multitask, no faster;
;
;   For 6502:
;
;       is a 8-bit processor with 16-bit address space;
;
;       the most significant byte is the page count;
;
;       page zero and page one hardware reserved;
;
;       hardware stack not used for this Forth;
;
;       page zero is used as pseudo registers;
;
;   For stacks:
;
;   "when the heap moves forward, move the stack backward" 
;
;   as hardware stacks do: 
;      push is 'store and decrease', pull is 'increase and fetch',
;
;   but see the note for Devs.
;
;   common memory model organization of Forth: 
;   [tib->...<-spt: user forth dictionary :here->pad...<-rpt]
;   then backward stacks allow to use the slack space ... 
;
;   this 6502 Forth memory model blocked in pages of 256 bytes:
;   [page0][page1][page2][core ... forth dictionary ...here...]
;   
;   at page2: 
;
;   $00|tib> ... <spt..sp0|$98|pad> ... <rpt..rp0|$FF
;
;   For Devs:
;
;   the hello_world.forth file states that stacks works
;       to allow : dup sp@ @ ; then sp must point to actual TOS
;   
;   The movements will be:
;       push is 'decrease and store'
;       pull is 'fetch and increase'

;    Never mess with two underscore variables;
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
; the entry point for dictionary is h_~name~
; the entry point for code is ~name~
.macro def_word name, label, flag
makelabel "h_", label
.ident(.sprintf("H%04X", hcount + 1)) = *
.word .ident (.sprintf ("H%04X", hcount))
hcount .set hcount + 1
.byte .strlen(name) + flag + 0 ; nice trick !
.byte name
makelabel "", label
.endmacro

;---------------------------------------------------------------------
/*
NOTES:

    not finished yet :)

*/
;----------------------------------------------------------------------

hcount .set 0

H0000 = 0

;----------------------------------------------------------------------
; alias

; cell size, two bytes, 16-bit
CELL = 2    

; highlander, immediate flag, also execute state
FLAG_IMM = 1<<7

; "all in" page $200

; terminal input buffer, 80 bytes, forward
; getline, token, skip, scan, depends on page boundary
tib = $0200

tib_end = $40

; data stack, 36 cells,
; moves backwards and push decreases before copy
sp0 = $98

; pad, 16 cells, forward
pad = sp0 + 1

; return stack, 36 cells, 
; moves backwards and push decreases before copy
rp0 = $FF

; magic NOP (EA) JMP (4C) cell
magic = $20EA

;----------------------------------------------------------------------
; no values here or must be a BSS
.segment "ZERO"

* = $E0

; default pseudo registers

nil:  ; empty fixed reference

; do not touch those
ipt:    .word $0 ; instruction pointer
spt:    .word $0 ; data stack base,
rpt:    .word $0 ; return stack base
wrk:    .word $0 ; work

; free for use
fst:    .word $0 ; first
snd:    .word $0 ; second
trd:    .word $0 ; third
fth:    .word $0 ; fourth

; * = $F0

; default Forth variables, order matters for HELLO.forth !

stat:   .word $0 ; state, only lsb used
toin:   .word $0 ; toin next free byte in TIB
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell in heap dictionary, aka dpt

tout:   .word $0 ; next token in TIB
back:   .word $0 ; hold 'here while compile

; future expansion
head:   .word $0 ; heap forward, also DP
tail:   .word $0 ; heap backward

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

    jmp cold

;----------------------------------------------------------------------
; START OF DEBUG CODE
;---------------------------------------------------------------------

debug = 1

.if debug

;---------------------------------------------------------------------
.macro shows char
    pha
    lda #char
    jsr putchar
    pla

.endmacro

;---------------------------------------------------------------------
.macro showval reg
    pha
    lda reg
    jsr puthex
    pla

.endmacro

;---------------------------------------------------------------------
.macro showbulk reg
    pha
    lda reg + 1
    jsr puthex
    lda reg + 0
    jsr puthex
    pla

.endmacro

;---------------------------------------------------------------------
.macro showrefer reg
    pha
    iny 
    lda (reg), y
    jsr puthex
    dey
    lda (reg), y
    jsr puthex
    pla

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
.macro savenils
    pha
    tya
    pha

    ldy #0
@loop_savenils:
    lda $00E0, y
    sta $00C0, y
    iny
    cpy #32
    bne @loop_savenils

    pla
    tay
    pla

.endmacro

;----------------------------------------------------------------------
.macro loadnils
    pha
    tya
    pha

    ldy #0
@loop_loadnils:
    lda $00C0, y
    sta $00E0, y
    iny
    cpy #32
    bne @loop_loadnils

    pla
    tay
    pla

.endmacro

;----------------------------------------------------------------------
shownils:

    pha
    tya
    pha
    
    ldy #0
    
    shows '('

@loop:
    shows ' '
    
    ; MSB
    iny
    lda nil, y
    jsr puthex

    ; LSB
    dey
    lda nil, y
    jsr puthex
    
    ; follow
    iny
    iny

    cpy #32
    bne @loop

    shows ' '
    shows ')'

    pla
    tay
    pla

    rts

;---------------------------------------------------------------------
showsts:

    saveregs

    savenils

    shows 10
    
    jsr shownils

    jsr showrp

    jsr showsp

    jsr showdic

    loadnils

    loadregs

    rts

;----------------------------------------------------------------------
; show compiled list address
showlist:

    shows ' '

    shows '('
    
    lda #0
    tax

@loop:
    shows ' '

    lda (fst), y
    sta wrk + 0
    iny 

    lda (fst), y
    sta wrk + 1
    iny 

    jsr puthex
    lda wrk + 0
    jsr puthex

@istwo:
    cpy #02
    bne  @isone

; was a magic ?
    lda wrk + 0
    cmp #$EA
    bne @ends
    lda wrk + 1
    cmp #$20
    bne @ends

    beq @loop

@isone:
; was a exit ?
    lda wrk + 1
    cmp #>exit
    bne @loop

    lda wrk + 0
    cmp #<exit
    bne @loop

@ends:

    shows ' '

    shows ')'

    rts

;----------------------------------------------------------------------
showname:
    
    shows ' '
    
    lda (fst), y
    pha
    jsr puthex
    
    shows ' '
    
    pla
    and #$7F
    tax

@loop:
    iny
    lda (fst), y
    jsr putchar
    dex
    bne @loop

    iny

    rts

;----------------------------------------------------------------------
showord:

    ldy #0

    jsr showname

    tya 
    ldx #(fst)
    jsr addwx 

    ldy #0

    shows ' '

    showbulk fst

    jsr showlist
    
    tya 
    ldx #(fst)
    jsr addwx 

    ldy #0

    shows ' '

    showbulk fst

    rts

;---------------------------------------------------------------------
showdic:

    shows 10

    shows '{'

; load lastest link
    lda last + 0
    sta snd + 0
    lda last + 1
    sta snd + 1

@loop:

; update link list
    lda snd + 0
    sta fst + 0
    
; verify is zero
    ora snd + 1
    beq @ends ; end of dictionary, no more words to search, quit

; update link list
    lda snd + 1
    sta fst + 1

    shows 10

    shows ' '

    showbulk fst

; get that link, snd = (fst)
    ldx #(fst) ; from 
    ldy #(snd) ; into
    jsr copyfrom

    shows ' '

    showbulk snd

    jsr showord

    jmp @loop

@ends:

    shows 10

    shows '}'

    shows 10

    rts

;----------------------------------------------------------------------
showbck:

; search a name backwards from cfa

    ldx #(fst)

@loop:
    jsr decwx
    lda (0, x)
    and #$7F    ; may be immediate ^.^
    cmp #' '
    bpl @loop

    ldy #0
    jsr showname

    rts

;----------------------------------------------------------------------
; show hard stack
showhs:

    php
    pha
    txa
    pha
    tya
    pha

    tsx

    shows 10

    lda #'H'
    jsr putchar
    
    lda #'='
    jsr putchar

    inx
    inx
    inx
    inx

    inx

    txa
    jsr puthex

@loop:

    lda #' '
    jsr putchar
    txa
    jsr puthex
    lda #':'
    jsr putchar
    lda $100, x
    jsr puthex
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
showrp:
    
    saveregs

    shows 10

    shows 'R'

    shows '='

    sec
    lda #rp0
    sbc rpt + 0
    beq @ends

    tax
    lsr
    jsr puthex

    ldy #0

@loop:
    shows ' '

    showrefer rpt

    iny 
    iny 
    dex
    dex
    bne @loop

@ends:

    loadregs

    rts

;----------------------------------------------------------------------
showsp:
    
    saveregs

    shows 10

    shows 'S'

    shows '='

    sec
    lda #sp0
    sbc spt + 0
    beq @ends

    tax
    lsr
    jsr puthex

    ldy #0

@loop:
    shows ' '

    showrefer spt

    iny 
    iny 
    dex
    dex
    bne @loop

@ends:

    loadregs

    rts

;----------------------------------------------------------------------
; terminal input buffer
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

.endif
;----------------------------------------------------------------------
; END OF DEBUG CODE
;----------------------------------------------------------------------

cold:
;   disable interrupts
    sei

;   clear BCD
    cld

;   set real stack
    ldx #$FF
    txs

;   enable interrupts
    cli

; link list of headers
    lda #>h_exit
    sta last + 1
    lda #<h_exit
    sta last + 0

; next heap free cell  
    lda #>init
    sta here + 1
    lda #<init
    sta here + 0

;---------------------------------------------------------------------
quit:
; reset stacks
    ldy #>tib
    sty spt + 1
    sty rpt + 1
    sty toin + 1
    sty tout + 1

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
; stat is 'interpret' == \0
    sty stat + 0
    
    .byte $2c   ; mask next two bytes, nice trick !

;---------------------------------------------------------------------
; the outer loop

; like a begin-again

parse_:
    .word okey
;---------------------------------------------------------------------
okey:
    lda #' '
    jsr putchar
    lda #'O'
    jsr putchar
    lda #'K'
    jsr putchar
    lda #10
    jsr putchar

parse:

    lda #>parse_
    sta ipt + 1
    lda #<parse_
    sta ipt + 0

  ;  shows 10
  ;  shows '~'

; get a token
    jsr token

    ; jsr showsts 

find:
; fst this link
; snd next link

; load last
    lda last + 1
    sta snd + 1
    lda last + 0
    sta snd + 0
    
@loop:
; lsb linked list
    lda snd + 0
    sta fst + 0

; verify null
    ora snd + 1
    bne @each
    jmp error ; end of dictionary, no more words to search, quit

@each:    

; msb linked list
    lda snd + 1
    sta fst + 1

; update next link 
    ldx #(fst) ; from 
    ldy #(snd) ; into
    jsr copyfrom

; compare words

    ldy #0
; save the flag, first byte is size and flag 
    lda (fst), y
    sta stat + 1

; compare chars
@equal:
    lda (tout), y
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
    ldx #(fst)
    jsr addwx
    
eval:
    ; if execute is FLAG_IMM
    ; lda stat + 1
    ; ora stat + 0
    ; bmi execute

; executing ? if == \0
    lda stat + 0   
    beq execute

; immediate ? if < \0
    lda stat + 1   
    bmi execute      

compile:

;    shows ' '
;    shows 'C'
;    shows ' '
;  showbulk fst

    ldy #(fst)
    jsr comma

    jmp next

execute:

;    shows ' '
;    shows 'E'
;    shows ' '
;  showbulk fst

; DTC exec

    jmp (fst)

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

; leave at 0
    ldy #1
@loop:  
    jsr getchar
    and #$7F        ; 7-bit ascii only
    cmp #10         ; unix \n
    beq @ends
    sta tib, y
    iny
    cpy #tib_end
    bne @loop

; clear all if y eq \0
@ends:
; grace \b
    lda #32
    sta tib + 0 ; start with space
    sta tib, y  ; ends with space
; mark eol with \0
    iny
    lda #0
    sta tib, y
; start it
    sta toin + 0

;---------------------------------------------------------------------
; in place every token
token:
; last position on tib
    ldy toin + 0

@skip:
; skip spaces
    jsr try
    beq @skip
; keep start 
    dey
    sty tout + 0    

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
    sbc tout + 0
; keep it
    ldy tout + 0
    dey
    sta tib, y  ; store size for counted string 
    sty tout + 0

; setup token
    rts

;---------------------------------------------------------------------
; add a byte to a word in page zero. offset by X
; incwx:
;   lda #01
addwx:
    clc
    adc 0, x
    sta 0, x
    bcc @ends
    inc 1, x
@ends:
    rts

;---------------------------------------------------------------------
; increment a word in page zero. offset by X
incwx:
    inc 0, x
    bne @ends
    inc 1, x
@ends:
    rts

;---------------------------------------------------------------------
; decrement a word in page zero. offset by X
decwx:
    lda 0, x
    bne @ends
    dec 1, x
@ends:
    dec 0, x
    rts

;---------------------------------------------------------------------
; push a cell 
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
rpush:
    ldx #(rpt)
    .byte $2c   ; mask next two bytes, nice trick !

spush:
    ldx #(spt)

;---------------------------------------------------------------------
; classic stack backwards
push:
    jsr decwx
    lda 1, y
    sta (0, x)
    jsr decwx
    lda 0, y
    sta (0, x)
    rts ; extra ***

;---------------------------------------------------------------------
; pull a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
rpull:
    ldx #(rpt)
    .byte $2c   ; mask next two bytes, nice trick !

spull:
    ldx #(spt)

;---------------------------------------------------------------------
; classic stack backwards
pull:
    lda (0, x)
    sta  0, y
    jsr incwx
    lda (0, x)
    sta  1, y
    jsr incwx
    rts

;---------------------------------------------------------------------
; classic heap moves always forward
;
wcomma:
    sta wrk + 1
    ldy #(wrk)

comma: 
    ldx #(here)

copyinto:
    lda 0, y
    sta (0, x)
    jsr incwx
    lda 1, y
    sta (0, x)
    jsr incwx
    rts ; extra ***

copyfrom:
    lda (0, x)
    sta 0, y
    jsr incwx
    lda (0, x)
    sta 1, y
    jsr incwx
    rts ; extra ***

;---------------------------------------------------------------------
; for lib6502  emulator
; still always does echo
getchar:
    lda $E000

putchar:
    sta $E000

    .if debug

; EOF ?

    cmp #$FF
    bne rets

byes:
; return (0)

    lda #'B'
    jsr putchar
    lda #'Y'
    jsr putchar
    lda #'E'
    jsr putchar

    jmp $0000

    .endif

rets:
    rts

;---------------------------------------------------------------------
;
; generics 
;
;---------------------------------------------------------------------
rpush1:
    ldy #(fst)
    jmp rpush

;---------------------------------------------------------------------
rpull1:
    ldy #(fst)
    jmp rpull

;---------------------------------------------------------------------
spush1:
    ldy #(fst)
    jmp spush

;---------------------------------------------------------------------
spull2:
    ldy #(snd)
    jsr spull

;---------------------------------------------------------------------
spull1:
    ldy #(fst)
    jmp spull

;---------------------------------------------------------------------
copys:
    lda 0, y
    sta fst + 0
    lda 1, y

keeps:
    sta fst + 1

this:
    jsr spush1

    jmp next

;---------------------------------------------------------------------
;
; primitives, 
; a address, c byte ascii, w signed word, u unsigned word 
; cstr counted string < 256, strz  string with nul ends
; 
;---------------------------------------------------------------------
; extras
;---------------------------------------------------------------------
def_word "bye", "bye", 0
    jmp byes

def_word "dump-on", "dumpon", 0
    dec fth
    jmp next

def_word "dump-off", "dumpoff", 0
    lda #0
    sta fth
    jmp next

;---------------------------------------------------------------------
def_word "dump", "dumpw", 0

    shows ' '

    lda here + 1
    jsr puthex
    lda here + 0
    jsr puthex
    
    shows 10

    lda #>init
    sta wrk + 1
    jsr puthex
    lda #<init
    sta wrk + 0
    jsr puthex
    
    shows ':'

    ldy #$00

@loop:
    shows ' '
    lda (wrk), y
    jsr puthex
    iny
    cpy #$20
    bmi @loop
    
    tya
    ldx #(wrk)
    jsr addwx

    ldy #0

    shows 10

    lda wrk + 1
    jsr puthex
    lda wrk + 0
    jsr puthex
    shows ':'

; thanks, @https://codebase64.org/doku.php?id=base:16-bit_absolute_comparison

    lda wrk + 0
    cmp here + 0
    lda wrk + 1
    sbc here + 1
    eor wrk + 1
    bmi @loop

    shows 10

    jmp next

;---------------------------------------------------------------------
def_word "S=", "spshow", 0

    jsr showsp
    jmp next

;---------------------------------------------------------------------
def_word "R=", "rpshow", 0

    jsr showrp
    jmp next

;---------------------------------------------------------------------
def_word "words", "words", 0

    jsr showdic
    jmp next

;---------------------------------------------------------------------
def_word ".", "dot", 0

    jsr spull1
    
    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex
    
    jsr spush1

    jmp next

;---------------------------------------------------------------------
def_word "cr", "cr", 0

    lda 10
    jsr putchar
    
    jmp next

;---------------------------------------------------------------------
def_word "qr", "qr", 0

    lda #$43
    sta fst + 1
    lda #$21
    sta fst + 0
    jmp this

;---------------------------------------------------------------------
; core 
;---------------------------------------------------------------------
; ( c -- ) ; tos + 1 unchanged
def_word "emit", "emit", 0
    jsr spull1
    lda fst + 0
    jsr putchar
    jmp next

;---------------------------------------------------------------------
; ( -- c ) ; tos + 1 unchanged
def_word "key", "key", 0
    jsr getchar
    sta fst + 0
    jmp this
    
;---------------------------------------------------------------------
; ( w -- w/2 ) ; shift right
def_word "2/", "shr", 0
    ; asr 
    ;lda tos + 1
    ;asl a
    ;ror tos + 1
    jsr spull1
    lsr fst + 1
    ror fst + 0
    jmp this

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
    jmp keeps

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
    jmp keeps

;---------------------------------------------------------------------
; ( 0 -- $FFFF) | ( n -- $0000)
def_word "0#", "zeroq", 0
    jsr spull1
    lda fst + 1
    ora fst + 0
    beq istrue  ; is \0
isfalse:
    lda #$00
    .byte $2c   ; mask next two bytes, nice trick !
istrue:
    lda #$FF
rest:
    sta fst + 0
    jmp keeps

;---------------------------------------------------------------------
; ( w a -- ) ; [a] = w
def_word "!", "store", 0
storew:
    jsr spull2
    ldx #(snd) 
    ldy #(fst) 
    jsr copyinto
    jmp next

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    jsr spull1
    ldx #(fst)
    ldy #(snd)
    jsr copyfrom
    jmp copys

;---------------------------------------------------------------------
; ( -- stat )
def_word "s@", "state", 0 
    lda #<stat
    sta fst + 0
    lda #>stat
mays:
    sta fst + 1
    jmp this 

;---------------------------------------------------------------------
; ( -- sp )
def_word "sp@", "spat", 0
    lda spt + 0
    sta fst + 0
    lda spt + 1
    bcc mays

;---------------------------------------------------------------------
; ( -- rp )
def_word "rp@", "rpat", 0
    lda rpt + 0
    sta fst + 0
    lda rpt + 1
    bcc mays 

;---------------------------------------------------------------------
def_word ";", "semis", FLAG_IMM
; update last, panic if colon not lead elsewhere 
    lda back + 0 
    sta last + 0
    lda back + 1 
    sta last + 1
; stat is 'interpret'
    lda #0
    sta stat + 0

;    shows ' '
;    shows 'K'
;    shows ' '

; compound words must ends with exit
finish:
    lda #<exit
    sta wrk + 0
    lda #>exit
    jsr wcomma

    jmp next

;---------------------------------------------------------------------
def_word ":", "colon", 0
; save here, panic if semis not follow elsewhere
    lda here + 0
    sta back + 0 
    lda here + 1
    sta back + 1 
; stat is 'compile'
    lda #1
    sta stat + 0

;    shows ' '
;    shows 'W'
;    shows ' '

create:
; copy last into (here)
    ldy #(last)
    jsr comma

; get following token
    jsr token

; copy size and name
    ldy #0
@loop:    
    lda (tout), y
    cmp #32    ; stops at space
    beq @ends
    sta (here), y
    iny
    bne @loop

@ends:
; update here 
    tya
    ldx #(here)
    jsr addwx

; inserts the nop call 
    lda #$EA
    sta wrk + 0
    lda #$20
    jsr wcomma

; inserts the reference
    lda #<nest
    sta wrk + 0
    lda #>nest
    jsr wcomma

; done
    jmp next

;---------------------------------------------------------------------
; classic direct thread code
;   ipt is IP, wrk is W
;
; for reference: nest ak enter or docol, unnest is exit or semis;
;
;---------------------------------------------------------------------
def_word "exit", "exit", FLAG_IMM
unnest:
    shows ' '
    shows 'U'
    shows ' '
;    showbulk ipt 
    
; pull, ipt = (rpt), rpt += 2 
    ldy #(ipt)
    jsr rpull

next:
;    shows ' '
;    shows 'X'
;    shows ' '
;    showbulk ipt 

; wrk = (ipt) ; ipt += 2
    ldx #(ipt)
    ldy #(wrk)
    jsr copyfrom

    lda fth
    beq jump
    
    shows 10
    shows ' '
    showbulk ipt
    shows '*'
    showbulk wrk
    shows ' '

    lda wrk + 0
    sta fst + 0
    lda wrk + 1
    sta fst + 1
    jsr showbck

    jsr showrp
    jsr showsp

jump:
    jmp (wrk)

enter:
nest:
    shows ' '
    shows 'N'
    shows ' '
 ;   showbulk ipt 
    

; push, *rp = ipt, rp -=2
    ldy #(ipt)
    jsr rpush

  ;  jsr showsts 

; pull (ip),  6502 trick: must increase return address rof a jsr

    pla
    sta ipt + 0
    pla
    sta ipt + 1

    ldx #(ipt)
    jsr incwx
    
    jmp next

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
; print a counted string
putstr:
    php
    pha
    tya
    pha
    txa
    pha

    ldy #0
    lda (fst), y
    tax
@loop:
    iny 
    lda (fst), y
    jsr putchar
    dex
    bne @loop
    
    pla
    tax
    pla
    tay
    pla
    plp

    rts

;----------------------------------------------------------------------
; for anything above is not a primitive
.align $100

init:   


