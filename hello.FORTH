
: zz S= cr ;

: dup sp@ @ ; 

 dup zz

: -1 s@ s@ nand s@ nand ; 

-1 dup zz

: 0 -1 dup nand ; 

0 zz

: 1 -1 dup + dup nand ; 

1 zz

: 2 1 1 + ; 

2 zz

: 4 2 2 + ; 

4 zz

: 6 2 4 + ; 

6 zz

 -1 0 1 2 4 6 zz

 + zz

 + zz

: state s@ ;

s@ state zz

: >in s@ 2 + ; 
s@ 2 s@ 2 + zz

bye

: latest s@ 4 + ; 
s@ 4 s@ 4 + latest zz

: here s@ 6 + ; 
s@ 6 s@ 6 + here zz

bye 

: invert dup nand ; 
0 invert zz

: and nand invert ; 
2 4 and zz

: - invert 1 + + ; 
: <> - 0# ; 
: = <> invert ; 
: drop dup - + ; 
: over sp@ 2 + @ ; 
2 4 6 
over zz
: swap over over sp@ 6 + ! sp@ 2 + ! ; 
swap zz

: 2dup over over ; 
2dup zz

: 2drop drop drop ; 

2drop zz

: or invert swap invert and invert ; 

4 2 or zz

: , here @ ! here @ 2 + here ! ; 


: 2* dup + ; 
2* zz

: 80h 1 2* 2* 2* 2* 2* 2* 2* ; 
80h zz


: immediate latest @ 2 + dup @ 80h or swap ! ; 

: [ 1 s@ ! ; 

latest latest @ zz

words

bye 

dump-on

immediate 

dump-off 

words

: ] 0 s@ ! ; 

