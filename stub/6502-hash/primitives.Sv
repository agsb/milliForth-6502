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
#       core primitives
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
#
# djb2 hash cleared of bit 31
#

.equ hash_MINUS, 0x0002B588     # - 

.equ hash_EQU, 0x0002B598       # = 
.equ hash_LESS, 0x0002B599      # < 
.equ hash_ULESS, 0x005973CC     # U< 
.equ hash_GTZERO, 0x0059680B    # 0>

.equ hash_CFETCH, 0x005972E6    # C@
.equ hash_CSTORE, 0x00597287    # C!

.equ hash_RAT, 0x00597497       # R@
.equ hash_TOR, 0x005968A9       # >R
.equ hash_RTO, 0x005974E9       # R>

.equ hash_AND, 0x0B87B72E 
.equ hash_OR, 0x00597378 
.equ hash_XOR, 0x0B883040 

.equ hash_NEGATE, 0x26B37A79 
.equ hash_INVERSE, 0x2D6AA2B5 

.equ hash_DUP, 0x0B87BC84 
.equ hash_DROP, 0x7C7F5C2C 
.equ hash_OVER, 0x7C84398B 
.equ hash_SWAP, 0x7C8A3910 
.equ hash_ROT, 0x0B8807CC 
.equ hash_NROT, 0x7C4E8CA1 

.equ hash_RPAT, 0x0B880527      # RP!
.equ hash_RPTO, 0x0B880546      # RP@
.equ hash_RPZO, 0x0B880557      # RP0

.equ hash_SPTO, 0x0B881187      # SP!
.equ hash_SPAT, 0x0B8811E6      # SP@
.equ hash_SPZO, 0x0B881196      # SP0

.equ hash_BRANCH, 0x1E6C4191 
.equ hash_ZBRANCH, 0x7D28616B
.equ hash_GBRANCH, 0x689E2DB6    

.equ hash_LIT, 0x0B87DB14 
.equ hash_ALIGN, 0x0C531CC8 

.equ hash_TRUE, 0x7C879BF3
.equ hash_FALSE, 0x0C3C6778

.equ hash_ONE, 0x00002B594      # 1
.equ hash_TWO, 0x00002B597      # 2
.equ hash_CELL, 0x07C81B0A3
.equ hash_NAN, 0x0B87D404       

.equ hash_STATE, 0x0DD1F032

.equ hash_LAST, 0x7C835F2F
.equ hash_HEAP, 0x7C857DF9

.equ hash_PEEK, 0x7C75C17E 
.equ hash_CEIL, 0x7C81B006 

.equ hash_HEAD, 0x7C857DED
.equ hash_TAIL, 0x7C87C175

.equ hash_PLUSTO, 0x0059676F    # +!

.equ hash_BYMUL, 0x005972C2     # M*
.equ hash_BYMOD, 0x7C4D1C6C     # /MOD

.equ hash_TWOMUL, 0x0059685D    # 2*
.equ hash_TWODIV, 0x00596858    # 2/

.equ hash_RSHIFT, 0x416E6B97
.equ hash_LSHIFT, 0x2C5784C9 

.equ hash_PERFORM, 0x15EEB854 #; ( PERFORM )

#---------------------------------------------------------------------

.equ init_primitives, last_next

#---------------------------------------------------------------------
#
look0:
        lw trd, SPTR (usr)

        lw fst, 0 (trd)

        ret

keep0:
        sw fst, 0 (trd)

        j next

drop0:
        addi ipt, ipt, CELL

        j next

#---------------------------------------------------------------------
# ( w1 -- w2 ) #; align to cell, word is 4 bytes
def_word "ALIGN", "align", hash_ALIGN, init_primitives

        call look0

        addi fst, fst, 3

        andi fst, fst, ~3

        j keep0

#---------------------------------------------------------------------
# ( w1 -- w2 ) #; INVERSE w
def_word "INVERSE", "nots", hash_INVERSE, it_align

        call look0

        # xori fst, fst, -1
        not fst, fst

        j keep0

#---------------------------------------------------------------------
# ( w1 -- w2 ) #; NEG w, arithmetic inverse
def_word "NEGATE", "negs", hash_NEGATE, it_nots

        call look0

        # sub fst, zero, fst
        neg fst, fst

        j keep0

