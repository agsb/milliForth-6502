/*
#---------------------------------------------------------------------
 
  Copyright 2025 Alvaro Gomes Sobral Barcellos <@agsb>
 
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 2 of the License, or
  (at your option) any later version.
 
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.
 
  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.

#----------------------------------------------------------------------
*/

#---------------------------------------------------------------------
#
# the minimal primitives 
# 
#---------------------------------------------------------------------

#---------------------------------------------------------------------
#
#  djb2 hash cleared of bit 31
#
#---------------------------------------------------------------------
# symbols ! @ + 0# : ;
.equ hash_store, 0x0002B584 
.equ hash_fetch, 0x0002B5E5 
.equ hash_plus,  0x0002B58E 
.equ hash_zeroq, 0x00596816 
.equ hash_colon, 0x0002B59F 

.equ hash_semis, 0x8002B59E # unique with FLAG_IMM 

#---------------------------------------------------------------------
# uppercase KEY EMIT EXIT NAND U@
.equ hash_KEY,   0x0B87F112
.equ hash_EMIT,  0x7C7C87D0
.equ hash_NAND,  0x7C8254C0
.equ hash_USERAT, 0x005973B0
.equ hash_EXIT,  0x7C7CC745

#---------------------------------------------------------------------

.equ init_minimals, last_next

#---------------------------------------------------------------------
# ( -- ) ; aka figforth semis
def_word "EXIT", "exit", hash_EXIT, init_minimals

        j unnest

#---------------------------------------------------------------------
# ( -- ), ; aka figforth colon 
def_word ":", "colon", hash_colon, it_exit
# save here, panic if semis not follow elsewhere
        
        lw fst, HEAP (usr)
        
        sw fst, PEEK (usr)

# stat is 'compile' == 1
        
        li fst, COMPILE
        
        sw fst, STAT (usr)

# make a header

create:

# copy last into (here)
        
        lw fst, LAST (usr)
        
        call comma

# get a hash of the next token
        
        call token

# copy hash into (here)

        mv fst, trd

docomma:

        call comma

        j next 

#---------------------------------------------------------------------
# ( -- ) ; aka figforth semicolon
def_word ";", "semis", hash_semis, it_colon 
# update last, panic if colon not lead elsewhere 
        
        lw fst, PEEK (usr)
        
        sw fst, LAST (usr)

# stat is 'execute' == 0
        
        li fst, EXECUTE

        sw fst, STAT (usr)

finish:
# compound words must ends with exit
        
        la fst, is_exit

        j docomma

#---------------------------------------------------------------------
# ( -- c ) 
def_word "KEY", "key", hash_KEY, it_semis 

        call _getc

        j push1

#---------------------------------------------------------------------
# ( c -- ) 
def_word "EMIT", "emit", hash_EMIT, it_key
        
        call pull2

        call _putc

        j save1

#---------------------------------------------------------------------
# ( a w -- ),  [a] = w
def_word "!", "store", hash_store, it_emit
        
        call pull2

        sw snd, 0 (fst)

drop1:
        addi trd, trd, CELL

        j save1

#---------------------------------------------------------------------
# ( a -- w ), w = [a]
def_word "@", "fetch", hash_fetch, it_store
        
        call pull2
        
        lw fst, 0 (fst)
        
        j back1

#---------------------------------------------------------------------
# ( w1 w2 -- w), NOT(w1 AND w2)
def_word "NAND", "nand", hash_NAND, it_fetch

        call pull2

        and fst, snd, fst
        
        not fst, fst

        j keep1

#---------------------------------------------------------------------
# ( w1 w2 -- w), w = w1 + w2  
def_word "+", "plus", hash_plus, it_nand
        
        call pull2

        add fst, snd, fst

        j keep1

#---------------------------------------------------------------------
# ( 0 -- FALSE) | ( n -- TRUE), not zero at top ?
def_word "0#", "zeroq", hash_zeroq, it_plus

        call pull2
        
        beqz fst, back1

        li fst, TRUE
        
        j back1

#---------------------------------------------------------------------
# beware variables order
# ( -- _user ) return an reference to _user structure
def_word "U@", "userat", hash_USERAT, it_zeroq
        
        mv fst, usr 

push1:
        lw trd, SPTR (usr)
        
back1:
        addi trd, trd, -1 * CELL

keep1:
        sw fst, 0 (trd)

save1:
        sw trd, SPTR (usr)
        
        j next

#---------------------------------------------------------------------

pull2:
        
        lw trd, SPTR (usr)
        
        lw fst, 0 (trd)
        
        addi trd, trd, CELL

        lw snd, 0 (trd)

        ret

