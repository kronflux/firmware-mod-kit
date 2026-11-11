all:
	$(MAKE) -C squashfs-tools
	@cp -u squashfs-tools/unsquashfs .
	@cp -u squashfs-tools/mksquashfs .

clean:
	$(MAKE) -C squashfs-tools clean
	rm -f unsquashfs mksquashfs
