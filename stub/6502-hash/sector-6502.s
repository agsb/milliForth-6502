;---------------------------------------------------------------------
;
; Copyright 2023 Alvaro Gomes Sobral Barcellos <@agsb>
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program. If not, see <http://www.gnu.org/licenses/>.
; não 
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
;   This version uses hash djb2 instead of size+name.
;
;   There is no names and no terminal input buffer.
;
;   All data (36 cells) and return (36 cells) stacks, 
;   in same page $200, 256 bytes; 
;
;   Stacks grows backwards;
;
;   No overflow or underflow checks;
;
;   the header order is LINK, HASH, theh CODE;
;
;   only IMMEDIATE flag used as $80 on high byte;
;
;   As ANSI Forth 1994: FALSE is $0000 ; TRUE is $FFFF ;
;
;----------------------------------------------------------------------
;   Remarks:
;
;       this code uses Minimal Indirect Thread Code.
;
;       use a classic cell with 16-bits. 
;
;       no TOS register, all values keeped at stacks;
;
;       use of stream model for input and output;
;
;       there is no lines;
;
;       tokens must be between spaces, before and after;
;
;       tokens are case-sensitivy and no length limit;
;
;       no multiuser, no multitask, no checks, not faster;
;
;       __Chuck Moore uses 64 columns, be wise, obey rule 72 CPL__
;
;       the stat are used as dual byte, stat+0 is STATE and 
;       stat+1 is the IMMEDIATE flag, both tested as bytes
;
;----------------------------------------------------------------------
;   For 6502:
;
;       a 8-bit processor with 16-bit address space;
;       
;       it uses 'little endian' order;
;
;       the most significant byte (MSB) is the page count;
;
;       page zero and page one hardware reserved;
;
;       page zero is used as hardware pseudo registers;
;
;       page one is used by hardware stack;
;
;       page two is forth reserved for stacks;
;
;       page three is forth reserved for user buffers;
;
;       page four and so on is forth code
;
;       hardware stack is not used for this Forth;
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
;   |$00|$01|$02|$03|$04[core..][dictionary..latest..]|here.. $FF|
;   
;   Stacks at page2: 
;
;   |$00  <spt..sp0 $48| <rpt..rp0 $90| free $FE..|$FF..|
;
;   From page 4 onwards:
;
;   |$0400 forth code, primitives | user words | heap ... ceil| 
;
;   Page $FF is reserved.
;
;----------------------------------------------------------------------
;   For Devs:
;
;   the hello_world.forth file states that stacks works
;       to allow : dup sp@ @ ; so sp must point to actual TOS.
;   
;   The movement will be:
;       push is 'decrease and store'
;       pull is 'fetch and increase'
;
;   Never mess with two underscore variables;
;
;   Not using smudge: 
;       colon saves "here" into "peek" and 
;       semis loads "lastest" from "peek";
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
;
;       (w1 w2 w3 -- u1 u2 ; w1 w2 w3 -- u1 u2)
;       
;       S ; R, before -- after, top at right.
;
;       a address 16-bit, c byte ascii, 
;       w signed word, u unsigned word 
;       cs counted string < 256 as c-ascii
;       sz string with zero ends as asciiz
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
;       best macros I had saw for linked list dictionary
;       it can be reorder without define previous or next
;
;   it_label:
;   .word   link_to_previous_entry
;   .dword  hash
;   is_label:
;
; label for primitives
.macro makelabel arg1, arg2
.ident (.concat (arg1, arg2)):
.endmacro

; header for primitives
; the entry point for head is it_~name~
; the entry point for code is is_~name~
.macro def_word name, label, hashed
makelabel "it_", label
.ident(.sprintf("H%04X", hcount + 1)) = *
.word .ident (.sprintf ("H%04X", hcount))
hcount .set hcount + 1
.dword hashed
makelabel "is_", label
; it_last .set it_label
.endmacro

;---------------------------------------------------------------------
; variables for macro def_word

hcount .set 0

H0000 = 0

;---------------------------------------------------------------------
; uncomment to include the tools (sic)
use_tools = 1 

; uncomment to include the extras (sic)
use_extras = 1 

;----------------------------------------------------------------------
;
; alias

; cell size, two bytes, 16-bit
CELL = 2    

; highlander, immediate flag. just compare high byte.
FLAG_IMM = $80

;---------------------------------------------------------------------
; primitives djb2 hash cleared of bit 32
; semmis is immediate (ORA $80)
;
; 32 bits, lowercase !
;
; BEWARE: a $00010203 constant is LSB 03020100 MSB in memory
;

