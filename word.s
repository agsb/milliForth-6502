;
; receive a word between spaces
; quits at any control < 32 or end space
; 
word:
    ldy #0

@skip:  ; skip spaces
    jsr getch
    beq @skip
    bmi @ends

@scan:  ; scan spaces
    jsr getch
    iny
    sta tib, y
    bmi @ends
    bne @scan

@ends:  ; make a c-string, keeps end char
    sty tib
    rts

@getch: ; receive a char and masks it
    jsr getchar
    and #$7F    ; mask 7-bit ASCII
    cmp #' ' 
    rts


