#! /usr/bin/bash

echo " start compiling "

case $1 in


a)   
    cl65 -C $2.cfg -Ln $2.lbl -l $2.lst -m $2.map \
    --cpu 6502 -t none --no-target-lib \
    --debug --debug-info \
    --memory-model near \
    --target none \
    -o $2.out \
    $2.s 2> err | tee out

    cp $2.s $2.asm

    sort -k 2 < $2.lbl > $2.lbs

    mv rom.bin $2.rom
    mv ram.bin $2.ram
    od --endian=big -x < $2.ram > $2.bhx
    od --endian=big -x < $2.rom > $2.bhx

    # -o $2.rom \

    ;;


x)
    rm $2.obj $2.dep $2.map $2.lbl $2.lbs $2.lst 
    rm $2.ram $2.rom $2.out $2.bhx $2.asm
    rm out err lst 
    
    ;;

esac

echo " stop compiling "



