
; there is no edit capabilities, 
; nor \b nor \u nor cursor nor line ;)
token:
    ldy #1

@skip:
    jsr getchar
    cmp #$FF
    beq byes
    cmp #' ' 
    beq @skip

@scan:
    cmp #10     ; if \n
    beq @ends
    sta tib, y
    iny
    ; cpy #16     ; if maxsize
    ; bpl @ends
    jsr getchar
    cmp #' '
    bne @scan

@ends:
    lda #' '
    sta tib, y
    dey
    sty tib
    rts

byes:
    jmp $0000


