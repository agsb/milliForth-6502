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
;----------------------------------------------------------------------
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
;----------------------------------------------------------------------
;   Remarks:
;
;       this code uses 
;           Direct Thread Code, aka DTC or
;           Minimal Thread Code, aka MTC.
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
;           ( later maybe \b backspace and \u cancel )
;
;       words are case-sensitivy and less than 16 characters;
;
;       no need named-'pad' at end of even names;
;
;       no multiuser, no multitask, no checks, not faster;
;
;----------------------------------------------------------------------
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
;----------------------------------------------------------------------
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
;   From page 3 onwards:
;
;   |$0300 cold:, warm:, forth code, init: here> heap ... tail| 
;
;   PIC is a transient area of 32 bytes 
;   PAD could be allocated from here
;
;----------------------------------------------------------------------
;   For Devs:
;
;   the hello_world.forth file states that stacks works
;       to allow : dup sp@ @ ; so sp must point to actual TOS.
;   
;   The movement will be:
;       pull is 'fetch and increase'
;       push is 'decrease and store'
;
;   Never mess with two underscore variables;
;
;   Not using smudge, 
;       colon saves "here" into "back" and 
;       semis loads "lastest" from "back";
;
;   Do not risk to put stacks with $FF.
;
;   Also carefull inspect if any label ends with $FF and move it;
;
;   This source is hacked for use with Ca65.
;
;----------------------------------------------------------------------
;
;   Stacks represented as (standart)
;       S:(w1 w2 w3 -- u1 u2)  R:(w1 w2 w3 -- u1 u2)
;       before -- after, top at left.
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
; macros for dictionary, makes:
;
;   h_name:
;   .word  link_to_previous_entry
;   .byte  strlen(name) + flags
;   .byte  name
;   name:
;
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
; define thread code model
; MTC is default
; use_DTC = 1

; uncomment to include the extras (sic)
 use_extras = 1 

; uncomment to include the extensions (sic)
 use_extensions = 1 

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

; terminal input buffer, forward
; getline, token, skip, scan, depends on page boundary
tib = $0200

; reserve 80 bytes, (72 is enough) 
; moves forwards
tib_end = $50

; data stack, 36 cells,
; moves backwards, push decreases before copy
sp0 = $98

; return stack, 36 cells, 
; moves backwards, push decreases before copy
rp0 = $E0

; reserved for scribbles
pic = rp0

;----------------------------------------------------------------------
; no values here or must be a BSS
.segment "ZERO"

* = $E0

nil:  ; empty for fixed reference

; as user variables
; order matters for hello_world.forth !

; internal Forth 

stat:   .word $0 ; state at lsb, last size+flag at msb
toin:   .word $0 ; toin next free byte in TIB
last:   .word $0 ; last link cell
here:   .word $0 ; next free cell in heap dictionary, aka dpt

; pointers registers

spt:    .word $0 ; data stack base,
rpt:    .word $0 ; return stack base
ipt:    .word $0 ; instruction pointer
wrd:    .word $0 ; word pointer

* = $F0

; free for use

fst:    .word $0 ; first
snd:    .word $0 ; second
trd:    .word $0 ; third
fth:    .word $0 ; fourth

; used, reserved

tout:   .word $0 ; next token in TIB
back:   .word $0 ; hold 'here while compile

; for future expansion, reserved
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
; common must
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

; next heap free cell, same as init:  
    lda #>ends + 1
    sta here + 1
    lda #0
    sta here + 0

;---------------------------------------------------------------------
; supose never change
reset:
    ldy #>tib
    sty spt + 1
    sty rpt + 1
    sty toin + 1
    sty tout + 1

abort:
    ldy #<sp0
    sty spt + 0

quit:
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

resolvept:
    .word okey

;---------------------------------------------------------------------
okey:

;;   uncomment for feedback
;    lda stat + 0
;    bne resolve
;    lda #'O'
;    jsr putchar
;    lda #'K'
;    jsr putchar
;    lda #10
;    jsr putchar

resolve:
; get a token
    jsr token

    ; lda #'P'
    ; jsr putchar

find:
; load last
    lda last + 1
    sta snd + 1
    lda last + 0
    sta snd + 0
    
@loop:
; lsb linked list
    lda snd + 0
    sta wrd + 0

; verify \0x0
    ora snd + 1
    beq abort

;   maybe to place a code for number? 
;   but not for now.

;;   uncomment for feedback, comment out "beq abort" above
;    lda #'?'
;    jsr putchar
;    lda #'?'
;    jsr putchar
;    lda #10
;    jsr putchar
;    jmp abort  ; end of dictionary, no more words to search, abort

