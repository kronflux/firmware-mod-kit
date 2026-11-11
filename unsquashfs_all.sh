#!/bin/bash
# Script to attempt to extract files from a SquashFS image using all of the available unsquashfs utilities in FMK until one is successful.
#
# Craig Heffner
# 27 August 2011
BINDIR=`dirname $0`
. "$BINDIR/common.inc"
IMG="$1"
DIR="$2"

ROOT="./src"
# should order in ascending version, 
# since newer versions may be able to extact older
# and we want *first* supporting version (some exceptions apply)
SUBDIRS="squashfs-2.1-r2 \
squashfs-3.0 \
squashfs-3.0-lzma-damn-small-variant \
others/squashfs-2.0-nb4 \
others/squashfs-2.2-r2-7z \
others/squashfs-3.0-e2100 \
others/squashfs-3.2-r2 \
others/squashfs-3.2-r2-lzma \
others/squashfs-3.2-r2-lzma/squashfs3.2-r2/squashfs-tools \
others/squashfs-3.2-r2-hg612-lzma \
others/squashfs-3.2-r2-wnr1000 \
others/squashfs-3.2-r2-rtn12 \
others/squashfs-3.3 \
others/squashfs-3.3-lzma/squashfs3.3/squashfs-tools \
others/squashfs-3.3-grml-lzma/squashfs3.3/squashfs-tools \
others/squashfs-3.4-cisco \
others/squashfs-3.4-nb4 \
others/squashfs-4.2-official \
others/squashfs-4.2 \
others/squashfs-4.0-lzma \
others/squashfs-4.0-realtek \
others/squashfs-hg55x-bin"
# Seconds each unsquashfs utility gets before it is considered hung
TIMEOUT="60"
MKFS=""

if [ "$IMG" == "" ] || [ "$IMG" == "-h" ]
then
	echo "Usage: $0 <squashfs image> [output directory]"
	exit 1
fi

if [ "$DIR" == "" ]
then
	BDIR="./squashfs-root"
	DIR="$BDIR"
	I=1

	while [ -e "$DIR" ]
	do
		DIR="$BDIR-$I"
		((I=$I+1))
	done
fi

IMG=$(readlink -f "$IMG")
DIR=$(readlink -f "$DIR")

# Make sure we're operating out of the FMK directory
cd $(dirname $(readlink -f "$0"))

# Read the major version from the SquashFS super block. It is a 16 bit value at
# offset 28 in every version of the format, stored in the byte order that the
# magic signature indicates.
case "$(head -c 4 "$IMG")" in
	sqsh|sqlz|qshs|tqsh)
		MAJOR=$(od -An -tu1 -j28 -N2 "$IMG" | awk '{print $1*256+$2}')
		;;
	*)
		MAJOR=$(od -An -tu1 -j28 -N2 "$IMG" | awk '{print $2*256+$1}')
		;;
esac

echo -e "Attempting to extract SquashFS $MAJOR.X file system...\n"

for SUBDIR in $SUBDIRS
do
	if [ "$(echo $SUBDIR | grep "$MAJOR\.")" == "" ]
	then
		echo "Skipping $SUBDIR (wrong version)..."
		continue
	fi

	unsquashfs="$ROOT/$SUBDIR/unsquashfs"
	mksquashfs="$ROOT/$SUBDIR/mksquashfs"

	if [ -e $unsquashfs-lzma ]; then
		echo -ne "\nTrying $unsquashfs-lzma... "

		timeout -k 5 $TIMEOUT $unsquashfs-lzma -dest "$DIR" "$IMG" 2>/dev/null
		
		if [ -d "$DIR" ]
                then
			if [ "$(ls "$DIR")" != "" ]
			then
				# Most systems will have busybox - make sure it's a non-zero file size
				if [ -e "$DIR/bin/sh" ]
				then
					if [ "$(wc -c "$DIR/bin/sh" | cut -d' ' -f1)" != "0" ]
					then
						MKFS="$mksquashfs-lzma"
					fi
				else
                        		MKFS="$mksquashfs-lzma"
				fi
			fi
			
			if [ "$MKFS" == "" ]
			then
				rm -rf "$DIR"
			fi
                fi
	fi
	if [ "$MKFS" == "" ] && [ -e $unsquashfs ]; then
		echo -ne "\nTrying $unsquashfs... "

		timeout -k 5 $TIMEOUT $unsquashfs -dest "$DIR" "$IMG" 2>/dev/null

		if [ -d "$DIR" ]
		then
			if [ "$(ls "$DIR")" != "" ]
			then
				# Most systems will have busybox - make sure it's a non-zero file size
				if [ -e "$DIR/bin/sh" ]
				then
					if [ "$(wc -c "$DIR/bin/sh" | cut -d' ' -f1)" != "0" ]
					then
						MKFS="$mksquashfs"
					fi
				else
					MKFS="$mksquashfs"
				fi
			fi

			if [ "$MKFS" == "" ]
			then
				rm -rf "$DIR"
			fi
		fi
	fi	

	if [ "$MKFS" != "" ]
	then
		echo "File system sucessfully extracted!"
		echo "MKFS=\"$MKFS\""
		exit 0
	fi
done

echo "File extraction failed!"
exit 1
