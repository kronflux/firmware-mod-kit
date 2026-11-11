SQDIR=squashfs-tools

all:
	$(MAKE) -C $(SQDIR)
	@cp -u $(SQDIR)/unsquashfs .
	@cp -u $(SQDIR)/mksquashfs .

clean:
	$(MAKE) -C $(SQDIR) clean
	rm -f unsquashfs mksquashfs
