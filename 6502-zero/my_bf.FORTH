 
 : -1 s@ s@ nand s@ nand ;
 : 0 -1 -1 nand ;
 : 1 -1 -1 + -1 nand ;
 
 : 2 1 1 + ;
 : 4 2 2 + ;
 : 6 2 4 + ;
 
 : >in s@ 2 + ;
 : latest s@ 4 + ;
 : here s@ 6 + ;
 
 : 8 6 2 + ;
 : 10 6 4 + ;
 
 : sp s@ 8 + ;
 : rp s@ 10 + ;
 
 : cr 10 emit ;
 
 : dup sp @ @ ;
 : invert dup nand ;
 : and nand invert ;
 : - invert 1 + + ;
 : <> - 0# ;
 : = <> invert ;
 
 : drop dup - + ;
 : over sp @ 2 + @ ;
 : swap over over sp @ 6 + ! sp @ 2 + ! ;
 : 2dup over over ;
 : 2drop drop drop ;
 
 : or invert swap invert and invert ;
 : , here @ ! here @ 2 + here ! ;
 : 2* dup + ;
 : 80h 1 2* 2* 2* 2* 2* 2* 2* ;
 : immediate latest @ 2 + dup @ 80h or swap ! ;
 : [ 0 s@ ! ; immediate
 : ] 1 s@ ! ;
 
 : >r rp @ @ swap rp @ ! rp @ 2 - rp ! rp @ ! ;
 : r> rp @ @ rp @ 2 + rp ! rp @ @ swap rp @ ! ;
 
 : branch rp @ @ dup @ + rp @ ! ;
 : ?branch 0# invert rp @ @ @ 2 - and rp @ @ + 2 + rp @ ! ;
 
 : lit rp @ @ dup 2 + rp @ ! @ ;
 : ['] rp @ @ dup 2 + rp @ ! @ ;
 
 : rot >r swap r> swap ;
 
 : if ['] ?branch , here @ 0 , ; immediate
 : then dup here @ swap - swap ! ; immediate
 : else ['] branch , here @ 0 , swap dup 
     here @ swap - swap ! ; immediate
 
 : begin here @ ; immediate
 : again ['] branch , here @ - , ; immediate
 : until ['] ?branch , here @ - , ; immediate
 : while ['] ?branch , here @ 0 , ; immediate
 : repeat swap ['] branch , here @ - , 
     dup here @ swap - swap ! ; immediate
 
 : do here @ ['] >r , ['] >r , ; immediate
 : loop ['] r> , ['] r> , ['] lit , 1 , ['] + , 
     ['] 2dup , ['] = , ['] ?branch , 
     here @ - , ['] 2drop , ; immediate
 
 : 0fh lit [ 4 4 4 4 + + + 1 - , ] ;
 : ffh lit [ 0fh 2* 2* 2* 2* 0fh or , ] ;
 : c@ @ ffh and ;
 : in> >in @ c@ >in dup @ 1 + swap ! ;
 : bl lit [ 1 2* 2* 2* 2* 2* , ] ;
 
 : type 0 do dup c@ emit 1 + loop drop ;
 : parse in> drop >in @ swap 0 begin over in> 
     <> while 1 + repeat swap bl 
     = if >in dup @ 1 - swap ! then ;
 : word in> drop begin dup in> <> until >in @ 2 - >in ! parse ;
 : [char] ['] lit , bl word drop c@ , ; immediate
 : ." [char] " parse type ; immediate
 : ( [char] ) parse drop drop ; immediate
 
 : create here @ : ['] lit , here @ 4 + , ['] exit , 0 s@ ! latest ! ;
 : cells lit [ 2 , ] ;
 : allot here @ + here ! ;
 : variable create 1 cells allot ;
 
 : 48 lit [ 6 6 + 6 + 6 + 6 + 6 + 6 + 6 + , ] ;
 
 variable tape_head
 variable loop_depth
 variable parse_index
 
 : runbf 0 parse_index ! 
     begin parse_index @ c@ 
     dup dup dup dup dup dup dup 
     [char] , = if key tape_head @ ! then 
     [char] - = if tape_head @ @ 1 - tape_head @ ! then 
     [char] + = if tape_head @ @ 1 + tape_head @ ! then 
     [char] < = if tape_head @ 2 - tape_head ! then 
     [char] > = if tape_head @ 2 + tape_head ! then 
     [char] . = if tape_head @ @ emit then 
 
     [char] [ = tape_head @ @ 0 = and if 1 loop_depth ! 
     begin parse_index @ 1 + parse_index ! parse_index @ c@ dup 
     [char] [ = if loop_depth @ 1 + loop_depth ! then 
     [char] ] = if loop_depth @ 1 - loop_depth ! then 
     loop_depth @ 0 = until then 
     
     [char] ] = tape_head @ @ 0 <> and if 1 loop_depth ! 
     begin parse_index @ 1 - parse_index ! parse_index @ c@ dup 
     [char] [ = if loop_depth @ 1 - loop_depth ! then 
     [char] ] = if loop_depth @ 1 + loop_depth ! then 
     loop_depth @ 0 = until then 
     
     parse_index @ 1 + parse_index ! 
     dup parse_index @ = until drop ;
 
 : BF( [char] ) parse runbf ; immediate
 
 here @ 48 + tape_head !
 
 BF( >++++++++[<+++++++++>-]
     <.>++++[<+++++++>-]
     <+.+++++++..+++.>>++++++[<+++++++>-]
     <++.------------.>++++++[<+++++++++>-]
     <+.<.+++.------.--------.>>>++++[<++++++++>-]
     <+. )

