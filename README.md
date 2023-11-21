# milliForth for 6502

A Forth in 380 bytes — the smallest real programming language ever, as of yet.

The milliForth[^1] is very similar to sectorForth[^2], and smaller than sector Lisp[^3]

## bytes?

Yes, bytes. But the code is for a x86 CPU. 

How minimal could be for a classic 6502 CPU ?

Two essentially different CPUs, a 16-bit x86 based on complex registers and opcodes, and a 8-bit 6502 using page zero as registers and page one as hardware stack.

## Coding

Coding for minimal size, not for best performance.

_14/11/2023_ code for 6502 sized to 624 bytes.

_16/11/2023_ code for 6502 sized to 555 bytes. (wrong count)

_20/11/2023 rebuild the github repo without fork from original milliForth[^1]

_20/11/2023 code for 6502 sized to 595 bytes, some good tips from Peter Ferrie <peter.ferrie@gmail.com>

## Language

_"SectorFORTH was an extensive guide throughout the process of implementing milliFORTH, and milliFORTH's design actually converged on sectorFORTH unintentionally in a few areas. That said, the language implemented is intentionally very similar, being the 'minimal FORTH'."_

For Forth language primer see [Starting Forth](https://www.forth.com/starting-forth/)

The milliForth for 6502 have some changes:

- Does not use _hardware stack_ as Forth stack;
- Only _IMMEDIATE_ flag used;
- Only update _latest_ at end of word definition, so the word is hidden while defined;
- Uses _Minimal Thread Indirect Code_ as inner dispatcher[^4];
- sizes of _tib, data stack, return stack_ are 256 bytes. By standarts 1979/1983/1994, minimum are 80, 64, 48;
- uses 32 bytes of _page zero_;
- depends on spaces before and after a word in tib; 
- still no include a classic _'OK '_;
- still no include a destructive backspace routine; 

## Use

_**still not operational, using lib6502 for emulation and tests**_

A crude small script for compile with ca65 is included.

## Note

the bf.FORTH and hello_world.FORTH are from original milliFort[^1]

## References
[^1]: the original milliForth: https://github.com/fuzzballcat/milliForth 
[^2]: The inspirational sectorForth: https://github.com/cesarblum/sectorforth/.
[^3]: Mind-blowing sectorLISP: https://justine.lol/sectorlisp2/, https://github.com/jart/sectorlisp.
[^4]: A minimal indirect thread code for Forth: https://github.com/agsb/immu/blob/main/The%20words%20in%20MITC%20Forth%20en.pdf
