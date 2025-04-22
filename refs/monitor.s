; AlexMon Monitor by Adumont
;
; Copyright (C) 2021-2023 Alexandre Dumont <adumont@gmail.com>
;
; SPDX-License-Identifier: GPL-3.0-only

;
; Monitor will show content at ADDR.
; You can type:
; - an ADDR (4 char, hex) --> set ADDR
; - a value (2 char, hex) --> store value at ADDR
; - ' followed by a char  --> store the char at ADDR
; - j --> restore registers to saved values and jump to ADDR
; - c --> continue (after a BRK). restore registers to saved values, set ADDR to saved PC (after BRK) and jump to ADDR
;
; Registers manipulation (saved values):
; - aXX : store XX (hex) in A
; - xXX : store XX (hex) in X
; - yXX : store XX (hex) in Y
; - sXX : store XX (hex) in S
; - pXX : store XX (hex) in P
; - r   : print registers value
;
; help: https://cc65.github.io/doc/ca65.html

.pc02 ; 65C02 mode
.debuginfo      +       ; Generate debug info

.segment  "CODE"

_init:

	BRA loop

inc_addr:
	; we increment ADDR
	INC z:MON_ADDR		; ADDR LO++
	BNE put_newline		; show_addr
	INC z:MON_ADDR+1	; ADDR HI++
	; fallback to put_newline

put_newline:
	JSR CRLF
	; fallback to loop

loop:
	; show address
	LDA z:MON_ADDR+1
	JSR print_byte
	LDA z:MON_ADDR
	JSR print_byte

	; show value at addr
	LDA #':'
	JSR putc

	LDY #0
	LDA (MON_ADDR),y
	TAX		; we use X to save the VALUE
	JSR print_byte	; print byte at ADDR

	LDA #' '
	JSR putc

	CPX #$20
	BMI non_printable	; not printable (too low)
	CPX #$7E
	BPL non_printable	; not printable (too low)

	TXA
	JSR putc
	JMP prompt

non_printable:
	; print a blank char
	LDA #' '
	JSR putc

prompt:
	LDA #' '
	JSR putc
	LDA #'?'
	JSR putc
	LDA #' '
	JSR putc

	JSR getline

	CMP #$0d ; LF
	BEQ cmd_return
	; here user hit ESC

cmd_esc:
	; here we do whatever to handle an ESC
	LDA #'E'
	JSR putc
	lda #'S'
	JSR putc
	lda #'C'
	JSR putc
	JMP put_newline

cmd_return:
	; here we do whatever to handle a RETURN

	; decision tree depending on the length
	; (length is still stored in X at this pointtp)

	CPX #0	; user has just hit return again?
	BEQ inc_addr

	LDA CMD	 ; first char

	CMP #'r'		; Print Registers
	BEQ preg_cmd

	CMP #$27		; starts with simple quote '
	BEQ it_is_a_char

	CMP #'j'		; Jmp
	BEQ exec_cmd

	CPX #2			; 2 chars --> a value
	BEQ it_is_a_value

	CPX #4			; 4 chars --> an addr
	BEQ it_is_an_addr

	CMP #'c'		; Continue
	BEQ cont_cmd

	CPX #3
	BNE error

	TAY	; we store the letter in Y

	LDX #1
	JSR scan_ascii_byte

	CPY #'a'		; edit A
	BEQ editA_cmd

	CPY #'x'		; edit X
	BEQ editX_cmd

	CPY #'y'		; edit Y
	BEQ editY_cmd

	CPY #'s'		; edit S
	BEQ editS_cmd

	CPY #'p'		; edit P
	BEQ editP_cmd

	; ELSE
	JMP error

cont_cmd:
	LDA MON_PC
	STA z:MON_ADDR
	LDA MON_PC+1
	STA z:MON_ADDR+1
	; fallback to exec_cmd

exec_cmd:
	LDA MON_P
	PHA
	PLP		; transfer to P
	LDX MON_S
	TXS
	LDY MON_Y
	LDX MON_X
	LDA MON_A

	JMP (MON_ADDR)
	; we don't know were wi'll end up...

it_is_a_char:
	LDX #1		; we load the 2nd byte of CMD
	LDA CMD,x	; into A

	STA (MON_ADDR),y	; and store at ADDR

	JMP inc_addr

it_is_a_value:
	LDX #0
	JSR scan_ascii_byte

	LDY #0
	STA (MON_ADDR),y

	JMP inc_addr

it_is_an_addr:
	LDX #0
	JSR scan_ascii_addr
	JMP put_newline

preg_cmd:
	JSR Print_Registers
	JMP put_newline

editA_cmd:
	sta MON_A
	JMP put_newline

editX_cmd:
	sta MON_X
	JMP put_newline

error:
	LDA #'E'
	JSR putc
	lda #'R'
	JSR putc
	lda #'R'
	JSR putc

	JMP put_newline ; and loop

editY_cmd:
	sta MON_Y
	JMP put_newline

editS_cmd:
	sta MON_S
	JMP put_newline

editP_cmd:
	ORA #$30 ; we force bits 4 and 5 to 1
	STA MON_P
	JMP put_newline

print_byte:
	PHA	; save A for 2nd nibble
	LSR	; here we shift right
	LSR	; to get HI nibble
	LSR
	LSR
	JSR nibble_value_to_asc
	JSR putc

	PLA
	AND #$0F ; LO nibble
	JSR nibble_value_to_asc
	JMP putc

CRLF:
	; output a CR+LF
	LDA #$0a ; CR
	JSR putc
	LDA #$0d ; LF
	JMP putc

getline:
	LDX #0