#---------------------------------------------------------------------

.equ last_next, it_userat

#---------------------------------------------------------------------

.ifdef extras 

#---------------------------------------------------------------------
#
#  djb2 hash cleared of bit 31
#
#---------------------------------------------------------------------

.equ hash_DOCODE, 0x0059697A
.equ hash_ABORT, 0x0A1DFF4F
.equ hash_BYE, 0x0B87C61B
.equ hash_DOT, 0x0002B58B
.equ hash_HEX, 0x0002B581
.equ hash_NAN, 0x0B87D404 
.equ hash_LSHIFT, 0x2C5784C9 
.equ hash_RSHIFT, 0x416E6B97

#---------------------------------------------------------------------

.set init_extras, last_next

#---------------------------------------------------------------------
# ( -- ) push 0x80000000 #; Not a Number and flag IMMEDIATE and error
def_word "NAN", "nan", hash_NAN, init_extras
by_erro:
by_zero:
by_under:        
by_over:

        lui fst, 0x80000
        
        j push1

#---------------------------------------------------------------------
# ( w1 w2 -- w1<<w2 ) #; shift left
def_word "LSHIFT", "lshift", hash_LSHIFT, it_nan

        call pull2
        
        sll fst, snd, fst
        
        j keep1

#---------------------------------------------------------------------
# ( w1 w2 -- w1>>w2 ) #; shift right
def_word "RSHIFT", "rshift", hash_RSHIFT, it_lshift

        call pull2
        
        srl fst, snd, fst
        
        j keep1

#---------------------------------------------------------------------
# ( -- ) execute a jump and link
def_word ";$", "docode", hash_DOCODE, it_rshift 

        # jump and link to there 

        jalr ra, 0 (ipt)
        
        # at there, save ra, do whatever, load ra,
        # end with  jalr s1, 0 (ra)
        # to return here, with s1 (is IP) to next cell 

        j next

#---------------------------------------------------------------------
# ( -- ) ae abort
def_word "ABORT", "aborts", hash_ABORT, it_docode

        j abort

#---------------------------------------------------------------------
# ( -- ) exit forth
def_word "BYE", "byes", hash_BYE, it_aborts

        j _exit

#---------------------------------------------------------------------
# ( w -- ) #; @
def_word "$", "hex", hash_HEX, it_byes

        call number

        j push1
        
#---------------------------------------------------------------------
# ( w -- ) #; @
def_word ".", "dot", hash_DOT, it_hex

        call pull2

        call tohex

        j save1
        
#---------------------------------------------------------------------

.equ last_next, it_dot

#---------------------------------------------------------------------
# code a 32-bit word in ASCII hexadecimal
# safe inside Forth words
# 
tohex:

        save_ra

        mv snd, fst
        
        li trd, 58

        li spc, 32

        # rolls 
100:
        beqz spc, 300f

        addi spc, spc, -4

        srl  fst, snd, spc
        andi fst, fst, 15
        ori  fst, fst, 48
        blt  fst, trd, 200f
        addi fst, fst, 7
200:
        call _putc
        
        j 100b

300:

        load_ra

        ret

#----------------------------------------------------------------------
# code a ASCII $0-9A-F hexadecimal to value
# safe inside Forth words
number:

        save_ra

        # clear result

        li trd, 0

        # load NaN

        lui snd, 0x80000

        # load word separator, BL is space      

        li spc, BL

        # skip spaces 
nskip:
        call _getc
        bleu fst, spc, nskip

ndigit:

        call digit

        beq fst, snd, nodigit

        slli trd, trd, 4

        add trd, trd, fst
        
        # scan spaces 
nscan:
        call _getc
        bltu fst, spc, nscan

        bne fst, spc, ndigit

isdigit:

        mv fst, trd 

nodigit:

        load_ra

        ret

# verify valid digit and convert it
digit:

100:
        #; valid digit, 0-9 and A-F  
        addi fst, fst, -48
        blt fst, zero, 400f

        #; 0-9 ?
        li hsh, 10
        blt fst, hsh, 200f

        #; normalize gap ascii 9 to A
        addi fst, fst, -7

        #; A to F ? No esoteric bases !
        li hsh, 16
        bgt fst, hsh, 400f

200:
        #; fst [ 0 .. 16 ]
        
        # lw hst, BASE (usr)
        # bgt fst, hst, 400f

        ret

400:
# is_error, NaN

        lui fst, 0x80000

        ret

#---------------------------------------------------------------------
.endif
#---------------------------------------------------------------------

