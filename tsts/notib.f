( still a stub )
( when Forth uses word by word )
( need move tib to user space )

: tib# 10 10 10 6 + + + ;

: tib lit [ here , ] ; tib# allot


: in> 
    key ffh and
    >in @ !
    >in @ 1 +
    >in !
    ;

: parse 
    TIB 1 + >in !
    dup 
    begin
      drop
      key ffh and
      over over
    = until
    begin
      >in @ !
      >in @ 1 +
      >in !
      key ffh and
      over over
   <> until
     drop
     >in @
     0
     >in !
     ...


