all:
	$(MAKE) -C nb4-mksquashfs
	$(MAKE) -C nb4-unsquashfs
	cp nb4-mksquashfs/mksquashfs .
	cp nb4-unsquashfs/unsquashfs .

clean:
	$(MAKE) -C nb4-mksquashfs clean
	$(MAKE) -C nb4-unsquashfs clean
	rm -rf mksquashfs unsquashfs
