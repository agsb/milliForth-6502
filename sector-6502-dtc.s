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
;   why ? For understand better my skills, 6502 code and thread codes
;
;   how ? Programming a new Forth for old 8-bit cpu emulator
;
;   what ? Design the best minimal Forth engine and vocabulary
;
;   Changes:
;
;   all data (36 cells) and return (36 cells) stacks, TIB (80 bytes) 
;       and PIC (32 bytes) are in same page $200, 256 bytes; 
;
;   TIB and PIC grows forward, stacks grows backwards;
;
;   no overflow or underflow checks;
;
;   the header order is LINK, SIZE+FLAG, NAME.
;
;   only IMMEDIATE flag used as $80, no hide, no compile;
;
;   As ANSI Forth 1994: FALSE is $0000 ; TRUE is $FFFF ;
;
;   Remarks:
;
;       this code uses Direct Thread Code, aka DTC.
;
;       use a classic cell with 16-bits. 
;
;       no TOS register, all values keeped at stacks;
;
;       TIB (terminal input buffer) is like a stream;
;
;       Chuck Moore uses 64 columns, be wise, obey rule 72 CPL; 
;
;       words must be between spaces, before and after;
;
;       no line wrap, do not break words between lines;
;
;       only 7-bit ASCII characters, plus \n, no controls;
;           ( later maybe \b bacspace and \u cancel )
;
;       words are case-sensitivy and less than 15-36 characters;
;
;       no need named-'pad' at end of even names;
;
;       no multiuser, no multitask, no checks, not faster;
;
;   For 6502:
;
;       a 8-bit processor with 16-bit address space;
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
;   but see the notes for Devs.
;
;   common memory model organization of Forth: 
;   [tib->...<-spt: user forth dictionary :here->pad...<-rpt]
;   then backward stacks allow to use the slack space ... 
;
;   this 6502 Forth memory model blocked in pages of 256 bytes:
;   [page0][page1][page2][core ... forth dictionary ...here...]
;   
;   At page2: 
;
;   |$00 tib> .. $50| <spt..sp0 $98| <rpt..rp0 $E0|pic> ..$FF|
;
;   At page 3:
;
;   |$0300 cold, warm, forth code, init: here> heap ... tail ????| 
;
;   PIC is a transient area of 32 bytes 
;   PAD could be allocated from here
;
;   For Devs:
;
;   the hello_world.forth file states that stacks works
;       to allow : dup sp@ @ ; then sp must point to actual TOS
;   
;   The movements will be:
;       push is 'decrease and store'
;       pull is 'fetch and increase'
;
;   Never mess with two underscore variables;
;
;   Not using smudge, 
;       colon saves "here" into "back" and 
;       semis loads "lastest" from "back";
;
;   Do not risk to put stacks with $FF also no routine endings with.
;
;   Must carefull inspect if any label ends with $FF and move it;
;
;   This source is for Ca65.
;
;   Stacks represented as (S: w3 w2 w1 -- u2 u1)
;       before -- after, lower to upper, top at right
;
;----------------------------------------------------------------------
;
; Stuff for ca65 compiler
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
; variables for macros

hcount .set 0

H0000 = 0

;---------------------------------------------------------------------
/*
NOTES:

    not finished yet :)

*/
;----------------------------------------------------------------------
;
; alias

; cell size, two bytes, 16-bit
CELL = 2    

; highlander, immediate flag.
FLAG_IMM = 1<<7

; "all in" page $200

; terminal input buffer, 80 bytes, forward
; getline, token, skip, scan, depends on page boundary
tib = $0200

tib_end = $50

; data stack, 36 cells,
; moves backwards and push decreases before copy
sp0 = $98

; return stack, 36 cells, 
; moves backwards and push decreases before copy
rp0 = $E0

; magic NOP (EA) JSR (20), at CFA cell
magic = $20EA

;----------------------------------------------------------------------
; no values here or must be a BSS
.segment "ZERO"

* = $E0

nil:  ; empty for fixed reference

; default Forth variables, order matters for HELLO.forth !

stat:   .word $0 ; state at lsb, last size+flag at msb
toin:   .word $0 ; toin next free byte in TIB
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell in heap dictionary, aka dpt

; default pseudo registers

spt:    .word $0 ; data stack base,
rpt:    .word $0 ; return stack base
ipt:    .word $0 ; instruction pointer
wrk:    .word $0 ; work

* = $F0

; free for use

fst:    .word $0 ; first
snd:    .word $0 ; second
trd:    .word $0 ; third
fth:    .word $0 ; fourth

; reserved

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

main:

;----------------------------------------------------------------------
; common
;
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