@each:    

; msb linked list
    lda snd + 1
    sta wrd + 1

; update next link 
    ldx #(wrd) ; from 
    ldy #(snd) ; into
    jsr copyfrom

; compare words
    ldy #0

; save the flag, first byte is (size and flag) 
    lda (wrd), y
    sta stat + 1

; compare chars
@equal:
    lda (tout), y
; space ends
    cmp #32  
    beq @done
; verify 
    sec
    sbc (wrd), y     
; clean 7-bit ascii
    asl        
    bne @loop

; next char
    iny
    bne @equal

@done:
; update wrd
    tya
    ;; ldx #(wrd) ; set already
    ;; addwx also clear carry
    jsr addwx
    
eval:
; executing ? if == \0
    lda stat + 0   
    beq execute

; immediate ? if < \0
    lda stat + 1   
    bmi immediate      

compile:

    ; lda #'C'
    ; jsr putchar

    jsr wcomma

    bcc resolve

immediate:
execute:

    ; lda #'E'
    ; jsr putchar

    lda #>resolvept
    sta ipt + 1
    lda #<resolvept
    sta ipt + 0

;~~~~~~~~
.ifdef use_DTC

    jmp (wrd)

.else 
    
    jmp pick

.endif
;~~~~~~~~

    
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
    ldy #0
@loop:  
; is valid
    sta tib, y  ; dummy store on first pass, overwritten
    iny
; would be better with 
; end of buffer ?
;    cpy #tib_end
;    beq @ends
; then 
    jsr getchar
; would be better with 
; 7-bit ascii only
;    and #$7F        
; unix \n
    cmp #10         
    bne @loop
; would be better with 
; no controls
;    cmp #' '
;    bmi @loop

; clear all if y eq \0
@ends:
; grace \b
    lda #32
    sta tib + 0 ; start with space
    sta tib, y  ; ends with space
; mark eol with \0
    lda #0
    sta tib + 1, y
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

; keep y == start + 1
    dey
    sty tout + 0

@scan:
; scan spaces
    jsr try
    bne @scan

; keep y == stop + 1  
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
    clc     ; clean 
    rts

;---------------------------------------------------------------------
;  this code depends on systems or emulators
;
;  lib6502  emulator
; 
getchar:
    lda $E000

eofs:
; EOF ?
    cmp #$FF ; also clean carry :)
    beq byes

putchar:
    sta $E000
    rts

; exit for emulator  
byes:
    jmp $0000

;
;   lib6502 emulator
;---------------------------------------------------------------------

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
; classic heap moves always forward
;
stawrd:
    sta wrd + 1

wcomma:
    ldy #(wrd)

comma: 
    ldx #(here)
    ; fall throught

;---------------------------------------------------------------------
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
copyinto:
    lda 0, y
    sta (0, x)
    jsr incwx
    lda 1, y
    sta (0, x)
    jmp incwx

;---------------------------------------------------------------------
;
; generics 
;
;---------------------------------------------------------------------
spush1:
    ldy #(fst)

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
    rts  

;---------------------------------------------------------------------
spull2:
    ldy #(snd)
    jsr spull
    ; fall through

;---------------------------------------------------------------------
spull1:
    ldy #(fst)
    ; fall through

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
pull:   ; fall through, same as copyfrom

;---------------------------------------------------------------------
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
copyfrom:
    lda (0, x)
    sta 0, y
    jsr incwx
    lda (0, x)
    sta 1, y
    ; jmp incwx ; fall through

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
    clc ; keep carry clean
@ends:
    rts

;---------------------------------------------------------------------
;
; the primitives, 
; for stacks uses
; a address, c byte ascii, w signed word, u unsigned word 
; cs counted string < 256, sz string with nul ends
; 
;----------------------------------------------------------------------

.ifdef use_extras

;----------------------------------------------------------------------
; extras
;----------------------------------------------------------------------
; ( -- ) ae exit forth
def_word "bye", "bye", 0
    jmp byes

;----------------------------------------------------------------------
; ( -- ) ae abort
def_word "abort", "abort_", 0
    jmp abort

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
; ( -- ) dumps the user dictionary
def_word "dump", "dump", 0

    lda #$0
    sta fst + 0
    lda #>ends + 1
    sta fst + 1

    ldx #(fst)
    ldy #0

@loop:
    
    lda (fst),y
    jsr putchar
    jsr incwx

    lda fst + 0
    cmp here + 0
    bne @loop

    lda fst + 1
    cmp here + 1
    bne @loop

    clc  ; clean
    jmp next 

