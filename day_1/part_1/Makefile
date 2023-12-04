
###############################################################################
# 
# @brief	Build executable using nasm and gcc.
#
# @file			Makefile
# @date			02 Dec 2023
# @author		upsetrobot
# @copyright	Copyright (c) 2023
# 
###############################################################################


PROGRAM = 	solution
OBJECTS = 	$(PROGRAM).o

CC = 		gcc
CFLAGS = 	-g -Wall -Wextra -no-pie
ASM = 		nasm
AFLAGS = 	-f elf64

run: rebuild clean
	valgrind ./$(PROGRAM)

rebuild : clean_all build

build: $(PROGRAM)

$(PROGRAM): $(OBJECTS)
	$(CC) $(CFLAGS) $^ -o $@

$(PROGRAM).o: $(PROGRAM).nasm
	$(ASM) $(AFLAGS) $^ -o $@

clean_all:
	rm -f *.o $(PROGRAM)

clean:
	rm -f *.o

.PHONY: run rebuild build clean_all clean


# End of file.