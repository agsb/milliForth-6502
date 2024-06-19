#! /usr/bin/bash

echo " start compiling "

case $1 in

a)   
    cl65 -Ln $2.lbl -l $2.lst -m $2.map \
    --cpu 6502 -t none --no-target-lib \
    --debug --debug-info \
    --memory-model near \
    --target none \
    -o $2.out -C $2.cfg $2.s 2> err | tee out

    cp $2.s $2.asm

    sort -k 2 < $2.lbl > $2.lbs

    grep 'f_' $2.lbs > $2.lbf

    ;;

o)    
    mv rom.bin $2.rom
    mv ram.bin $2.ram
    od --endian=big -x < $2.ram > $2.bhx
    od --endian=big -x < $2.rom > $2.bhx

    ;;

x)
    rm $2.obj $2.dep $2.map $2.lbl $2.lbs $2.lbf 2> err 
    rm $2.ram $2.rom $2.out $2.bhx $2.asm $2.lst 2> err
    rm out err  
    
    ;;

esac

echo " stop compiling "



