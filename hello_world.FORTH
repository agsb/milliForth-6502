
: dup sp@ @ ; 

dup . 

: -1 s@ s@ nand s@ nand ; 

-1 .

: 0 -1 dup nand ; 

0 .

: 1 -1 dup + dup nand ; 

1 . 

: 2 1 1 + ; 

2 .

: 4 2 2 + ; 

4 . 

: 6 2 4 + ; 

6 .

: 8 4 4 + ; 

8 .

: 10 6 4 + ;

10 .

: 12 6 6 + ;

12 .

0 0# .

1 0# .

: >in s@ 2 + ; 

>in .

: latest s@ 4 + ; 

latest .

: here s@ 6 + ; 

here .

: invert dup nand ; 

0 invert .

: and nand invert ; 

10 6 and .

: - invert 1 + + ; 

4 6 - .

6 4 - .

: <> - 0# ; 

6 6 <> .

6 4 <> .

: = <> invert ; 

6 6 = .

6 4 = .

: drop dup - + ; 

1 2 drop .

: over sp@ 2 + @ ; 

1 2 over .

: swap over over sp@ 6 + ! sp@ 2 + ! ; 

1 2 swap . 

: 2dup over over ; 

1 2 2dup . .

: 2drop drop drop ; 

6 1 2 2drop .

: or invert swap invert and invert ; 

2 4 or .

: , here @ ! here @ 2 + here ! ; 

: 2* dup + ; 

4 2* .

: 80h 1 2* 2* 2* 2* 2* 2* 2* ; 

80h .

: immediate latest @ 2 + dup @ 80h or swap ! ; 

: [ 1 s@ ! ; immediate 

: ] 0 s@ ! ; 

: branch rp@ @ dup @ + rp@ ! ; 

: ?branch 0# invert rp@ @ @ 2 - and rp@ @ + 2 + rp@ ! ; 

: lit rp@ @ dup 2 + rp@ ! @ ; 

: ['] rp@ @ dup 2 + rp@ ! @ ; 

: >rexit rp@ ! ; 

: >r rp@ @ swap rp@ ! >rexit ; 

: r> rp@ 2 + @ rp@ @ rp@ 2 + ! lit [ here @ 6 + , ] rp@ ! ; 

: r> rp@ 2 + @ rp@ @ rp@ 2 + ! rp@ 2 + rp@ ! ; 

: 32 10 10 10 2 + + + ;

: bl 32 emit ;

: cr 10 emit ;

: ex 32 4 + emit ;

: .. dup . bl ;

: S' sp@ + @ .. drop ;
: S" 0 S' ex bl 2 S' 4 S' 6 S' 8 S' ;

: R' rp@ + @ .. drop ;
: R" 0 R' ex bl 2 R' 4 R' 6 R' 8 R' ;

: SR' cr ex sp@ .. @ .. drop drop cr rp@ .. @ .. drop drop ;

SR' 

4 6 

SR'

>r

SR'

r>

SR'

>r r> SR'

: if ['] ?branch , here @ 0 , ; immediate 

: ahead ['] branch , here @ 0 , ; immediate

: then dup here @ swap - swap ! ; immediate 

: begin here @ ; immediate 

: again ['] branch , here @ - , ; immediate 

: until ['] ?branch , here @ - , ; immediate 

: while ['] if ; immediate 

: repeat swap ['] again ['] then ; immediate 

: else ['] ahead swap ['] then ; immediate

>r r> SR'

: begin here @ ; immediate 

: while ['] ?branch , here @ 0 , ; immediate 

: repeat swap ['] branch , here @ - , dup here  
  @ swap - swap ! ; immediate 

: until ['] ?branch , here @ - , ; immediate 

: if ['] ?branch , here @ 0 , ; immediate 

: then dup here @ swap - swap ! ; immediate 

: do here @ ['] >r , ['] >r , ; immediate 

: loop ['] r> , ['] r> , ['] lit , 1 , ['] + , ['] 2dup ,  
  ['] = , ['] ?branch , here @ - , ['] 2drop , ; immediate 

0 6 do ex cr loop

: 0fh lit [ 4 4 4 4 + + + 1 - , ] ; 

: ffh lit [ 0fh 2* 2* 2* 2* 0fh or , ] ; 

: c@ @ ffh and ; 

: type 0 do dup c@ emit 1 + loop drop ; 

: in> >in @ c@ >in dup @ 1 + swap ! ; 

: bl lit [ 1 2* 2* 2* 2* 2* , ] ; 

: parse in> drop >in @ swap 0 
    begin over in> <> while 1 + repeat 
    swap bl = if >in dup @ 1 - swap ! then ; 

: word in> drop begin dup in> <> until >in @ 2 - >in ! parse ; 

: [char] ['] lit , bl word drop c@ , ; immediate 

: ." [char] " parse type ; immediate 

." hello, world " 
