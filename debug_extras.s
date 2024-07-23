.if _extras

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

    ; shows ' '

    lda here + 1
    jsr puthex
    lda here + 0
    jsr puthex
    
    ; shows 10

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


; zzzzzzzzzz

.endif

