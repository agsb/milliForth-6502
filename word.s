;---------------------------------------------------------------------
; receive a word between spaces
; also ends at controls
; terminate it with \0
; 
word:
    ldy #0

@wskip:  ; skip spaces
    jsr @wgetch
    bmi @wends
    beq @wskip

@wscan:  ; scan spaces
    jsr @wgetch
    iny
    sta tib, y
    bmi @wends
    bne @wscan

@wends:  ; make a c-string \0
    lda #0
    sta tib, y
    sty tib
    rts

@wgetch: ; receive a char and masks it
    jsr getchar
    and #$7F    ; mask 7-bit ASCII
    cmp #' ' 
    rts

