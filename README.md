# A milliForth for 6502

_"A Forth in 328 bytes — the smallest real programming 
language ever, as of yet."_

The milliForth[^1] is a review of sectorForth[^2], 
and smaller than sector Lisp[^3]

The miniForth[^4] is another Forth to use in a boot sector 
of less than 512 bytes.

## Bytes?

Yes, bytes. But those are for a x86 16-bit CPU. 
How minimal could be it for a classic 6502 8-bit CPU ?

Two essentially different CPUs, a 16-bit x86 based on complex 
registers and opcodes, and a 8-bit 6502 using page zero 
as common registers and page one as hardware stack.

## Inner Interpreter

The FIG-Forth (1980) for 6502 uses Indirect Thread Code (ITC) 
    as inner interpreter. 

The miniForth, sectorforth and milliForth use Direct Thread Code (DTC) 

This Forth for 6502, ~will be~ was done using two models: 
    
    with classic Direct Thread Code (DTC) ~ now with 583 bytes (*)
    and
    with Minimal Thread Code (MTC) ~ now with 572 bytes (*)


(*) Thanks to wise changes from peterferrie !

(later we will compare both, ~but DTC will win for less size~) 

This project is also used to verify standart Direct Thread Code against 
variations of Minimum Thread Code.

[Minimal Thread Code](https://github.com/agsb/milliForth-6502/blob/main/The%20words%20in%20MITC%20Forth%20en.pdf) 
is an alternative model for inner interpreter, where 
the dictionary is organized with the primitives words grouped together 
before the compound words, defining a "tipping point", from where could 
decide if the reference of a word will be to executed or be pushed into 
return stack.

## Coding for 6502

Focus in size not performance.

The compilation wqas done with [ca65](https://github.com/cc65/cc65) V2.19 - Git 7979f8a41. 

The emulation of 6502 CPU was done with [run6502](https://github.com/mrdudz/run6502)

The way at 6502 is use a page zero and lots of lda/sta bytes.

Both DTC and MTC runs with my_hello_world.FORTH, with these numbers. 

    MTC Instructions: 38053769 Cycles: 156337697                            
                                                                        
    DTC Instructions: 37457299 Cycles: 155977289                            
                                                                              
    overhead: Instructions: 596470 Cycles: 360408                            

        1.59% Instructions (mtc/dtc)                                        

        0.23% cycles (mtc/dtc)      


### Changes:

- as Forth-1994[^5]: FALSE is $0000 and TRUE is $FFFF ;
- all tib (80 bytes), pic (16 cells), data (36 cells) and 
    return (36 cells) stacks are in page $200 ; 
- tib and pic grows forward, stacks grows backwards ;
- only immediate flag used as $80, no more flags ;

- no line editor, no backspace, no cancel line, no low ASCII verify ; 
- no stacks overflow or underflow checks ;
 
### Remarks:

- 6502 is a byte processor, no need 'pad' at end of even names ;
- hardware stack (page $100) not used as forth stack, free for use ;
- uses 32 bytes of _page zero_ ;
- no multiuser, no multitask, no faster ;
- only update _latest_ at end of word definition ; 
- redefine a word does not change previous uses ;
- stacks moves like the hardware stack ;
- words must be between spaces, before and after ever ;
- better use 7-bit ASCII characters ;
- approuch as ANSI X3.215-1994[^5]

### Notes

Look up at Notes[^6] for more.

16/08/2024:
    both models DTC and MTC, works with my_hello_world.FORTH;
    
11/08/2024:
    return to direct thread code;

11/06/2024:
    adapt for minimal thread indirect code;

24/01/2024:
    write using standart direct thread code;

14/11/2023
    code for 6502 sized to 624 bytes, 
    no ascii-7, no key, no emit, no 2/, many errors

## Coding

This version includes: 

```
primitives:
    s@    return the address of user structure
    +     adds two values at top of data stack
    nand  logic not and the two values at top of data stack
    @     fetch a value of cell wich address at top of data stack
    !     store a value into a cell wich address at top of data stack
    :     starts compilng a new word
    ;     stops compiling a new word
    0#    test if top of data stack is not zero
    exit  ends a word
    key   get a char from default terminal (system dependent)
    emit  put a char into default terminal (system dependent)
        
internals: 
    spush, spull, rpull, rpush, (stack code)
    copyfrom, copyinto, (heap code)
    incr, decr, add, etc (register mimics)
    cold, quit, token, skip, scan, getline, (boot and terminal)
    parse, find, compile, execute, (outer interpreter)
    unnest, next, nest, (dtc inner) 
    pick, jump, (mtc inner) 
    
externals:
    getch, putch, byes (depends on system, used minimal for emulator )

extensions: (selectable)
    2/      shift right one bit
    jump    jump to address in instruction pointer (ipt)    
    
extras:    (selectable)
    bye     ends the Forth, return to system
    abort   restart the Forth
    .S      list cells in data stack
    .R      list cells in return stack
    .       show cell at top of data stack
    words   extended list the words in dictionary
    dump    list contents of dictionary in binary

A my_hello_world.FORTH alternate version with dictionary for use;

The sp@ and rp@ are now derived from s@ in the my_hello_world.FORTH

```

### Memory

```
    $000    page zero       ; cpu reserved
    $100    hardware stack  ; cpu reserved
    $200    TIB             ; terminal input buffer, 80 bytes
    $298*   data stack      ; data stack, 36 cells, backwards
    $2E0*   return stack    ; return stack, 36 cells, backwards
    $2E0    PIC             ; reserved for scratch, 16 cells
    $300    _main_          ; start of Forth
    $???    _ends_          ; end of code and primitives of Forth
    $???    _init_          ; start of compound dictionary

    _init_ is the page (MSB) of _ends_ + 1

```

### Stacks

   " When heap moves forward, move the stack backward "

   Push is 'store and decrease'. Pull is 'increas and fetch'.

   A common memory model organization of Forth: 

       tib->...<-spt, user forth dictionary, here->pad...<-rpt,

   then backward stacks allow to use the slack space ... 

   This 6502 Forth memory model is blocked in pages of 256 bytes:

       page0, page1, page2, core ... forth dictionary ...here...
   
   at page2, without 'rush over'

       |tib 40 cells> <spt 36 cells| <rpt 36 cells|pic 16 cells> | .

## Language

_"SectorFORTH was an extensive guide throughout the process of 
implementing milliFORTH, and milliFORTH's design actually converged
on sectorFORTH unintentionally in a few areas. That said, the language
implemented is intentionally very similar, being the 'minimal FORTH'."_

For Forth language primer see 
[Starting Forth](https://www.forth.com/starting-forth/)

For Forth from inside howto see
[JonasForth](http://git.annexia.org/?p=jonesforth.git;a=blob_plain;f=jonesforth.S;hb=refs/heads/master)

## Use

_** 16/08/2024 DTC and MTC models operational, using lib6502 for emulation and tests **_

A crude small script for compile with ca65 is included.

    ; for make it
    sh mk a sector-6502

    ; for clear it
    sh mk x sector-6502

the size is take from main: to ends: using the sector-6502.lbl file

## Note

the originals files are edited for lines with less than 80 bytes

the bf.FORTH and hello_world.FORTH are from original milliForth[^1]

the my_hello_world.FORTH is adapted for miiliforth-6502

## References

[^1]: The original milliForth: https://github.com/fuzzballcat/milliForth 
[^2]: The inspirational sectorForth: https://github.com/cesarblum/sectorforth/
[^3]: Mind-blowing sectorLISP: https://justine.lol/sectorlisp2/, https://github.com/jart/sectorlisp
[^4]: The miniforth: https://github.com/meithecatte/miniforth
[^5]: Forth standart ANSI X3.215-1994: http://www.forth.org/svfig/Win32Forth/DPANS94.txt
[^6]: Notes and Times: https://github.com/agsb/milliForth-6502/blob/main/Notes.md
[^7]: A minimal indirect thread code for Forth: https://github.com/agsb/immu/blob/main/The%20words%20in%20MITC%20Forth%20en.pdf


