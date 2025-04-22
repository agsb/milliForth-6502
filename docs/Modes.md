
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

    IP = (RP)
    RP += CELL

NEXT:
    
    W = (IP)
    IP += CELL
    JMP (W)

ENTER:

    RP -= CELL
    (RP) = IP
    POP IP 
    JMP NEXT
    
any_compound_WORD:

    // must call for ENTER
    CALL ENTER
    list of references
    reference to EXIT
   
Note, each compound word start does 3 jumps (in NEXT to W, in WORD to ENTER, in ENTER to NEXT) and a push-pull at hardware SP.

### Minimal Thread Code (MTC)

In MTC, each word is tested but only jumps if reference address is bellow _init_ of compound dictionary. 

All primitives words comes before compound words in dictionary.

No extra jumps and in 16-bit CPUs, the test could be done just comparing the MSB bytes.

UNNEST:

    IP = (RP)
    RP += CELL

NEXT:

    W = (IP)
    IP += CELL

    TST W
    CMP _INIT_
    BMI JUMP

NEST:
    
    RP -= CELL
    (RP) = IP

LINK:

    IP = W
    JMP NEXT
    
JUMP:

    JMP (W)
    
any_compound_WORD:
    
    // no CALL for ENTER 
    list of references for words
    reference to UNNEST

All references at compound words are pushed into return stack without any jump into the word code. The dictionary is smaller.