;----------------------------------------------------------------------
warm:
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
; must review 'abort and 'quit code
; together to save bytes
quit:
; reset
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
    lda stat + 0
    bne parse

    lda #' '
    jsr putchar
    lda #'O'
    jsr putchar
    lda #'K'
    jsr putchar
    lda #10
    jsr putchar

;---------------------------------------------------------------------
; place a hook
parse:
    lda #>parse_
    sta ipt + 1
    lda #<parse_
    sta ipt + 0

; get a token
    jsr token

find:
; load last
    lda last + 1
    sta snd + 1
    lda last + 0
    sta snd + 0
    
@loop:
; lsb linked list
    lda snd + 0
    sta fst + 0

; verify \0x0
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

    ldy #(fst)
    jsr comma

    jmp next

execute:

    jmp (fst)

;---------------------------------------------------------------------
; wipe later
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

; leave the first
    ldy #1
@loop:  
    jsr getchar
; zzz 7-bit ascii only
    and #$7F        
; unix \n
    cmp #10         
    beq @ends
; no controls
    cmp #' '
    bmi @loop
; valid
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
; in place every token,
; the counter is placed at last space before word
; no rewinds
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
;  lib6502  emulator
getchar:
    lda $E000
    ; no echoes ? uncomment
    ; rts 
putchar:
    sta $E000
; EOF ?
    cmp #$FF
    beq byes
    rts
; exit for emulator  
byes:
    jmp $0000

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
; increment a word in page zero. offset by X
;incwx:
;    inc 0, x
;    bne @ends
;    inc 1, x
;@ends:
;    rts

;---------------------------------------------------------------------
; increment a word in page zero. offset by X
incwx:
    lda #01
;---------------------------------------------------------------------
; add a byte to a word in page zero. offset by X
addwx:
    clc
    adc 0, x
    sta 0, x
    bcc @ends
    inc 1, x
    clc     ; keep branchs
@ends:
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
    jmp incwx

copyfrom:
    lda (0, x)
    sta 0, y
    jsr incwx
    lda (0, x)
    sta 1, y
    jmp incwx

;---------------------------------------------------------------------
; push a cell 
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
spush:
    ldx #(spt)
    ; jmp push
    .byte $2c   ; mask next two bytes, nice trick !

rpush:
    ldx #(rpt)

;---------------------------------------------------------------------
; classic stack backwards
push:
    jsr decwx
    lda 1, y
    sta (0, x)
    jsr decwx
    lda 0, y
    sta (0, x)
    rts ; 

;---------------------------------------------------------------------
; pull a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
spull:
    ldx #(spt)
    ; jmp pull
    .byte $2c   ; mask next two bytes, nice trick !

rpull:
    ldx #(rpt)

;---------------------------------------------------------------------
; classic stack backwards
pull:
    lda (0, x)
    sta  0, y
    jsr incwx
    lda (0, x)
    sta  1, y
    jmp incwx
    ;  rts zzzz

;---------------------------------------------------------------------
;
; generics 
;
;---------------------------------------------------------------------
spull2:
    ldy #(snd)
    jsr spull

;---------------------------------------------------------------------
spull1:
    ldy #(fst)
    jmp spull

;---------------------------------------------------------------------
spush1:
    ldy #(fst)
    jmp spush

;---------------------------------------------------------------------
;
; the primitives, 
; for stacks uses
; a address, c byte ascii, w signed word, u unsigned word 
; cs counted string < 256, sz string with nul ends
; 
;----------------------------------------------------------------------

; uncomment to include the extras (sic)
extras = 1 

.ifdef extras

;----------------------------------------------------------------------
; extras
;----------------------------------------------------------------------
; ( -- ) ae exit forth
def_word "bye", "bye", 0
    jmp byes

;----------------------------------------------------------------------
; ( -- ) ae exit forth
def_word "abort", "abort", 0
    jmp error

;----------------------------------------------------------------------
; ( -- ) ae list of data stack
def_word ".S", "splist", 0
    lda spt + 0
    sta fst + 0
    lda spt + 1
    sta fst + 1
    lda #'S'
    jsr putchar
    lda #sp0
    jsr list
    jmp next

;----------------------------------------------------------------------
; ( -- ) ae list of return stack
def_word ".R", "rplist", 0
    lda rpt + 0
    sta fst + 0
    lda rpt + 1
    sta fst + 1
    lda #'R'
    jsr putchar
    lda #rp0
    jsr list
    jmp next

;----------------------------------------------------------------------
;  ae list a sequence of references
list:

    sec
    sbc fst + 0
    lsr

    tax

    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex

    lda #' '
    jsr putchar

    txa
    jsr puthex

    lda #' '
    jsr putchar

    txa
    beq @ends

    ldy #0