hash_key        = $0B876D32  
hash_emit       = $7C6B87D0  
hash_fetch      = $0002B5E5  
hash_store      = $0002B584  
hash_nand       = $7C727500  
hash_plus       = $0002B58E  
hash_zeroq      = $00596816  
hash_userq      = $00596F90  
hash_semis      = $8002B59E  
hash_colon      = $0002B59F  
hash_exit       = $7C6BBE85  

;---------------------------------------------------------------------
; extras
;
hash_bye        = $0B874AFB  
hash_abort      = $0A1DFF4F  
hash_dot        = $0002B58B  
hash_hex        = $0002B581 
hash_docode     = $0059697A  
hash_lshift     = $562BBE49
hash_rshift     = $7D5F6717 
hash_nan        = $0B8758E4 

;--------------------------------------------------------------------
; tools
;
hash_slist      = $005966B8  
hash_rlist      = $005966B9  
hash_dump       = $7C6B2FE9  
hash_words      = $0B6953F8  

;----------------------------------------------------------------------
.segment "ZERO"

* = $D0
 
; hash djb2 buffer
hashp:
        .dword $0 
hashq:
        .dword $0 
 
; math buffer
maths:
        .word $0
        .word $0
        .word $0
        .word $0
 
;----------------------------------------------------------------------
* = $E0

; order matters for hello_world.forth !
; user variables
sptr:   .word $0 ; data stack base,
rptr:   .word $0 ; return stack base
last:   .word $0 ; last link cell
here:   .word $0 ; next unused cell, aka dpt

stat:   .word $0 ; state at lsb, last size+flag at msb
peek:   .word $0 ; last here before compiling
ceil:   .word $0 ; last unused cell 
void:   .word $0 ; nothing

;----------------------------------------------------------------------
* = $F0

; pointers registers
fst:    .word $0 ; first
snd:    .word $0 ; second
trd:    .word $0 ; third
fth:    .word $0 ; fourth

ipt:    .word $0 ; instruction pointer
wrd:    .word $0 ; word pointer

; temporary
a_save: .byte $0
y_save: .byte $0
x_save: .byte $0
s_save: .byte $0

;----------------------------------------------------------------------
; system stack, reserved
* = $100

;----------------------------------------------------------------------
;.segment "ONCE" 
; no rom code

;----------------------------------------------------------------------
;.segment "VECTORS" 
; no boot code

;----------------------------------------------------------------------
.segment "CODE" 

;----------------------------------------------------------------------
; leave space for page zero, hard stack, forth stacks 

* = $200

; start of data stack
sp0 = $0248

; start of return stack
rp0 = $0290

;----------------------------------------------------------------------
; this page is reserved for user buffers 

* = $300

;----------------------------------------------------------------------
; where the code starts

* = $400

;----------------------------------------------------------------------
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

; h_last and h_here defined elsewhere 

;----------------------------------------------------------------------
warm:
; link list of headers
        lda #<h_last
        sta last + 0
        lda #>h_last
        sta last + 1

; next heap free cell, take a page
        ; lda #<h_here
        ; sta here + 0
        lda #>h_here
        sta here + 1

        ; round up
        lda #0
        sta here + 0
        inc here + 1

; supose never change
        ldy #$02
        spty sptr + 1
        sy rptr + 1

; when not found in dictionary
miss:
        ; emote ??

abort:
        ldy #<(sp0)
        sty sptr + 0

quit:
        ldy #<(rp0)
        sty rptr + 0

; stat is 'execute' == \0
        ldy #0
        sty stat + 0
        
;---------------------------------------------------------------------
; the outer loop

        .byte $2c   ; mask next two bytes, nice trick !

warpit:
        .word warp

;---------------------------------------------------------------------
warp:

.ifdef emote
        ; use high byte of stat for flag
        lda s_save
        beq @100          
        lda #0
        sta s_save

        lda #10
        jsr putchar
        lda #'O'
        jsr putchar
        lda #'K'
        jsr putchar
        lda #10
        jsr putchar
@100:
.endif

; get a token and receive a hash :)
        jsr token

        lda #'?'
        jsr putchar
        jsr phash
        jsr cr

find:
; load last entry
        lda last + 0
        sta snd + 0
        lda last + 1
        sta snd + 1
        
@loop:
; lsb linked list
        lda snd + 0
        sta wrd + 0

; verify \0x0, end of linked list
        ora snd + 1
        beq miss

; msb linked list
        lda snd + 1
        sta wrd + 1

