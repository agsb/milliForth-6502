# use:
# to make: 		MY=file make 
# to clean: 	MY=file make clean

.PHONY: clean all

########################################

LD = cl65

LDFLAGS = --cpu 6502 --memory-model near \
	--no-target-lib --target none -t none \
	--debug --debug-info

MY = sector-6502

LOADD = 0300

########################################

%: %.s

$(MY): $(SOURCES:.s=.o) $(MY).cfg

	$(LD) $(LDFLAGS) -C $@.cfg -Ln $@.lbl \
	-l $@.lst -m $@.map -o $@.out $@.s \
	2> err | tee out

	od --endian=big -A x -t x1z -v $@.out > $@.hex

	cp $@.s $@.asm

	sort -k 2 < $@.lbl > $@.lbs

all: 
	
	$(MY)

clean:
	
	$(RM) $(MY).out $(MY).map $(MY).lst \
	      $(MY).lbl $(MY).lbs $(MY).lbf \
	      $(MY).hex err out

run: 
	run6502 -l $(LOADD) $(MY).out -c \
		-R $(LOADD) -M E000 -X 0 \
		# -d 200 1000


