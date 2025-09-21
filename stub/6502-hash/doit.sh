
gcc djb2.c
./a.out < $1.list > $1.hash
sort < $1.hash > $1.sort
uniq -w 10 -D < $1.sort > $1.uniq