; update next link in snd, wrd + cell, point to hash  
        ldx #wrd ; from 
        ldy #snd ; into
        jsr pull

        lda #'!'
        jsr putchar
        jsr pword
        jsr cr

; compare hashes, for 32 bits

        ldy #0
@a100:
        lda (wrd), y

        cpy #3
        bne @a200
        ; save word immediate flag
        sta stat + 1
        ; mask high byte
        and #$7F
@a200:
        cmp hashp, y
        bne @loop

        iny
        cpy #4
        bne @a100

        lda #'='
        jsr putchar
        jsr pword
        jsr cr

@done:
; update wrd to code, 4 bytes of hash
        lda #4
        ldx #wrd 
        jsr addwx

eval:
; executing ? if == \0
        lda stat + 0   
        beq execute

; immediate ? if < \0
        lda stat + 1
        and #$80
        bne immediate      

compile:
        ;lda #'c'
        ;jsr putchar

        jsr docomma

        ; or branch bcc?
        jmp warp

immediate:
execute:
        ;lda #'e'
        ;jsr putchar

        lda #<warpit
        sta ipt + 0
        lda #>warpit
        sta ipt + 1

        jmp pick

;---------------------------------------------------------------------
; in place crude token,
token:
hash_DJB2 = 5381 ; 32bit $00001505
@hash:
        lda #<hash_DJB2
        sta hashp + 0
        sta hashq + 0
        
        lda #>hash_DJB2
        sta hashp + 1
        sta hashq + 1
        
        lda #0
        sta hashp + 2
        sta hashq + 2
        sta hashp + 3
        sta hashq + 3

@skip:
        jsr getchar
        cmp #' '
        bmi @skip
        beq @skip

@again:
        pha

; multiply by 32

        ldx #5
@loopi:        
        asl hashp + 0
        rol hashp + 1
        rol hashp + 2
        rol hashp + 3
        dex
        bne @loopi

; then add, total 33
        
        ldx #0
        clc
@loopk:
        lda hashp, x
        adc hashq, x
        sta hashp, x
        inx
        cpx #4
        bne @loopk

; xor with character
        pla
        eor hashp + 0
        sta hashp + 0
        
@scan:
        jsr getchar
        ; cmp #' '
        eor #' '
        bmi @scan
        bne @again

;mask:
; clear MSB bit
        lda #$7F
        and hashp + 3
        sta hashp + 3
        
        ; alternative
        clc
        rol hashp + 3
        clc
        ror hashp + 3

        jsr cr
        lda #'~'
        jsr putchar
        jsr phash
        jsr cr

        rts

;---------------------------------------------------------------------
cr:
        lda #10
        jsr putchar
        rts

;---------------------------------------------------------------------
bl:
        lda #32
        jsr putchar
        rts

;---------------------------------------------------------------------
phash:
        lda hashp + 0
        jsr puthex
        lda hashp + 1
        jsr puthex
        lda hashp + 2
        jsr puthex
        lda hashp + 3
        jsr puthex
        rts

;---------------------------------------------------------------------
pword:

        ldy #0
@10:
        lda (wrd), y
        jsr puthex

        iny
        cpy #4
        bne @10

        rts

;---------------------------------------------------------------------
;  this code depends on systems or emulators
;
;  init lib6502  emulator
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
;   exit lib6502 emulator
;
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
;       inc 0, x
;       bne @ends
;       inc 1, x
;@ends:
;       rts

;---------------------------------------------------------------------
; classic heap moves always forward
;
docomma: 
        ldx #here
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
; push a cell 
; from a page zero address indexed by Y
; into a page zero indirect address indexed by X
spush1:
        ldy #fst

;---------------------------------------------------------------------
spush:
        ldx #sptr
        ; jmp push
        .byte $2c   ; mask next two bytes, nice trick !

;---------------------------------------------------------------------
rpush:
        ldx #rptr

;---------------------------------------------------------------------
; from a page zero indirect address indexed by Y
; into a page zero address indexed by X
; also decrease address in X
push:
        jsr decwx
        lda 1, y
        sta (0, x)
        jsr decwx
        lda 0, y
        sta (0, x)
        rts  

;---------------------------------------------------------------------
; pull a cell 
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
;---------------------------------------------------------------------
spull2:
        ldy #snd
        jsr spull
        ; fall through

;---------------------------------------------------------------------
spull1:
        ldy #fst
        ; fall through

;---------------------------------------------------------------------
spull:
        ldx #sptr
        ; jmp pull
        .byte $2c   ; mask next two bytes, nice trick !

