PROG = uncramfs-lzma
CC = gcc -O3 -w
LIB = -lm
RM = rm -f
CFLAGS = -c

OBJS = \
  lzma-uncramfs.o \
  lzma-rg/SRC/7zip/Compress/LZMA_C/decode.o \
  lzma-rg/SRC/7zip/Compress/LZMA_C/LzmaDecode.o \


all: $(PROG)

$(PROG): $(OBJS)
	$(CC) -o $(PROG) $(LDFLAGS) $(OBJS) $(LIB)

lzma-uncramfs.o: lzma-uncramfs.c
	$(CC) $(CFLAGS) lzma-uncramfs.c

# Build the LZMA objects directly. Delegating to the sub-make raced with the
# implicit rule for LzmaDecode.o when running make in parallel.
lzma-rg/SRC/7zip/Compress/LZMA_C/%.o: lzma-rg/SRC/7zip/Compress/LZMA_C/%.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	-$(RM) $(PROG) $(OBJS)
	$(MAKE) -C lzma-rg/SRC/7zip/Compress/LZMA_C clean

