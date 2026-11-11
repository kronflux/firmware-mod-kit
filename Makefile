# Builds the tools in src/, running its configure script first if needed.

.PHONY: all clean distclean

all: src/Makefile
	$(MAKE) -C src

src/Makefile: src/Makefile.in src/configure
	cd src && ./configure --quiet

clean distclean:
	if [ -f src/Makefile ]; then $(MAKE) -C src $@; fi
