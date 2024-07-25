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
1. the primitives
   
        +       ( w1 w2 -- w1+w2 ) unsigned addition
        2/      ( w -- w>>1 )  shift right one bit
        nand    ( w1 w2 -- NOT(w1 AND w2) )  not and 
        0#      ( 0 -- 0x0000 | w -- 0xFFFF ) test is tos is diferent of zero
        @       ( a -- w )  fetch the value at reference
        !       ( w a -- )  store the value in reference
        &       ( -- a )  return next ip reference
        s@      ( -- a )  return veriable _state_ absolute reference
        
1. the re-introduce of user area concept as 

        state,     the state of Forth, compile or execute
        toin,      a pointer to next free byte in terminal input buffer
        latest,    a pointer to last word in dictionary
        dpt,       a pointer to next free byte in heap dictionary
        spt,       a pointer to actual top of data stack
        rpt,       a pointer to actual top of return stack
        ipt,       a pointer to next following cell in dictionary

2. the changes on hello-world.FORTH to my-hello-world.FORTH, to incorporate the modifications and recreate some words.
 
3. new words
    
       : dp@ s@ 2 2 2 + + ;
   
       : sp@ dp@ 2 + ;

       : rp@ sp@ 2 + ;

       : ip@ rp@ 2 + ; 
       
       : ip+ ip@ @ 2 + ip@ ! ;

       : dp+ dp@ @ 2 + dp@ ! ;

       : rp+ rp@ @ 2 + rp@ ! ;

       : rp- rp@ @ 2 - rp@ ! ;
   
       : >r rp- rp@ @ ! ;
   
       : r> rp@ @ @ rp+ ;

       : lit ip@ @ @ ip+ ;
   
       : here dp@ @ ;

       : , here ! dp+ ;

       : allot here + dp@ ! ;

4. the new primitive **&**, called perse, to allow access to follow next reference on dictionary.
