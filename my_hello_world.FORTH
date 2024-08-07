
: -1 s@ s@ nand s@ nand ;
: 0 -1 -1 nand ;
: 1 -1 -1 + -1 nand ;

: FALSE  0 ;
: TRUE  -1 ;

: 2 1 1 + ;
: 4 2 2 + ;
: 6 2 4 + ;
: 8 4 4 + ;
: 10 6 4 + ;

: state s@ ;
: >in s@ 2 + ;
: latest s@ 4 + ;
: here s@ 6 + ;

: sp s@ 8 + ;
: rp s@ 10 + ;

: sp@ sp @ ;
: rp@ rp @ ;

: sp! sp ! ;
: rp! rp ! ;

: cr 10 emit ;
: ? cr .S cr .R ;

: dup sp@ @ ;
: invert dup nand ;
: negate invert 1 + ;
: - negate + ;

: <> - 0# ;
: = <> invert ;

: drop dup - + ;
: over sp@ 2 + @ ;
: swap over over sp@ 6 + ! sp@ 2 + ! ;
: nip swap drop ;

: and nand invert ;
: or invert swap invert and invert ;

: 2dup over over ;
: 2drop drop drop ;
: 2* dup + ;
: 80h 1 2* 2* 2* 2* 2* 2* 2* ;

: , here @ ! here @ 2 + here ! ;
: immediate latest @ 2 + dup @ 80h or swap ! ;

: [ 1 s@ ! ; immediate
: ] 0 s@ ! ;

: branch rp@ @ dup @ + rp@ ! ;
: ?branch 0# invert rp@ @ @ 2 - and rp@ @ + 2 + rp@ ! ;

: lit rp@ @ dup 2 + rp! @ ;
: ['] rp@ @ dup 2 + rp! @ ;


: slit sp@ ? @ ? dup ?  2 ? + ? sp! ? @ ? ;

slit 

: >rexit rp@ ! ;
: >r rp@ @ swap rp@ ! >rexit ;
: r> rp@ 2 + @ rp@ @ rp@ 2 + ! lit [ here @ 6 + , ] rp@ ! ;

: lit0 rp@ @ dup 2 + ? ;

: branch0 rp@ ? @ ? dup ? 2 ? + ? rp! ? @ ? ;

: if ['] ?branch , here @ 0 , ; immediate
: then dup here @ swap - swap ! ; immediate


: tx 10 if 2 ? then 4 ? ;

: ty 0 if 4 ? then 6 ? ;

tx ty 

dump

bye

: begin here @ ; immediate
: while ['] ?branch , here @ 0 , ; immediate
: repeat swap ['] branch , here @ - , dup here @ swap - swap ! ; 
    immediate
: until ['] ?branch , here @ - , ; immediate
: do here @ ['] >r , ['] >r , ; immediate
: loop ['] r> , ['] r> , ['] lit , 1 , ['] + , ['] 2dup , ['] = , 
    ['] ?branch , here @ - , ['] 2drop , ; immediate
: 0fh lit [ 4 4 4 4 + + + 1 - , ] ;
: ffh lit [ 0fh 2* 2* 2* 2* 0fh or , ] ;
: c@ @ ffh and ;
: type 0 do dup c@ emit 1 + loop drop ;
: in> >in @ c@ >in dup @ 1 + swap ! ;
: bl lit [ 1 2* 2* 2* 2* 2* , ] ;

: parse in> drop >in @ swap 0 begin over in> <> while 1 + repeat 
    swap bl = if >in dup @ 1 - swap ! then ;
: word in> drop begin dup in> <> until >in @ 2 - >in ! parse ;
: [char] ['] lit , bl word drop c@ , ; immediate
: ." [char] " parse type ; immediate
." hello, world"
