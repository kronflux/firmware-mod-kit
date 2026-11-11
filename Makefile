# Builds the tools in src/, running its configure script first if needed.

.PHONY: all clean distclean

all: src/Makefile
	@$(MAKE) --no-print-directory -C src

src/Makefile: src/Makefile.in src/configure
	@cd src && ./configure --quiet

clean distclean:
	@if [ -f src/Makefile ]; then $(MAKE) --no-print-directory -C src $@ > /dev/null; fi