;----------------------------------------------------------------------
; ( -- ) words in dictionary, 
def_word "words", "words", 0

; load lastest
    lda last + 1
    sta snd + 1
    lda last + 0
    sta snd + 0

; load here
    lda here + 1
    sta trd + 1
    lda here + 0
    sta trd + 0
    
@loop:
; lsb linked list
    lda snd + 0
    sta fst + 0

; verify \0x0
    ora snd + 1
    beq @ends

; msb linked list
    lda snd + 1
    sta fst + 1

@each:    

    lda #10
    jsr putchar

; put address
    lda #' '
    jsr putchar

    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex

; put link
    lda #' '
    jsr putchar

    ldy #1
    lda (fst), y
    jsr puthex
    dey 
    lda (fst), y
    jsr puthex

    ldx #(fst)
    lda #2
    jsr addwx

; put size + flag, name
    ldy #0
    jsr show_name

; update
    iny
    tya
    ldx #(fst)
    jsr addwx

; show CFA

    lda #' '
    jsr putchar
    
    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex

; check if is a primitive
    lda fst + 1
    cmp #>ends + 1
    bmi @continue

; list references
    ldy #0
    jsr show_refer

@continue:
    
    lda snd + 0
    sta trd + 0
    lda snd + 1
    sta trd + 1

    ldy #0
    lda (trd), y
    sta snd + 0
    iny
    lda (trd), y
    sta snd + 1

    ldx #(trd)
    lda #2
    jsr addwx

    jmp @loop 

@ends:
    clc  ; clean
    jmp next

;----------------------------------------------------------------------
; ae put size and name 
show_name:
    lda #' '
    jsr putchar

    lda (fst), y
    jsr puthex
    
    lda #' '
    jsr putchar

    lda (fst), y
    and #$7F
    tax

 @loop:
    iny
    lda (fst), y
    jsr putchar
    dex
    bne @loop

@ends:
    rts

;----------------------------------------------------------------------
show_refer:
; ae put references PFA ... 

    ldx #(fst)

@loop:
    lda #' '
    jsr putchar

    lda fst + 1
    jsr puthex
    lda fst + 0
    jsr puthex

    lda #':'
    jsr putchar
    
    iny 
    lda (fst), y
    jsr puthex
    dey
    lda (fst), y
    jsr puthex

    lda #2
    jsr addwx

; check if ends

    lda fst + 0
    cmp trd + 0
    bne @loop
    lda fst + 1
    cmp trd + 1
    bne @loop

@ends:
    rts

;----------------------------------------------------------------------
;  ae seek for 'exit to ends a sequence of references
;  max of 254 references in list
;
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
    tya
    lsr
    clc  ; clean
    rts

;----------------------------------------------------------------------
; ( u -- u ) print tos in hexadecimal, swaps order
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
@ends:
    clc  ; clean
    jmp putchar

.endif


.ifdef numbers
;----------------------------------------------------------------------
; code a ASCII $FFFF hexadecimal in a byte
;  
number:

    ldy #0

    jsr @very
    asl
    asl
    asl
    asl
    sta fst + 1

    iny 
    jsr @very
    ora fst + 1
    sta fst + 1
    
    iny 
    jsr @very
    asl
    asl
    asl
    asl
    sta fst + 0

    iny 
    jsr @very
    ora fst + 0
    sta fst + 0

    clc ; clean
    rts

@very:
    lda (tout), y
    sec
    sbc #$30
    bmi @erro
    cmp #10
    bcc @ends
    sbc #$07
    ; any valid digit, A-Z, do not care 
@ends:
    rts

@erro:
    pla
    pla
    rts

.endif

;---------------------------------------------------------------------
;
; extensions
;
;---------------------------------------------------------------------
.ifdef use_extensions

;---------------------------------------------------------------------
; ( w -- w/2 ) ; shift right
def_word "2/", "shr", 0
    jsr spull1
    lsr fst + 1
    ror fst + 0
    jmp this

;---------------------------------------------------------------------
; ( a -- ) execute a jump to a reference at top of data stack
def_word "exec", "exec", 0 
    jsr spull1
    jmp (fst)

;---------------------------------------------------------------------
; ( -- ) execute a jump to a reference at IP
def_word ":$", "docode", 0 
    jmp (ipt)

;---------------------------------------------------------------------
; ( -- ) execute a jump to next
def_word ";$", "donext", 0 
    jmp next

.endif

