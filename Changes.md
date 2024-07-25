_this file is still a stub_

# Adapt and survive

Due lack of registers and complex instructions, present in x86, the 6502 milliforth review the original code for use of references at page zero and memory access modes.

```
  in x86:
    mov ax, dx

  is 6502:
    lda ax + 0
    sta dx + 0
    lda ax + 1
    sta dx + 1
```

```
in x86:
    mov [bx], ax
    inc bx
    inc bx

is 6502:
    ldx #bx
    ldy #ax
    jsr movs

movs:
    ld (0), y
    sta (0, x)
    jsr incwx
    ld (1), y
    sta (0, x)
    jsr incwx
    rts

incwx:
    inc 0, x
    bcc ends
    inc 1, x
ends:
    rts
       
```
 
2. the proposal of a new primitive **&**, called perse, to allow access to next following cell on dictionary.
   allow
   
       : dp@ s@ 2 2 2 + + ;
       : sp@ dp@ 2 + ;
       : rp@ sp@ 2 + ;
       : ip@ rp@ 2 + ;
   
       : lit  ip@ @ @ ;
       : here dp@ @ ;

4. the re-introduce of user area concept as 

        state,     the state of Forth, compile or execute
        toin,      a pointer to next free byte in terminal input buffer
        latest,    a pointer to last word in dictionary
        dpt,       a pointer to next free byte in heap dictionary
        spt,       a pointer to actual top of data stack
        rpt,       a pointer to actual top of return stack
        ipt,       a pointer to next following cell in dictionary

5. the changes on hello-world.FORTH to my-hello-world.FORTH, to incorporate the modifications and recreate some words.
