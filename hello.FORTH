: dup S= sp@ S= @ S= ; 
: -1 s@ s@ nand s@ nand ; 
: 0 -1 dup nand ; 
: 1 -1 dup + dup nand ; 
: 2 1 1 + ; 
: 4 2 2 + ;
: 6 4 2 + ;
: state s@ ; 
: >in s@ 2 + ; 
: latest s@ 4 + ; 
: here s@ 6 + ; 
: invert dup nand ; 

 sp@
 rp@
 s@

 S= 
 
 qr

 S=

 dup 

 S=