#---------------------------------------------------------------------
# ( w -- w w ) #; duplicate tos
def_word "DUP", "dups", hash_DUP, it_negs

        call look0

        j back1

#---------------------------------------------------------------------
# ( w -- ) #; drop tos
def_word "DROP", "drop", hash_DROP, it_dups

        j drop1

#---------------------------------------------------------------------
# ( w1 w2 -- w1 w2 w1 ) #; over tos
def_word "OVER", "over", hash_OVER, it_drop

        call look0

        lw fst, CELL (trd)

        j push1

#---------------------------------------------------------------------
# ( w1 w2 -- w2 w1 ) #; over tos
def_word "SWAP", "swap", hash_SWAP, it_over

        call look0

        lw snd, CELL (trd)

        sw snd, 0 (trd)

        sw fst, CELL (trd)

        j next

#---------------------------------------------------------------------
# ( w1 w2 w3 -- w2 w3 w1 ) #; rot tos
def_word "ROT", "rot", hash_ROT, it_swap

        call look0

        lw snd, CELL (trd)
        
        sw fst, CELL (trd)

        lw fst, 2 * CELL (trd)

        sw snd, 2 * CELL (trd)

        sw fst, 0 (trd)

        j next

#---------------------------------------------------------------------
 # ( a -- w ), w = [a], one byte
 def_word "C@", "cfetch", hash_CFETCH, it_rot

         call look0

         lb fst, 0 (fst)

         j keep0

 #---------------------------------------------------------------------
 # ( a w -- ),  [a] = w, one byte
 def_word "C!", "cstore", hash_CSTORE, it_cfetch

         call pull2

         sb snd, 0 (fst)

         j drop1

#---------------------------------------------------------------------
# ( w1 w2 -- w3 ) #; w1 - w2
def_word "-", "minus", hash_MINUS, it_cstore

        call pull2

        sub fst, snd, fst

        j keep1

#---------------------------------------------------------------------
# ( w1 w2 -- w3 ) #; w1 AND w2
def_word "AND", "and", hash_AND, it_minus

        call pull2

        and fst, snd, fst

        j keep1

#---------------------------------------------------------------------
# ( w1 w2 -- w3 ) #; w1 OR w2 
def_word "OR", "or", hash_OR, it_and

        call pull2

        or fst, snd, fst

        j keep1

#---------------------------------------------------------------------
# ( w1 w2 -- w3 ) #; w1 OR w2 
def_word "XOR", "xor", hash_XOR, it_or

        call pull2

        xor fst, snd, fst

        j keep1

#---------------------------------------------------------------------
# ( w1 w2 -- w3 ) #; w1 = w2 
def_word "=", "equ", hash_EQU, it_xor

        call pull2

        bne fst, snd, isfalse

istrue:
        li fst, TRUE

        j keep0

isfalse:
        li fst, FALSE

        j keep0

#---------------------------------------------------------------------
# ( w1 w2 -- w3 ) #; w1 < w2 
def_word "<", "less", hash_LESS, it_equ

        call pull2

        blt snd, fst, istrue

        j isfalse

#---------------------------------------------------------------------
# ( w1 w2 -- w3 ) #; w1 < w2 unsigned
def_word "U<", "uless", hash_ULESS, it_less     

        call pull2

        bltu snd, fst, istrue

        j isfalse

#---------------------------------------------------------------------
# ( w1 -- w2 ) #; w1 > 0 greater than zero
def_word "0>", "gtzero", hash_GTZERO, it_uless     

        call look0

        bgt fst, zero, istrue

        j isfalse

#---------------------------------------------------------------------
# ( -- w ) #; the value is at second cell
def_word "R@", "rat", hash_RAT, it_gtzero

rlook0:
        lw trd, RPTR (usr)

        lw fst, CELL (trd)

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; the value is at second cell
def_word "R>", "rto", hash_RTO, it_rat

rpull1:
        # load pointer

        lw trd, RPTR (usr)

        # load value

        lw fst, CELL (trd)

        # load return

        lw snd, 0 (trd)

        # update pointer 

        addi trd, trd, +1 * CELL

        # save return 

        sw snd, 0 (trd) 

        # save pointer

        sw trd, RPTR (usr)

        # save value

        j push1

