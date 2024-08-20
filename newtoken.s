
; there is no edit capabilities, 
; nor \b nor \u nor cursor nor line ;)
token:
    ldy #1

@skip:
    jsr getch
    cmp #' ' 
    beq @skip

@scan:
    jsr getch
    sta tib, y
    iny
    cmp #' '
    bne @scan

@ends:
    lda #' '
    sta tib, y
    dey
    sty tib
    rts

@getch:
    jsr getchar
    cmp #10
    beq @ends
    cmp #$FF
    beq byes
    rts

byes:
    jmp $0000


