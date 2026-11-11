all:
	$(MAKE) -C nb4-mksquashfs
	$(MAKE) -C nb4-unsquashfs
	@cp -u nb4-mksquashfs/mksquashfs .
	@cp -u nb4-unsquashfs/unsquashfs .

clean:
	$(MAKE) -C nb4-mksquashfs clean
	$(MAKE) -C nb4-unsquashfs clean
	rm -rf mksquashfs unsquashfs
