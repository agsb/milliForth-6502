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
: 12 6 6 + ;

: state s@ ;
: >in s@ 2 + ;
: latest s@ 4 + ;
: here s@ 6 + ;

: spt s@ 8 + ;
: sp@ spt @ ;
: sp! spt ! ;

: rpt s@ 10 + ;
: rp@ rpt @ ;
: rp! rpt ! ;

: ipt s@ 10 + ;
: ip@ ipt @ ;
: ip! ipt ! ;

: cr 10 emit ;

: dup sp@ @ ;
: invert dup nand ;
: - invert 1 + + ;

: <> - 0# ;
: = <> invert ;
: drop dup - + ;
: over sp@ 2 + @ ;
: swap over over sp@ 6 + ! sp@ 2 + ! ;
: 2dup over over ;
: 2drop drop drop ;
: and nand invert ;
: or invert swap invert and invert ;
: 2* dup + ;
: 80h 1 2* 2* 2* 2* 2* 2* 2* ;

: , here @ ! here @ 2 + here ! ;
: immediate latest @ 2 + dup @ 80h or swap ! ;
: [ 1 s@ ! ; immediate
: ] 0 s@ ! ;

: branch rp@ dup @ + rp! ;
: ?branch 0# invert rp@ @ 2 - and rp@ + 2 + rp! ;

: lit rp@ @ dup 2 + rp! @ ;
: ['] rp@ @ dup 2 + rp! @ ;

.S

: xx lit [ 10 , ] ;

xx

.S
: >rexit rp@ ! ;
: >r rp@ @ swap rp@ ! >rexit ;
: r> rp@ 2 + @ rp@ @ rp@ 2 + ! lit [ here @ 6 + , ] rp@ ! ;

: >r rp@ 2 - rp! rp@ ! ;
: r> rp@ @ rp@ 2 + rp! ;

10 8 .S .R

>r .S .R

r> .S .R

bye 

: if ['] ?branch , here @ 0 , ; immediate
: then dup here @ swap - swap ! ; immediate
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