@loop:
    lda #' '
    jsr putchar
    iny
    lda (fst),y 
    jsr puthex
    dey
    lda (fst),y 
    jsr puthex
    iny 
    iny
    dex
    bne @loop
@ends:
    rts

;----------------------------------------------------------------------
;  ae seek for 'exit to ends a sequence of references
;  max of 254 references in list
seek:
    ldy #0
@loop1:
    iny
    beq @ends

    lda (fst), y
    cmp #>exit
    bne @loop1

    dey 
    lda (fst), y
    cmp #<exit
    beq @ends
    
    iny
    bne @loop1

@ends:
    ; clc     ; keep branchs
    tya
    lsr
    rts

;----------------------------------------------------------------------
; ( u -- ) print tos in hexadecimal, swaps order
def_word ".", "dot", 0
    lda #' '
    jsr putchar
    jsr spull1
    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex
    jsr spush1
    jmp next

;----------------------------------------------------------------------
; code a byte in ASCII hexadecimal 
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
    ora #$30
    cmp #$3A
    bcc @ends
    adc #$06
    clc     ; keep branchs
@ends:
    jmp putchar

.endif

;---------------------------------------------------------------------
;
; extensions
;
;---------------------------------------------------------------------
; uncomment to include the extensions (sic)
extensions = 1 

.ifdef extensions

;---------------------------------------------------------------------
; ( w -- w/2 ) ; shift right
def_word "2/", "shr", 0
    jsr spull1
    lsr fst + 1
    ror fst + 0
    jmp this

;---------------------------------------------------------------------
; ( -- a ) return next dictionary address
def_word "&", "perse", 0 
    ldy #(ipt)
    jsr spush
    ldx #(ipt)
    lda #2
    jsr incwx
    jmp this

;---------------------------------------------------------------------
; ( a -- ) execute a jump to a reference at top of data stack
def_word "exec", "exec", 0 
    jsr spull1
    jmp (fst)

;---------------------------------------------------------------------
; ( a -- ) execute a jump to reference at ipt
def_word "duck", "duck", 0 
    jmp (ipt)

.endif

;---------------------------------------------------------------------
; core 
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
; ( w2 w1 -- w1 + w2 ) 
def_word "+", "plus", 0
    jsr spull2
    clc
    lda snd + 0
    adc fst + 0
    sta fst + 0
    lda snd + 1
    adc fst + 1
    ; clc ; keep branches 
    jmp keeps

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    jsr spull1
    ldx #(fst)
    ldy #(snd)
    jsr copyfrom
    ;   jmp copys

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
; ( -- c ) ; tos + 1 unchanged
def_word "key", "key", 0
    jsr getchar
    sta fst + 0
    jmp this
    
;---------------------------------------------------------------------
; ( 0 -- $0000) | ( n -- $FFFF)
def_word "0#", "zeroq", 0
    jsr spull1
    lda fst + 1
    ora fst + 0
    bne istrue  ; is \0 ?
isfalse:
    lda #$00
    .byte $2c   ; mask next two bytes, nice trick !
istrue:
    lda #$FF
rest:
    sta fst + 0
    jmp keeps

;---------------------------------------------------------------------
; ( -- state ) a variable return an reference
def_word "s@", "state", 0 
    lda #<stat
    sta fst + 0
    lda #>stat
    jmp keeps 

;---------------------------------------------------------------------
; ( -- sp )
;def_word "sp@", "spat", 0
;    lda spt + 0
;    sta fst + 0
;    lda spt + 1
;    jmp keeps 

;---------------------------------------------------------------------
; ( -- rp )
;def_word "rp@", "rpat", 0
;    lda rpt + 0
;    sta fst + 0
;    lda rpt + 1
;    jmp keeps 

;---------------------------------------------------------------------
; ( c -- ) ; tos + 1 unchanged
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
    ldx #(snd) 
    ldy #(fst) 
    jsr copyinto
    jmp next

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

create:
; copy last into (here)
    ldy #(last)
    jsr comma

; get following token
    jsr token

; copy it
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
    ; clc     ; keep branchs
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
; pull, ipt = (rpt), rpt += 2 
    ldy #(ipt)
    jsr rpull

next:
; wrk = (ipt) ; ipt += 2
    ldx #(ipt)
    ldy #(wrk)
    jsr copyfrom

jump:
    jmp (wrk)

nest:   ; enter
; push, *rp = ipt, rp -=2
    ldy #(ipt)
    jsr rpush

; pull (ip),  
    pla
    sta ipt + 0
    pla
    sta ipt + 1

; 6502 trick: must increase return address 
    ldx #(ipt)
    jsr incwx
    
    jmp next

ends:

;----------------------------------------------------------------------
; anything above is not a primitive
.align $100

init:   

