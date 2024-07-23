
## Coding

 done - still no _'OK'_ or _'NO'_;
- still no backspace routine for \b; 
- still no cancel line routine for \u; 

## Time table 

_23/07/2024_ 

    working in .S and .R

_17/07/2024_

    All words using sp till >r r> are working
    but any using r> r> breaks. 
    Need review 

_15/07/2024_

    first compiled run with full hello_world.FORTH ! 
    but ." is still looping

    all words with IMMEDIATE flag are working
    all stack and heap moves are working
    all dictionary are working

    what was ? really ? 
    the sp@ and rp@ are indirect (spt) and (rpt)
    but s@ is absolute direct #<stat, as VARIABLE

_11/07/2024_

    The original hello_world.forth file states that : dup sp@ @ ; 
    then sp must point to actual TOS, and movements are                                           
           push is 'decrease and store'                                
           pull is 'fetch and increase'                                

_09/07/2024

    Made a version for DTC-TOS for parallel debugs

_04/07/2024_

    erase all indirect references for offset pseudo registers

    using TOS in a pseudo register

_26/06/2024_

   In debug mode, It's still a mess, don't get lost !!!

    something wrong at end of execution of compound words, 
    exit should break the sequence of references
    the nest and unnest for deep-search seems work well

    guilty by abuse of pla/pha 

_28/06/2024_ 
    
    Found a bug: exit must drop top of return stack 

_19/06/2024_ 

    Great review of heap and stack core code, 
    reorder tib, sp, rp, pad.

_16/06/2024_ 
    
    Return to MITC paradigm.
    it will grow the size of code, but will work.
    todo a real DTC code, later.

_15/06/2024_ 
    
    I found the big mistake ! Mix DTC and MITC.
    The compare with init: was a great mistake.
    Some assembler code could lead to wrong comparations.
    For MITC primitives must have a NULL.

_12/06/2024_ 

    random error in list the values 
    from $00E0 to $00FF, at return
    can not catch why

_11/06/2024_ 

    return and change model for 'minimal indirect thread code'
    with lots of debugging code to find errors. 
    Renaming main file for it

_01/05/2024_ 
            
    I'm on vacancy to reflesh some ideas

_30/01/2024_ 

    doing debugs for DTC inner 

_28/01/2024_ code for 6502 sized to 632 bytes. 
             Review with 'standart direct thread code',
             new sizes for tib, pad, data and return stacks. 

_24/01/2024_ code for 6502 review. Recode for use 'standart direct thread code'. 
             made a file with 'minimum itc model ' and another with 'standart itc model'
                 
_16/01/2024_ code for 6502 sized to 612 bytes, review and reorder, need loop end-of-find.

_11/01/2024_ code for 6502 sized to 632 bytes, refine ( pull, push, copy ), still crashes.

_10/01/2024_ code for 6502 sized to 621 bytes, turn explicit copy from into, still crashes.

_09/01/2024_ code for 6502 sized to 654 bytes, stack goes forward, still crashes.

_02/01/2024_ code for 6502 sized to 647 bytes, still crashes by wrong jsr/jmp.

_19/12/2023_ code for 6502 sized to 629 bytes, include key and emit, clean wrong rts.

_05/12/2023_ code for 6502 sized to 588 bytes, include names in ascii-7 and aritmetic shift right (2/).

_27/11/2023_ code for 6502 sized to 572 bytes, clear some errors and ascii-7 checks

_22/11/2023_ code for 6502 sized to 566 bytes, more good tips from Peter Ferrie <peter.ferrie@gmail.com>

_20/11/2023_ code for 6502 sized to 590 bytes, some good tips from Peter Ferrie <peter.ferrie@gmail.com>

_20/11/2023_ rebuild the github repo without fork from original milliForth[^1]

_14/11/2023_ code for 6502 sized to 624 bytes, no ascii-7, no key, no emit, no 2/, many errors

