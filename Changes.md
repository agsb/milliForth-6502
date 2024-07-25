_this file is still a stub_

# Adapt and survive

Due lack of registers and complex instructions, present in x86, the 6502 milliforth review the original code for use of references at page zero and memory access modes.

the proposal of a new primitive **&**, called perse, to allow access to next following cell on dictionary.

the re-introduce of user area concept as 
  state,     the state of Forth, compile or execute
  toin,      a pointer to next free byte in terminal input buffer
  latest,    a pointer to last word in dictionary
  dpt,       a pointer to next free byte in heap dictionary
  spt,       a pointer to actual top of data stack
  rpt,       a pointer to actual top of return stack
  ipt,       a pointer to next cell in dictionary

the changes on hello-world.FORTH to my-hello-world.FORTH, to incorporate the modifications and recreate some words.