next:
	JSR getc

	CMP #$0D	; LF (enter)?
	BEQ eol

	CMP #$1B 	; ESC
	BEQ eol

	CMP #$08 	; Backspace
	BEQ backspace

;	CMP #'9'+1
;	BMI skip_uppercase
;	AND #$DF 	; make upper case
;skip_uppercase:
	STA CMD,x	; save in buffer

	CPX #$0F	; x=15 -> end line
	BEQ eol

	INX
	JSR putc	; echo char
	JMP next	; wait for next

backspace:
	CPX #0
	BEQ next
	DEX
	JSR putc	; echo char
	JMP next

eol:
	STX LEN
	RTS

nibble_asc_to_value:
; converts a char representing a hex-digit (nibble)
; into the corresponding hex value
	CMP #$41
	BMI less
	SBC #$37
less:
	AND #$0F
	RTS

nibble_value_to_asc:
	CMP #$0A
	BCC skip
	ADC #$66
skip:
	EOR #$30
	RTS

scan_ascii_addr:
	LDA CMD,X	; load char into A
	JSR nibble_asc_to_value
	ASL
	ASL
	ASL
	ASL
	STA z:MON_ADDR+1

	INX
	LDA CMD,X	; load char into A
	JSR nibble_asc_to_value

	ORA z:MON_ADDR+1
	STA z:MON_ADDR+1

	INX
	LDA CMD,X	; load char into A
	JSR nibble_asc_to_value
	ASL
	ASL
	ASL
	ASL
	STA z:MON_ADDR

	INX
	LDA CMD,X	; load char into A
	JSR nibble_asc_to_value
	ORA z:MON_ADDR
	STA z:MON_ADDR

	RTS

scan_ascii_byte:
	LDA CMD,X	; load char into A
	JSR nibble_asc_to_value
	ASL
	ASL
	ASL
	ASL
	STA BYTE

	INX
	LDA CMD,X	; load char into A
	JSR nibble_asc_to_value
	ORA BYTE
	STA BYTE
	RTS

Print_Registers:
	JSR CRLF
	LDA #'A'
	JSR putc
	LDA MON_A
	JSR print_byte

	LDA #' '
	JSR putc
	LDA #'X'
	JSR putc
	LDA MON_X
	JSR print_byte

	LDA #' '
	JSR putc
	LDA #'Y'
	JSR putc
	LDA MON_Y
	JSR print_byte

	LDA #' '
	JSR putc
	LDA #'P'
	JSR putc
	LDA MON_P
	JSR print_byte

	LDA #' '
	JSR putc
	LDA #'S'
	JSR putc
	LDA MON_S
	JSR print_byte

	LDA #' '
	JSR putc
	LDA #'P'
	JSR putc
	LDA #'C'
	JSR putc
	LDA MON_PC+1
	JSR print_byte
	LDA MON_PC
	JSR print_byte
	RTS

IO_AREA = $F000

getc:
	LDA IO_AREA+4

	BEQ getc
	RTS

putc:
	STA IO_AREA+1
	RTS


; -----------------------------------------------------------------------

; -----------------------------------------------------------------------
; Non-maskable interrupt (NMI) service routine

_nmi_int:  RTI                    ; Return from all NMI interrupts

; -----------------------------------------------------------------------
; Maskable interrupt (IRQ) service routine

_irq_int:
	; Save registers
	STX MON_X							; before    |  xx   |  after the
	STY MON_Y							; interrupt |  xx   |  interrupt
	STA MON_A							;           |  xx   |
	TSX		; get current SP into X		;  old SP ->| PC HI |  SP+3
										;           | PC LO |  SP+2
	LDA $0102,X	; SP+2 -> PC LO			;           |   P   |  SP+1
	STA MON_PC							;           |       | <- SP (new SP)
										;
	LDA $0103,X	; SP+3 -> PC HI			;
	STA MON_PC+1						;

	LDA $0101,X	; SP+1 -> P
	STA MON_P

	INX		; add 3 to get
	INX		; SP before IRQ
	INX
	STX MON_S

	; is it a BRK?
	LDA #$10	; position of B bit
	BIT MON_P	; is B bit set, indicating BRK and not IRQ?
	BNE BRKhandler

  ; here it's not a BRK
  ; Another type of IRQ then...
	LDA #'i'
	JSR putc
	LDA #'r'
	JSR putc
	LDA #'q'
	JSR putc

	LDY MON_Y
	LDX MON_X
	LDA MON_A
	RTI

BRKhandler:
  CLI   ; we reenable Interrupts (in case other more urgent IRQ arrives)
	JSR Print_Registers

	LDX MON_S
	TXS
	LDY MON_Y
	LDX MON_X
	LDA MON_A

  CLI
	JMP put_newline
	;RTI

; -----------------------------------------------------------------------
; Constants! (for variables, see .DATA)
.RODATA
MSG:    .asciiz "adumont 6502"

; -----------------------------------------------------------------------
; reserve space for global variables

.ZEROPAGE
MON_ADDR:	.res    2	; // NOTICE remember to use z:MON_ADDR to force zeropage addressing.

; for variables we want to have initialized, and be able to modify later. Requires copydata.s!
; for reserving space only, use .BSS
.DATA

.BSS
BYTE:	.res 1
LEN:	.res 1	; Length of CMD
CMD:	.res 16	; CMD string
MON_A:	.res 1
MON_X:	.res 1
MON_Y:	.res 1
MON_S:	.res 1
MON_P:	.res 1
MON_PC:	.res 2

.segment  "VECTORS"

.addr      _nmi_int    ; NMI vector
.addr      _init       ; Reset vector
.addr      _irq_int    ; IRQ/BRK vector
