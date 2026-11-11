CC=gcc
CFLAGS=-g -Wall
TARGET=buffalo-enc

$(TARGET): buffalo-enc.c buffalo-lib.o
	$(CC) $(CFLAGS) $(LDFLAGS) $(TARGET).c buffalo-lib.o -o $(TARGET)

buffalo-lib.o: buffalo-lib.c buffalo-lib.h
	$(CC) $(CFLAGS) $(LDFLAGS) buffalo-lib.c -c

clean:
	rm -f buffalo-enc.o buffalo-lib.o $(TARGET)

distclean: clean
