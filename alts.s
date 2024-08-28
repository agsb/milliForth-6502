;----------------------------------------------------------------------
;
;   original for the 6502, by Alvaro G. S. Barcellos, 2023
;
;   https://github.com/agsb 
;   see the disclaimer file in this repo for more information.
;
;   The way at 6502 is use page zero and lots of lda/sta
;
;   why ? For understand better my skills, 6502 code and thread codes
;
;   how ? Programming a new Forth for old 8-bit cpu emulator
;
;   what ? Design the best minimal Forth engine and vocabulary
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
/*
NOTES:

    not finished yet :)

*/
;----------------------------------------------------------------------
;
; alias

; cell size, two bytes, 16-bit
CELL = 2    

;----------------------------------------------------------------------
; no values here or must be a BSS
.segment "ZERO"

* = $E0

; pointers registers

spt:    .word $0 ; data stack base,
rpt:    .word $0 ; return stack base
ipt:    .word $0 ; instruction pointer
wrd:    .word $0 ; word pointer

ptr:    .word $0
tos:    .word $0
nos:    .word $0
tmp:    .word $0

* = $F0

w:  .word $0

tp:  .word $0

sp0: .word $0

sp1: .word $0

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

;spz = $40
;rpz = $80

; data stack, 36 cells,
; moves backwards, push decreases before copy
;.word spz 

; return stack, 36 cells, 
; moves backwards, push decreases before copy
;.word rpz 

;---------------------------------------------------------------------
main:
;
; compare stack models in 6502
;
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
; add a 8bit to a 16bit 
addbx:
    clc
    adc 0, x
    sta 0, x
    lda 1, x
    adc #$00
    sta 1, x
    clc ; keep carry clean
@ends:
    rts

;---------------------------------------------------------------------
; sub a 8bit to a 16bit 
subbx:
    clc
    adc 0, x
    sta 0, x
    lda 1, x
    sbc #$00
    sta 1, x
    clc ; keep carry clean
@ends:
    rts

;---------------------------------------------------------------------
; add a 16bit to a 16bit 
; ( w1 w2 -- w1 w1+w2 )
addwx:
    clc
    lda 0, x
    adc 2, x
    sta 2, x
    lda 1, x
    adc 3, x
    sta 3, x
    clc ; keep carry clean
    rts

;---------------------------------------------------------------------
; sub a 16bit to a 16bit 
; 0,1 tos 2,3 nos
; ( w1 w2 -- w1 w1-w2 )
subwx:
    sec
    lda 0, x
    sbc 2, x
    sta 2, x
    lda 1, x
    sbc 3, x
    sta 3, x
    clc ; keep carry clean
    rts

;---------------------------------------------------------------------
.macro copy into, from 
    lda from + 0
    sta into + 0
    lda from + 1
    sta into + 1
.endmacro

;---------------------------------------------------------------------
;   using stack at any page
;   minimal use of page zero and page one
;       x   byte, word in page zero
;       y   byte, index of stack 
;       z   word, pointer to top of stack, grows downsize
;---------------------------------------------------------------------
; Eg:
;
;   ldx from
;   ldy index
;   copy z, stack 
;
;   jsr jolt
;
;   ldx z
;   jsr decwx
;   jsr decwx
;   
;   copy stack, z
;
;---------------------------------------------------------------------
; R = --(M)
; 
jolt:   
    dey
    lda (tp), y
    sta 1, x
    dey
    lda (tp), y
    sta 0, x
    rts

;---------------------------------------------------------------------
; (M)++ = R   
;
yank:   
    lda 0, x
    sta (tp), y
    iny
    lda 1, x
    sta (tp), y
    iny
    rts

;---------------------------------------------------------------------
; R = (M)++
;
pull:   
    lda (tp), y
    iny
    sta 0, x
    lda (tp), y
    iny
    sta 1, x
    rts

;---------------------------------------------------------------------
; --(M) = R
; 
push:   
    lda 1, x
    dey
    sta (tp), y
    lda 0, x
    dey
    sta (tp), y
    rts

;---------------------------------------------------------------------
; using hardware stack
;
;
pushs:
 lda #40   ; word to use
 ldy #80   ; stack to use
 clc ; to push
 ;sec ; to pull
 jsr stack
;
pulls:
 lda #40   ; word to use
 ldy #80   ; stack to use
 ; clc ; to push
 sec ; to pull
 jsr stack
;
stack:
    tsx 
    stx sp0
    ldx 0, y
    txs
    tax
    bcc @push
@pull:
    pla 
    sta 1, x 
    pla
    sta 0, x
    bcs @ends
@push:
    lda 0, x 
    pha 
    lda 1, x
    pha
    tsx
@ends:
    tsx
    stx 0, y
    ldx sp0
    txs
    rts

;---------------------------------------------------------------------
ends:
