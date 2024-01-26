# milliForth for 6502

_"A Forth in 380 bytes — the smallest real programming language ever, as of yet."_

The milliForth[^1] is very similar to sectorForth[^2], and smaller than sector Lisp[^3]

## bytes?

Yes, bytes. But the code is for a x86 CPU. 

How minimal could be it for a classic 6502 CPU ?

Two essentially different CPUs, a 16-bit x86 based on complex registers and opcodes, and a 8-bit 6502 using page zero as registers and page one as hardware stack.

## Coding

This version includes: 
```
        primitives:
            sp@, rp@, s@, +, nand, @, !, :, ;, 0=, key, emit, 2/,

        internals: 
            spush, spull, rpull, rpush, incr, decr, add, etc (register mimics)
            unnest, next, nest, link, jump, (inner interpreter) 
            quit, token, skip, scan, newline, find, compile, execute, exit (outer interpreter)
            _getchar_, _putchar_ (depends on system, used minimal for emulator )
```
    
### Coding for minimal size, not for best performance. Using ca65 V2.19 - Git 7979f8a41.

include some debug code and flag

_24/01/2024_ code for 6502 sized to 632 bytes. Review with 'standart indirect thread code'. 

_24/01/2024_ code for 6502 review. Recode for use 'standart indirect thread code'. 
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

## Language

_"SectorFORTH was an extensive guide throughout the process of implementing milliFORTH, and milliFORTH's design actually converged on sectorFORTH unintentionally in a few areas. That said, the language implemented is intentionally very similar, being the 'minimal FORTH'."_

For Forth language primer see [Starting Forth](https://www.forth.com/starting-forth/)

The milliForth for 6502 have some changes:

- does not use _hardware stack_ as Forth stack;
- only _IMMEDIATE_ flag used;
- only update _latest_ at end of word definition, so the word is hidden while defined;
- redefine a word does not changes at previous uses;
- uses _Minimal Thread Indirect Code_ as inner dispatcher[^4];
- the _tib, locals, data stack, return stack_ at same page ($200) [^5];
- uses 32 bytes of _page zero_;
- depends on spaces before and after a word in tib;
- uses 7-bit ASCII characters;

- still no include a _'OK'_ or _'??'_;
- still no include a backspace routine for \b; 
- still no include a empty line routine for \u; 

### Memory

```
    $000    page zero       ; cpu reserved
    $100    hardware stack  ; cpu reserved
    $200    TIB             ; terminal input buffer, 80 bytes
    $250    Locals          ; reserved for locals, 16 cells
    $2DC    data stack      ; data stack, 36 cells
    $2FF    return stack    ; return stack, 36 cells
    $300    _main_          ; start of Forth
    $500    _init_          ; start of compose dictionary
```

## Use

_** Still not operational, using lib6502 for emulation and tests, Any sugestions ? **_

A crude small script for compile with ca65 is included.

    ; for make it
    sh mk a sector-6502

    ; for clear it
    sh mk x sector-6502

the size is take from main: to ends: using the sector-6502.lbl file

## Note

the bf.FORTH and hello_world.FORTH are from original milliFort[^1]

## References
[^1]: the original milliForth: https://github.com/fuzzballcat/milliForth 
[^2]: The inspirational sectorForth: https://github.com/cesarblum/sectorforth/.
[^3]: Mind-blowing sectorLISP: https://justine.lol/sectorlisp2/, https://github.com/jart/sectorlisp.
[^4]: A minimal indirect thread code for Forth: https://github.com/agsb/immu/blob/main/The%20words%20in%20MITC%20Forth%20en.pdf
[^5]: Minimum are 80, 64, 48, from ANSI X3.215-1994, http://www.forth.org/svfig/Win32Forth/DPANS94.txt;
