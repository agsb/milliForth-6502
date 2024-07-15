
: zz S= cr ;

: dup sp@ @ ; 

: -1 s@ s@ nand s@ nand ; 

: 0 -1 dup nand ; 

: 1 -1 dup + dup nand ; 

: 2 1 1 + ; 

: 4 2 2 + ; 

: 6 2 4 + ; 

: state s@ ;

: >in s@ 2 + ; 

: latest s@ 4 + ; 

: here s@ 6 + ; 

: invert dup nand ; 

: and nand invert ; 

: - invert 1 + + ; 

: <> - 0# ; 

: = <> invert ; 

: drop dup - + ; 

: over sp@ 2 + @ ; 

: swap over over sp@ 6 + ! sp@ 2 + ! ; 

: 2dup over over ; 

: 2drop drop drop ; 

: or invert swap invert and invert ; 

: , here @ ! here @ 2 + here ! ; 


: 2* dup + ; 

: 80h 1 2* 2* 2* 2* 2* 2* 2* ; 

80h zz

: immediate latest @ 2 + dup @ 80h or swap ! ; 

: [ 1 s@ ! ; 

words

dump-on

immediate 

dump-off 

words

: ] 0 s@ ! ; 

