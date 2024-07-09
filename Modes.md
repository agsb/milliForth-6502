
# This file is a stub

### Threads and nuts

 historical JMP @(W)++
 case indirect thread code, 

   W = (IP)
   IP++
   X = (W)
   W++
   JMP (X)

 historical JMP (W)
 case direct thread code
    
    W = (IP)
    IP++
    JMP (W)

### Alternatives

1)  direct, better footprint, need a 'call' in cfa 
    for each compound word

EXIT:
UNNEST:
    RP++
    IP = (RP)

NEXT:
    W = (IP)
    IP++
    JMP (W)

ENTER:
NEST:
    (RP) = IP
    RP--
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
    RP++
    IP = (RP)

NEXT:
    W = (IP)
    IP++
    TST W
    BEQ JUMP

ENTER:
NEST:
    (RP) = IP
    RP--
    IP = W
    JMP NEXT

JUMP:
    RP++
    IP = (RP)
    JMP (W)

; test every word, only jumps when 0x0
; just test and jump to next or to W

3) a better alternative ?

; aka exit, semis, etc
UNNEST:
    RP++
    IP = (RP)

; always next
NEXT:
    W = (IP)
    IP++
    X = (W)
    W++

; aka enter, docol, dolst, etc
NEST:
    (RP) = IP
    RP--
    IP = W

; does not need the 0x0 at cfa, just compare tha reference
MESH:
    TST X
    CMP MSB(INIT)
    BPL NEXT
    JMP (X)

