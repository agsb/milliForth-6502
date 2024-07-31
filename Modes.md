
# This file is a stub

### Threads and nuts

 historical JMP @(W)++
 case on indirect thread code, 

   W = (IP)
   IP++
   X = (W)
   W++
   JMP (X)

 historical JMP (W)
 case on direct thread code
    
    W = (IP)
    IP++
    JMP (W)

### Alternatives

1)  Direct, better footprint, 
    each compound word needs start with a "call NEST" and 
    ends with 'EXIT

EXIT:
UNNEST:
    IP = (RP)
    RP += CELL

NEXT:
    W = (IP)
    IP += CELL
    JMP (W)

ENTER:
NEST:
    RP -= CELL
    (RP) = IP
    POP IP 
    JMP NEXT

;
; in all compount: CALL NEST, list references, EXIT
; it does 3 jumps (to W, to NEST, to NEXT) and a push-pull in SP
;
; a call: (sp)-- = ++pc; pc = address
; a return: ps = ++(sp)
; a push: (sp)-- = ip 
; a pull: ip = ++(sp)

2) Minimal D T C

EXIT:
UNNEST:
    IP = (RP)
    RP += CELL

NEXT:
    W = (IP)
    IP += CELL
    TST W
    BEQ JUMP

ENTER:
NEST:
    RP -= CELL
    (RP) = IP
    IP = W
    JMP NEXT

JUMP:
    W = IP
    IP = (RP)
    RP += CELL
    JMP (W)

; test every first reference in ever word, 
; only jumps when 0x0
; just test and jump to next or to W

3) a better alternative ?

; aka exit, semis, etc
UNNEST:
    IP = (RP)
    RP += CELL

; always next
NEXT:
    W = (IP)
    IP += CELL
    X = (W)
    W++

; aka enter, docol, dolst, etc
NEST:
    RP -= CELL
    (RP) = IP
    IP = W

; does not need the 0x0 at cfa, just compare tha reference
MESH:
    TST X
    CMP MSB(INIT)
    BPL NEXT
    JMP (X)

