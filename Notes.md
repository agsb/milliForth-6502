
## Coding

On milliforth sector-x86 the classic NEXT ('lodsw' and 'jmp ax')
    is used as inner Forth heart beat. 

The register SI is ever used as pointer to next reference in same 
    word. Whenm it is saved into and loaded from return stack ? 

All primitive words do not call any other word and ends with a 
    jump to NEXT.

All composed words have a call to DOCOL, at start, to push SI, 
    followed by a list of references of other words and ends with 
    a reference to EXIT, to pull SI, from return stack, 

The return stack keep track of next references of the last words 
    not for the actual word.

Meanwhile the SI register is not accessible, it is not exposed and 
    the next reference can only be accessed while compiling, by using 
    HERE. Eg. lit [ here @ 6 + , ] 

The primitives s@ sp@ rp@ acts as VARIABLES, place the contentes 
    of of registers at data stack. Those are the addresses for STATE 
    and, DATA and RETURN stack pointers.

But to easy run better have a pure pointer as sp and rp, so can
    derive sp@ == sp @ @ and sp! == sp @ ! 

Then need to make a my_hello_world.FORTH

## Todo

- still no  _'OK'_ or _'NO'_;
- still no backspace routine for \b; 
- still no cancel line routine for \u; 

## Time table 

_28/08/2024_ 

    sector-6502-tst, testing use full pages for tib, sp, rp

    take a break for while ...let the dust settle.

_24/08/2024_ 

    unify sector-6502-mtc and sector-6502-dtc as 
        flagged sector-6502

    change internal parse: to resolve: because ambiguity on common used

    change flags name to use_"something"

    the __:__ does not update latest. It is only updated at __;__.

    then __create__ must update it.

    my_bf.FORTH still not work

_23/08/2024_ 

    in milliforth/sector forth, compiling is 0 and executing is 1,
    all forth uses 0 to execute and 1 to compiling

    __exit__ does not deserve to be immediate.
    __;__    must to be immediate  
    
    using my_test.FORTH as test dicitionary

_20/08/2024_ 

    Updated the presentation

    bf.FORTH still does no works

_20/08/2024_ 

    Peterferrie does some improvements but somewhere those breaked
    the execution.

    Doing patch per patch to find what or where.

    The 'getline and token' code does not work, 
        assumes only one space between words, changed.

    The '0#' forgot set LSB to MSB, changed;

    Why need a buffer of 80 chars and complex getline and token, if
    thereis no edition and only one word between spaces is taken each
    time ? make a 24 char buffer and just simplify token. next todo. 

    MTC and DTC ok

    need review for my_bf.FORTH

_16/08/2024_ 

    both DTC and MTC runs with my_hello_world.FORTH

        MTC Instructions: 38053769 Cycles: 156337697                            
                                                                            
        DTC Instructions: 37457299 Cycles: 155977289                            
                                                                                  
        overhead:
            
            Instructions:   596470 Cycles:    360408                            

            1.59% Instructions (mtc/dtc)                                        

            0.23% cycles (mtc/dtc)                                              

_14/08/2024_ 
    
    testing MTC

    all words bellow immediate from my_hello_word.FORTH 
        make dictionary ok
        compiling ok 
        colon ok 
        semis ok
        primitives ok

_12/08/2024_ 

    testing DTC

    all words from my_hello_word.FORTH runnig ok 

    extentions: toogle inside
        2/    shift right ( w -- w/2 )
        exec  jumps to reference at top of data stack

    extras: (toogle inside)
        .
        .S
        .R
        dump
        words
        bye
        abort
        
_10/08/2024_ 

    Using flag for [ (executing is 0) and ] (compiling is 1), 
        to follow the classic sense. 
        (was inverted in original milliforth hello_world.FORTH)

_08/08/2024_ 

    Beware the direction of stacks ! 

    got both >r and r> working by copy code 
        from https://github.com/benhoyt/third

_06/08/2024_ 

    eight primitives now: ! @ + nand : ; exit s@

    include a pack of extra words, most for debug : 
        2/      shift right non arithmetic ( w -- w/2 )
        .       hexdump top cell of data stack ( w -- w )
        .S      dumps the data stack ( -- )
        .R      dumps the return stack ( -- )
        words   list all words in dictionary, extense view
        dump    dumps all memory of dictionary
    
    using explict sp@ rp@ 

    tested all words with sp@, all correct

    words with rp@ still do not work

_31/07/2024_ 

    review of those of use rp@ as BRANCH LIT and etc.
        for use ipt as reference 
        because when a primitive is executed the next reference
        is at ipt, there is NO next reference in return stack,

_26/07/2024_ 

    no more need sp@ rp@ as primitives

    add a toggle for extensions:

        a primitive 'duck', for jump to ip ( reference )
        a primitive '&', perse, for get ip ( reference )

    add a toggle for extras:

        primitive '.', dot, for print TOS
        primitive .S for show the data stack
        primitive .R for show the return stack

    using my-hello-world.FORTH as base dictionary
    
    need review for change (jmp for bcc), todo

_24/07/2024_ 

    reorder pseudo registers at page zero to allow
        sp rp from offset by s@

    cosmetic pretty format sector-x86.s

    included in extras: 
        bye abort .S .R FALSE TRUE

    OK: *pull *push 

    OK: dup drop swap over 

    OK: nand + and or = <> invert - 

    OK: @ ! 

    >r and r> still bugged

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
    reorder tib, sp, rp, pic.

_16/06/2024_ 
    
    Return to MTC paradigm.
    it will grow the size of code, but will work ?
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

    return and change model for 'minimal thread code'
    with lots of debugging code to find errors. 
    Renaming main file for it

_01/05/2024_ 
            
    I'm on vacancy to reflesh some ideas

_30/01/2024_ 

    doing debugs for DTC inner 

_28/01/2024_ 

    code for 6502 sized to 632 bytes. 
    review with 'standart direct thread code',
    new sizes for tib, pad, data and return stacks. 

_24/01/2024_ 
    
    code for 6502 review. Recode for use 'direct thread code'. 
    made a file with 'minimum tc model ' and another with 'direct tc model'
                 
_16/01/2024_ 

    code for 6502 sized to 612 bytes, review and reorder, need loop end-of-find.

_11/01/2024_ 
    
    code for 6502 sized to 632 bytes, refine ( pull, push, copy ), still crashes.

_10/01/2024_ 

    code for 6502 sized to 621 bytes, turn explicit copy from into, still crashes.

_09/01/2024_ 

    code for 6502 sized to 654 bytes, stack goes forward, still crashes.

_02/01/2024_ 

    code for 6502 sized to 647 bytes, still crashes by wrong jsr/jmp.

_19/12/2023_ 

    code for 6502 sized to 629 bytes, include key and emit, clean wrong rts.

_05/12/2023_ 

    code for 6502 sized to 588 bytes, include names in ascii-7 and aritmetic shift right (2/).

_27/11/2023_ 

    code for 6502 sized to 572 bytes, clear some errors and ascii-7 checks

_22/11/2023_ 

    code for 6502 sized to 566 bytes, more good tips from Peter Ferrie <peter.ferrie@gmail.com>

_20/11/2023_ 

    code for 6502 sized to 590 bytes, some good tips from Peter Ferrie <peter.ferrie@gmail.com>

_20/11/2023_ 

    rebuild the github repo without fork from original milliForth[^1]

_14/11/2023_ 

    code for 6502 sized to 624 bytes, no ascii-7, no key, no emit, no 2/, many errors