;---------------------------------------------------------------------
rpull:
        ldx #rptr

;---------------------------------------------------------------------
; from a page zero indirect address indexed by X
; into a page zero address indexed by y
; also decrease address in X
pull:  
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
;

;----------------------------------------------------------------------

.ifdef use_tools

;----------------------------------------------------------------------
; ( -- ) ae list of data stack
def_word ".S", "splist", hash_slist
        lda sptr + 0
        sta fst + 0
        lda sptr + 1
        sta fst + 1
        lda #'S'
        jsr putchar
        lda #<(sp0)
        jsr list
        jmp next

;----------------------------------------------------------------------
; ( -- ) ae list of return stack
def_word ".R", "rplist", hash_rlist
        lda rptr + 0
        sta fst + 0
        lda rptr + 1
        sta fst + 1
        lda #'R'
        jsr putchar
        lda #<rp0
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
def_word "dump", "dump", hash_dump

        lda #$0
        sta fst + 0
        lda #>(it_ends + 1)
        sta fst + 1

        ldx #fst
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
def_word "words", "words", hash_words

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

; put value
        lda #' '
        jsr putchar

        ldy #1
        lda (fst), y
        jsr puthex
        dey 
        lda (fst), y
        jsr puthex

; next cell
        lda #2
        ldx #fst
        jsr addwx

; check if end of word
        lda fst + 0
        cmp trd + 0
        bne @each

        lda fst + 1
        cmp trd + 1
        bne @each

; check if is a primitive
        lda fst + 1
        cmp #>(it_ends + 1)
        bmi @ends

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

        lda #2
        ldx #trd
        jsr addwx

        jmp @loop 

@ends:
        jmp next


.endif

;----------------------------------------------------------------------

.ifdef use_extras

;----------------------------------------------------------------------
; ( -- ) ae exit forth
def_word "bye", "bye", hash_bye
        jmp byes

;----------------------------------------------------------------------
; ( -- ) ae abort
def_word "abort", "abort", hash_abort
        jmp abort

;---------------------------------------------------------------------
; ( -- ) execute a jump to a reference at IP
def_word ";$", "docode", hash_docode 
        jmp (ipt)
        jmp next

;----------------------------------------------------------------------
; ( w1 u2 -- w2 ) left shit 1 to 15 bits
def_word "lshift", "lshift", hash_lshift
        
        jsr spull2

        ldx fst + 0
@100:
        clc
        rol snd + 0
        rol snd + 1
        dex
        bne @100

        jmp copys

;----------------------------------------------------------------------
; ( w1 u2  -- w2 ) right shift 1 to 15 bits
def_word "rshift", "rshift", hash_rshift
        
        jsr spull2

        ldx fst + 0
@100:
        clc
        ror snd + 0
        ror snd + 1
        dex
        bne @100

        jmp copys

;----------------------------------------------------------------------
; ( -- NaN ) place NaN in data stack
def_word "nan", "nan", hash_nan
is_error:
is_zeros:
is_overs:
is_undes:

        lda #$0
        sta fst + 0
        lda #$80
        sta fst + 1
        jmp this

;----------------------------------------------------------------------
; ( u -- ) next token is a hexadecimal number
def_word "$", "hex", hash_hex
        
        jsr number

        jmp spush1

;----------------------------------------------------------------------
; receive an ASCII hexadecimal value
number:
        lda #0
        sta fst + 0
        sta fst + 1

@skip:
        jsr getchar
        cmp #' '
        bmi @skip
        beq @skip

@again:
        jsr digit
        cmp #$FF
        beq is_error

        pha

        clc
        ldx #4
@100:
        rol fst + 0
        rol fst + 1
        dex
        bne @100

        pla
        
        clc
        adc fst + 0
        sta fst + 0
        adc #0
        sta fst + 1
        
@scan:
        jsr getchar
        cmp #' '
        bmi @scan
        bne @again

        rts

; verify a valid hexadecimal digit
digit:
        sec
        sbc #48
        bmi @error
        
        cmp #10
        bmi @100

        sec
        sbc #7
@100:
        cmp #17
        bpl @error

        rts

; return a digit error
@error:
        lda #$FF
        rts

;----------------------------------------------------------------------
; ( u -- ) print tos in hexadecimal
def_word ".", "dot", hash_dot
        jsr spull1
        lda fst + 1
        jsr puthex
        lda fst + 0
        jsr puthex
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

;----------------------------------------------------------------------
.endif