#---------------------------------------------------------------------
# ( w --  ; -- w ) #; the value is at second cell
def_word ">R", "tor", hash_TOR, it_rto

        # load value

        call pull2 

        # load pointer

        lw trd, RPTR (usr)

        # load return

        lw snd, 0 (trd) 

        # save value

        sw fst, 0 (trd) 

        # update pointer 

        addi trd, trd, -1 * CELL

        # save return

        sw snd, 0 (trd)

        # save pointer

        sw trd, RPTR (usr)

        j next

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @
def_word "RP@", "rpat", hash_RPAT, it_tor

        lw fst, RPTR (usr)

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @
def_word "RP!", "rpto", hash_RPTO, it_rpat

        call pull2

        sw fst, RPTR (usr)

        j next

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @
def_word "SP@", "spat", hash_SPAT, it_rpto

        lw fst, SPTR (usr)

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @
def_word "SP!", "spto", hash_SPTO, it_spat

        call pull2

        sw fst, SPTR (usr)

        j next

#---------------------------------------------------------------------
# ( -- ; -- ) #; branch is relative, not absolute
def_word "BRANCH", "branch", hash_BRANCH, it_spto

branch:

        lw fst, 0 (ipt)
        
        # when absolute
        # mv ipt, fst

        # when relative
        add ipt, ipt, fst

        j next

#---------------------------------------------------------------------
# ( -- ; -- ) #; branch if zero
def_word "0BRANCH", "zbranch", hash_ZBRANCH, it_branch
        
        call pull2

        beq fst, zero, branch

        j drop0

#---------------------------------------------------------------------
# ( -- ; -- ) #; branch if greater than zero
def_word "GBRANCH", "gbranch", hash_GBRANCH, it_zbranch
        
        call pull2

        bgt fst, zero, branch

        j drop0

#---------------------------------------------------------------------
# ( -- w ) #; 
def_word "LIT", "lit", hash_LIT, it_gbranch

        lw trd, RPTR (usr)

        lw fst, 0 (trd)

        addi trd, trd, CELL

        sw trd, RPTR (usr)

        j push1

#---------------------------------------------------------------------
# ( -- TRUE ) #; push 0xFFFFFFFF 
def_word "TRUE", "true", hash_TRUE, it_lit
        
        li fst, TRUE 

        j push1

#---------------------------------------------------------------------
# ( -- FALSE ) #; push 0x00000000
def_word "FALSE", "false", hash_FALSE, it_true

        li fst, FALSE 

        j push1

#---------------------------------------------------------------------
# ( -- 4 ) #; push 0x00000004
def_word "CELL", "cell", hash_CELL, it_false

        li fst, CELL

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; constant
def_word "RP0", "rpzo", hash_RPZO, it_cell

        la fst, _rp0

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; constant
def_word "SP0", "spzo", hash_SPZO, it_rpzo

        la fst, _sp0

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @
def_word "STATE", "state", hash_STATE, it_spzo

        lw fst, STAT (usr)

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @ last in dictionary
def_word "LAST", "last", hash_LAST, it_state

        lw fst, LAST (usr)

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @ heap in memory
def_word "HEAP", "heap", hash_HEAP, it_last

        lw fst, HEAP (usr)

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @ start of memory for use
def_word "PEEK", "peek", hash_PEEK, it_heap

        lw fst, PEEK (usr)

        j push1

#---------------------------------------------------------------------
# ( -- w ; w -- ) #; @ start of memory for use
def_word "CEIL", "ceil", hash_CEIL, it_peek

        lw fst, CEIL (usr)

        j push1

#---------------------------------------------------------------------
# ( w1 w2 -- w3 w4 ) double multiply,  
def_word "M*", "bymul", hash_BYMUL, it_ceil
        
        call pull2
        mulh spc, fst, snd
        mul snd, fst, snd

push2:
        sw snd, 0 (trd)
        mv fst, spc
	j push1

#---------------------------------------------------------------------
# ( w1 w2 -- w3 w4 ) divide
def_word "/MOD", "bymod", hash_BYMOD, it_bymul
        
        call pull2
	beqz fst, by_zero

        div spc, fst, snd
        rem snd, fst, snd
	j push2

#---------------------------------------------------------------------
# ( w -- ) #; @
def_word "PERFORM", "perform", hash_PERFORM, it_bymod

        call pull2

        jalr ra, 0 (fst)

        j next
        
#---------------------------------------------------------------------

.set last_next, it_perform

#---------------------------------------------------------------------

