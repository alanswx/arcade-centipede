CFLAGS = -Wno-implicit-function-declaration

all: lib6502.a testit

lib6502.a: sim6502.c sim6502.h macro6502.h
	cc -c sim6502.c -Wno-implicit-function-declaration
	ar cru lib6502.a sim6502.o

testit: testit.c lib6502.a
	cc -o testit testit.c -Wno-implicit-function-declaration lib6502.a
