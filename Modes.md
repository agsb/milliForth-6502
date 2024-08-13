
# Forth Thread modes easy way

## Threads and nuts

 the historical _JMP @(W)++_ does indirect thread code, by

    W = (IP)
    IP++
    X = (W)
    W++
    JMP (X)

 And _JMP (W)_ case on direct thread code
    
    W = (IP)
    IP++
    JMP (W)

## Alternatives

### Direct Thread Code (DTC)

In DTC, each compound word needs start with a "call ENTER" and ends with a reference to EXIT

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
    
any_WORD:

    CALL ENTER
    list of references
    EXIT
   
Note, each compound word does 3 jumps (in NEXT to W, in WORD to ENTER, in ENTER to NEXT) and a push-pull in SP

### Minimal Thread Code (MTC)

In MTC, each word is tested but only jumps if reference address is bellow _init_ of compound dictionary. 

No extra jumps and in 16-bit CPUs, the test could be done just comparing the MSB bytes.

EXIT:
UNNEST:

    IP = (RP)
    RP += CELL

NEXT:

    W = (IP)
    IP += CELL

    TST W
    CMP _INIT_
    BNE NEST
    
JUMP:

    JMP (W)
    
ENTER:
NEST:
    
    RP -= CELL
    (RP) = IP
    
    IP = W
    JMP NEXT

