: dup sp@ @ ; 
: -1 s@ s@ nand s@ nand ; 
: 0 -1 dup nand ; 
: 1 -1 dup + dup nand ; 
: 2 1 1 + ; 
: 4 2 2 + ;
: 6 4 2 + ;
: >in s@ 2 + ; 
: latest s@ 4 + ; 
: here s@ 6 + ; 
: invert dup nand ; 
0 
dup 
dup dup

