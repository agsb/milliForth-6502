; 6502 processor
; 6522 VIA chip
; 32KB RAM, 32KB ROM
; 16x2 LCM - 4bit mode

PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
T1CL = $6004
T1CH = $6005
ACR = $600B
IFR = $600D
IER = $600E


COUNT = $0002
toggle_time = $0003


E = %10000000
EB = %01111111
RW = %01000000
RWB = %10111111
RS = %00100000
RSB = %11011111

 .org $8000

reset:
initialize_lcd:
 lda #%11111111 ;Set all PORTA pins to output
 sta DDRA
 lda #%0010 ; Set 4 bit operation
 jsr send_lcd_cmd
 lda #%0010 ; Set 4 bit operation
 jsr send_lcd_cmd
 lda #%1000 ; 2 line display, 5x8 dots
 jsr send_lcd_cmd
 lda #%0000 ; Display control
 jsr send_lcd_cmd
 lda #%1110 ; Display on, cursor on, blink off
 jsr send_lcd_cmd
 lda #%0000 ; Entry mode set
 jsr send_lcd_cmd
 lda #%0110 ; increment cursor, no display shift
 jsr send_lcd_cmd
 lda #%0000 ; Clear display
 jsr send_lcd_cmd
 lda #%0001 ; Clear display
 jsr send_lcd_cmd
 
 ldx #0
print_msg:
 lda message,x
 beq init_done
 ror
 ror
 ror
 ror
 and #%00001111 ; mask the upper nibble (msg)
 jsr send_lcd_data
 lda message,x
 and #%00001111 ; mask the upper nibble
 jsr send_lcd_data
 inx
 jmp print_msg

init_done:

main:
 lda #0
 sta PORTA
 sta COUNT
 sta toggle_time
 lda #$ff
 sta DDRB
 cli ; Enable global interrupt
init_timer:
 lda #%01000000 ;Timer 1 free running mode
 sta ACR
 lda #%11000000 ; Enable timer1 interrupt
 sta IER
 lda #$4e
 sta T1CL
 lda #$c3
 sta T1CH
loop:
 sec
 lda COUNT
 sbc toggle_time
 cmp #10
 bcc loop
 lda #01
 eor PORTB
 sta PORTB
 lda COUNT
 sta toggle_time
 jmp loop
 
send_lcd_cmd:
 jsr lcd_wait
 sta PORTA
 ora #E
 sta PORTA
 and #EB
 sta PORTA
 rts
 
send_lcd_data:
 jsr lcd_wait
 sta PORTA
 ora #RS
 sta PORTA
 ora #E
 sta PORTA
 and #EB
 sta PORTA
 rts
 
message: .asciiz "Hello, World!"

lcd_wait:
 pha
 lda #%11110000 ; set lower nibble in PORTA to input
 sta DDRA
 lda #RW ; Set condition to read busy flag
 sta PORTA
 ora #E
 sta PORTA
lcd_busy:
 lda PORTA
 and #%1000
 bne lcd_busy
 lda #%11111111 ; set PORTA to output
 sta DDRA
 lda #$0
 sta PORTA
 pla
 rts
 
irq:
 bit T1CL ; Clear interrupt flag
 inc COUNT
 rti
 
 .org $FFFC
 .word reset
 .word irq