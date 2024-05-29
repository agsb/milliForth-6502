# A milliForth for 6502

_"A Forth in 380 bytes — the smallest real programming language ever, as of yet."_

The milliForth[^1] is very similar to sectorForth[^2], and smaller than sector Lisp[^3]

## Bytes?

Yes, bytes. But the code is for a x86 CPU. 

How minimal could be it for a classic 6502 CPU ?

Two essentially different CPUs, a 16-bit x86 based on complex registers and opcodes, 
and a 8-bit 6502 using page zero as registers and page one as hardware stack.

## Time table 

include some debug code and flag

_01/05/2024 I'm on vacancy to reflesh some ideas

_30/01/2024_ doing debugs for DTC inner 

_28/01/2024_ code for 6502 sized to 632 bytes. Review with 'standart direct thread code',
             new sizes for tib, locals, data and return stacks. 

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

## Coding for 6502

Using ca65 V2.19 - Git 7979f8a41. Focus in size not performance.

The way at 6502 is use a page zero and lots of lda/sta bytes.

### Changes:

- all tib (84 bytes), locals (14 cells), data (36 cells) and return (36 cells) stacks are in page $200 ; 
- tib and locals grows forward, stacks grows backwards ;
- no overflow or underflow checks ;
- only immediate flag used as $80, no extras flags ;
- as Forth-1994: FALSE is $0000 and TRUE is $FFFF ;

### Remarks:

- words must be between spaces, begin and end spaces are wise;
- hardware stack (page $100) not used as forth stack, free for use;
- 6502 is a byte processor, no need 'pad' at end of even names;
- no multiuser, no multitask, no faster;
- uses 7-bit ASCII characters;
- uses 32 bytes of _page zero_;
- only update _latest_ at end of word definition, so the word is hidden while defined;
- redefine a word does not changes at previous uses;


24/01/2024:
for comparison with x86 code, 
    rewrite using standart direct thread code as inner dispatcher;
    before was using Minimal Thread Indirect Code_ as inner dispatcher[^4];


The stack operations are backwards but slightly different in order.
Usually, **push** is _store and decrease_, **pull** is _increase and fetch_.
This code, **push** is _decrease and store_, **pull** is _fetch and increase_,

- still no include a _'OK'_ or _'??'_;
- still no include a backspace routine for \b; 
- still no include a empty line routine for \u; 

## Coding

This version includes: 
```
    primitives:
        sp@, rp@, s@, +, nand, @, !, :, ;, 0#, key, emit, 2/, exit,

    internals: 
        spush, spull, rpull, rpush, incr, decr, add, etc (register mimics)
        unnest, next, nest, link, jump, (inner interpreter) 
        quit, token, skip, scan, newline, find, compile, execute, exit (outer interpreter)
        getch, putch (depends on system, used minimal for emulator )
```
    
### Memory

```
    $000    page zero       ; cpu reserved
    $100    hardware stack  ; cpu reserved
    $200    TIB             ; terminal input buffer, 84 bytes
    $254    Locals          ; reserved for locals, 14 cells
    $2D8    data stack      ; data stack, 36 cells
    $2FF    return stack    ; return stack, 36 cells
    $300    _main_          ; start of Forth
    $5??    _init_          ; start of compose dictionary
```

## Language

_"SectorFORTH was an extensive guide throughout the process of implementing milliFORTH, and milliFORTH's design actually converged on sectorFORTH unintentionally in a few areas. That said, the language implemented is intentionally very similar, being the 'minimal FORTH'."_

For Forth language primer see [Starting Forth](https://www.forth.com/starting-forth/)

## Use

_** Still not operational, using lib6502 for emulation and tests, Any sugestions ? **_

A crude small script for compile with ca65 is included.

    ; for make it
    sh mk a sector-6502

    ; for clear it
    sh mk x sector-6502

the size is take from main: to ends: using the sector-6502.lbl file

## Note

the originals files are edited for lines with less than 80 bytes

the bf.FORTH and hello_world.FORTH are from original milliFort[^1]

## References
[^1]: the original milliForth: https://github.com/fuzzballcat/milliForth 
[^2]: The inspirational sectorForth: https://github.com/cesarblum/sectorforth/.
[^3]: Mind-blowing sectorLISP: https://justine.lol/sectorlisp2/, https://github.com/jart/sectorlisp.
[^4]: A minimal indirect thread code for Forth: https://github.com/agsb/immu/blob/main/The%20words%20in%20MITC%20Forth%20en.pdf
[^5]: Minimum are 80, 64, 48, from ANSI X3.215-1994, http://www.forth.org/svfig/Win32Forth/DPANS94.txt;
