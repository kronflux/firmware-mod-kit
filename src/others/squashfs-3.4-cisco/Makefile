SQDIR=squashfs-tools

all:
	$(MAKE) -C $(SQDIR)
	cp $(SQDIR)/unsquashfs .
	cp $(SQDIR)/mksquashfs .

clean:
	$(MAKE) -C $(SQDIR) clean
	rm -f unsquashfs mksquashfs