;---------------------------------------------------------------------
; minimal core primitives
; start of dictionary
;---------------------------------------------------------------------
; ( -- u ) ; tos + 1 unchanged
def_word "key", "key", hash_key
        jsr getchar
        sta fst + 0
        ; jmp this  ; uncomment if char could be \0
        bne this    ; always taken
        
;---------------------------------------------------------------------
; ( u -- ) ; tos + 1 unchanged
def_word "emit", "emit", hash_emit
        jsr spull1
        lda fst + 0
        jsr putchar
        ; jmp next  ; uncomment if carry could be set
        bcc jmpnext ; always taken

;---------------------------------------------------------------------
; ( w1 w2 -- NOT(w1 AND w2) )
def_word "nand", "nand", hash_nand
        jsr spull2
        lda snd + 0
        and fst + 0
        eor j#$FF
        sta fst + 0
        lda snd + 1
        and fst + 1
        eor #$FF
        ; jmp keeps  ; uncomment if carry could be set
        bcc keeps ; always taken

;---------------------------------------------------------------------
; ( w1 w2 -- w1+w2 ) 
def_word "+", "plus", hash_plus
        jsr spull2
        clc  
        lda snd + 0
        adc fst + 0
        sta fst + 0
        lda snd + 1
        adc fst + 1
        clc
        bcc keeps

;---------------------------------------------------------------------
; ( a w -- ) ; [a] = w
def_word "!", "store", hash_store
storew:
        jsr spull2
        ldx #snd 
        ldy #fst 
        jsr copyinto
        ; jmp next  ; uncomment if carry could be set
        bcc jmpnext ; always taken

;---------------------------------------------------------------------
; ( a -- w ) ; w = [a]
def_word "@", "fetch", hash_fetch
fetchw:
        jsr spull1
        ldx #fst
        ldy #snd
        jsr pull
        
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
def_word "0#", "zeroq", hash_zeroq
        jsr spull1
        lda fst + 1
        ora fst + 0
        beq isfalse  
istrue:
        lda #$FF
isfalse:
        sta fst + 0                                                         
        jmp keeps  

;---------------------------------------------------------------------
; ( -- state ) a variable return an reference
def_word "u@", "userq", hash_userq
        lda #<sptr
        sta fst + 0
        lda #>sptr
        beq keeps   ; always taken

;---------------------------------------------------------------------
def_word ":", "colon", hash_colon

        ;lda #'['
        ;jsr putchar

; save here, panic if semis not follow elsewhere
        lda here + 0
        sta peek + 0 
        lda here + 1
        sta peek + 1 

; stat is 'compile'
        lda #1
        sta stat + 0

@header:
; copy last into (here)
        ldy #last

        jsr docomma

; get a token and receive a hash :)
        jsr token

; lower word

        ldy #(hashp+0)

        jsr docomma
        
; upper word

        ldy #(hashp+2)

        jsr docomma

@ends:
        bcc next

;---------------------------------------------------------------------
def_word ";", "semis", hash_semis
        
        ;lda #']'
        ;jsr putchar

; update last, panic if colon not lead elsewhere 
        lda peek + 0 
        sta last + 0
        lda peek + 1 
        sta last + 1

; stat is 'execute'
        lda #0
        sta stat + 0

; compound words must ends with exit
        lda #<is_exit
        sta fst + 0
        lda #>is_exit
        sta fst + 1

finish:
        ldy #fst

        jsr docomma

.ifdef emote
        lda #1
        sta s_save
.endif

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
def_word "exit", "exit", hash_exit
unnest: ; exit
; pull, ipt = (rpt), rpt += 2 
        ldy #ipt
        jsr rpull

next:
; wrd = (ipt) ; ipt += 2
        ldx #ipt
        ldy #wrd
        jsr pull

pick:
; compare pages (MSBs)
        lda wrd + 1
        cmp #>(it_ends + 1) + 1
        bpl nest 

jump: 
        jmp (wrd)

nest:   ; enter
; push, *rp = ipt, rp -=2
        ldy #ipt
        jsr rpush

move:
        lda wrd + 0
        sta ipt + 0
        lda wrd + 1
        sta ipt + 1

        jmp next

;-----------------------------------------------------------------------

h_last = it_exit

;-----------------------------------------------------------------------
; BEWARE, MUST BE AT END! MINIMAL THREAD CODE DEPENDS ON IT!
it_ends:

h_here = it_ends

;-----------------------------------------------------------------------
; anything above is not a primitive
;----------------------------------------------------------------------
.end