;---------------------------------------------------------------------
; core primitives minimal 
; start of dictionary
;---------------------------------------------------------------------
; ( -- u ) ; tos + 1 unchanged
def_word "key", "key", 0
    jsr getchar
    sta fst + 0
    ; jmp this  ; uncomment if char could be \0
    bne this    ; always taken
    
;---------------------------------------------------------------------
; ( u -- ) ; tos + 1 unchanged
def_word "emit", "emit", 0
    jsr spull1
    lda fst + 0
    jsr putchar
    ; jmp next  ; uncomment if carry could be set
    bcc jmpnext ; always taken

;---------------------------------------------------------------------
; ( a w -- ) ; [a] = w
def_word "!", "store", 0
storew:
    jsr spull2
    ldx #(snd) 
    ldy #(fst) 
    jsr copyinto
    ; jmp next  ; uncomment if carry could be set
    bcc jmpnext ; always taken

;---------------------------------------------------------------------
; ( w1 w2 -- NOT(w1 AND w2) )
def_word "nand", "nand", 0
    jsr spull2
    lda snd + 0
    and fst + 0
    eor #$FF
    sta fst + 0
    lda snd + 1
    and fst + 1
    eor #$FF
    ; jmp keeps  ; uncomment if carry could be set
    bcc keeps ; always taken

;---------------------------------------------------------------------
; ( w1 w2 -- w1+w2 ) 
def_word "+", "plus", 0
    jsr spull2
    clc  ; better safe than sorry
    lda snd + 0
    adc fst + 0
    sta fst + 0
    lda snd + 1
    adc fst + 1
    jmp keeps

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", 0
fetchw:
    jsr spull1
    ldx #(fst)
    ldy #(snd)
    jsr copyfrom
    ; fall throught

;---------------------------------------------------------------------
copys:
    lda 0, y
    sta fst + 0
    lda 1, y

keeps:
    sta fst + 1

this:
    jsr spush1

jmpnext:
    jmp next

;---------------------------------------------------------------------
; ( 0 -- $0000) | ( n -- $FFFF) not zero at top ?
def_word "0#", "zeroq", 0
    jsr spull1
    lda fst + 1
    ora fst + 0
    beq isfalse  ; is \0 ?
istrue:
    lda #$FF
isfalse:
    sta fst + 0                                                         
    jmp keeps  

;---------------------------------------------------------------------
; ( -- state ) a variable return an reference
def_word "s@", "state", 0 
    lda #<stat
    sta fst + 0
    lda #>stat
    ;  jmp keeps ; uncomment if stats not in page $0
    beq keeps   ; always taken

;---------------------------------------------------------------------
def_word ";", "semis",  FLAG_IMM
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
    sta wrd + 0
    lda #>exit
    sta wrd + 1
    jsr wcomma

    ; jmp next
    bcc next    ; always taken

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

@header:
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
    tya
    ldx #(here)
    jsr addwx

;~~~~~~~~
.ifdef use_DTC

; magic NOP (EA) JSR (20), at CFA cell
; magic = $EA20

magic = $20EA

; inserts the nop call
    lda #<magic
    sta wrd + 0
    lda #>magic
    jsr stawrd

; inserts the reference
    lda #<nest
    sta wrd + 0
    lda #>nest
    jsr stawrd

.endif
;~~~~~~~~

; done
    ; jmp next
    bcc next    ; always taken

;---------------------------------------------------------------------
; Thread Code Engine
;
;   ipt is IP, wrd is W
;
; for reference: 
;
;   nest aka enter or docol, 
;   unnest aka exit or semis;
;
;---------------------------------------------------------------------
; ( -- ) 
def_word "exit", "exit", 0
unnest: ; exit
; pull, ipt = (rpt), rpt += 2 
    ldy #(ipt)
    jsr rpull

next:
; wrd = (ipt) ; ipt += 2
    ldx #(ipt)
    ldy #(wrd)
    jsr copyfrom

;~~~~~~~~
.ifdef use_DTC

pick:
    jmp (wrd)

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

    bcc next

.else

pick:
; compare pages (MSBs)
    lda wrd + 1
    cmp #>ends + 1
    bmi jump

nest:   ; enter
; push, *rp = ipt, rp -=2
    ldy #(ipt)
    jsr rpush

    lda wrd + 0
    sta ipt + 0
    lda wrd + 1
    sta ipt + 1

    jmp next

jump: 

    jmp (wrd)

.endif
;~~~~~~~~

;-----------------------------------------------------------------------
; BEWARE, MUST BE AT END! MINIMAL THREAD CODE DEPENDS ON IT!
ends:
;-----------------------------------------------------------------------
; anything above is not a primitive
;----------------------------------------------------------------------

