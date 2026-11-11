all:
	$(MAKE) -C squashfs-tools
	cp squashfs-tools/unsquashfs .
	cp squashfs-tools/mksquashfs .

clean:
	$(MAKE) -C squashfs-tools clean
	rm -f unsquashfs mksquashfs
