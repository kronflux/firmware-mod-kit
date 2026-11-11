#!/bin/bash
BINDIR=$(dirname "$0")
. "$BINDIR/common.inc"

IMG="${1}"
DIR="${2}"

if [ "${DIR}" = "" ]; then
	DIR="fmk"
fi

# Need to extract file systems as ROOT, so that device nodes and file ownership
# survive. Set FMK_SUDO to use something other than sudo to gain privileges
# (e.g. "fakeroot"), or to the empty string to run without any.
if [ "$(id -ru)" != "0" ]; then
	SUDO="${FMK_SUDO-sudo}"
else
	SUDO=""
fi

IMG=$(readlink -f "$IMG")
DIR=$(readlink -f "$DIR")

# Make sure we're operating out of the FMK directory
cd "$(dirname "$(readlink -f "$0")")"

# Source in/Import shared settings. ${DIR} MUST be defined prior to this!
. ./shared-ng.inc

printf "Firmware Mod Kit (extract) ${VERSION}, (c)2011-2013 Craig Heffner, Jeremy Collake\n\n"

# Check usage
if [ "${IMG}" = "" ] || [ "${IMG}" = "-h" ]; then
	printf "Usage: ${0} <firmware image> [output directory]\n\n"
	exit 1
fi

if [ ! -f "${IMG}" ]; then
	echo "File does not exist!"
	exit 1
fi

if [ -e "${DIR}" ]; then
	echo "Directory ${DIR} already exists! Quitting..."
	exit 1
fi

Build_Tools

# Get the size, in bytes, of the target firmware image
FW_SIZE=$(wc -c < "${IMG}")

# Create output directories
mkdir -p "${DIR}/logs"
mkdir -p "${DIR}/image_parts"

echo "Scanning firmware..."

# Log the binwalk results to the ${BINLOG} file, one "offset, hex offset, description" line per result.
if ! Binwalk_Scan "${IMG}" > "${BINLOG}"; then
	rm -rf "${DIR}"
	exit 1
fi

# Header image offset is ALWAYS 0. Header checksums are simply updated by build-ng.sh.
HEADER_IMAGE_OFFSET=0

# Loop through binwalk log file
while IFS="$(printf '\t')" read -r OFFSET HEX LINE
 do
	# The first word of the description names the type of the result
	DESCRIPTION=$(echo "${LINE}" | awk '{print tolower($1)}')

	# Offset 0 is firmware header
	if [ "${OFFSET}" = "0" ]; then
		HEADER_OFFSET=${OFFSET}
		HEADER_TYPE=${DESCRIPTION}
		HEADER_SIZE=$(echo "${LINE}" | sed -n -e 's/.*header size: \([0-9]*\).*/\1/p')

	# Check to see if this line is a file system entry.
	# binwalk 2.x calls it a "filesystem", 3.x a "file system" for some types.
	elif echo "${LINE}" | grep -q -i -E 'file ?system'
	 then
		# JFFS2 and YAFFS images are a sequence of nodes or chunks that each
		# carry the signature, so binwalk may report them many times over.
		# Only the first result marks the start of the file system.
		if [ "${FS_TYPE}" = "${DESCRIPTION}" ] && { [ "${FS_TYPE}" = "jffs2" ] || [ "${FS_TYPE}" = "yaffs" ]; }; then
			continue
		fi

		FS_OFFSET=${OFFSET}
		FS_TYPE=${DESCRIPTION}

		# Need to know endianess for re-assembly
		if echo "${LINE}" | grep -q -i 'big endian'; then
			ENDIANESS="-be"
		else
			ENDIANESS="-le"
		fi

		# Check for compression type of the file system. binwalk names it for
		# squashfs 4.x images ("compression:xz" in 2.x, "compression: xz" in 3.x).
		# Older images have no such field, so fall back to gzip if the description
		# mentions it and default to LZMA otherwise.
		FS_COMPRESSION=$(echo "${LINE}" | sed -n -e 's/.*compression: *\([a-z0-9]*\).*/\1/p')
		if [ "${FS_COMPRESSION}" = "" ] || [ "${FS_COMPRESSION}" = "unknown" ]; then
			if echo "${LINE}" | grep -q -i 'gzip'; then
				FS_COMPRESSION="gzip"
			else
				FS_COMPRESSION="lzma"
			fi
		fi

		# Check for a block size (used only by squashfs).
		# "blocksize: N bytes" in binwalk 2.x, "block size: N" in 3.x.
		FS_BLOCKSIZE=$(echo "${LINE}" | sed -n -E -e 's/.*block ?size: ([0-9]+).*/\1/p')

		# Check for the size of the file system, which tells where it ends.
		# binwalk 3.x reports an "image size" or "total size". 2.x reports
		# a "size" for squashfs, which must not be confused with "blocksize".
		FS_SIZE=$(echo "${LINE}" | sed -n -E -e 's/.*(image|total) size: ([0-9]+) bytes.*/\2/p')
		if [ "${FS_SIZE}" = "" ]; then
			FS_SIZE=$(echo "${LINE}" | sed -n -E -e 's/.*, size: ([0-9]+) bytes.*/\1/p')
		fi
	fi
done < "${BINLOG}"

if [ "${FS_OFFSET}" = "" ]; then
	echo "ERROR: No supported file system found! Aborting..."
	rm -rf "${DIR}"
	exit 1
fi

# Header image size is everything from the header image offset (0) up to the file system
HEADER_IMAGE_SIZE=$((${FS_OFFSET}-${HEADER_IMAGE_OFFSET}))

# Extract the header + image up to the file system
echo "Extracting ${HEADER_IMAGE_SIZE} bytes of ${HEADER_TYPE} header image at offset ${HEADER_IMAGE_OFFSET}"
dd if="${IMG}" bs=${HEADER_IMAGE_SIZE} skip=${HEADER_IMAGE_OFFSET} count=1 of="${HEADER_IMAGE}" 2>/dev/null

# Try to determine if there is a footer at the end of the firmware image.
# A footer is whatever follows the last run of at least 64 identical padding
# bytes (0x00 or 0xFF) after the end of the file system. If binwalk did not
# report the size of the file system there is no telling such padding from
# what the file system itself contains, so no footer is looked for.
FOOTER_OFFSET=${FW_SIZE}

if [ "${FS_SIZE}" != "" ]; then
	FS_END=$((${FS_OFFSET}+${FS_SIZE}))
	if [ "${FS_END}" -gt "${FW_SIZE}" ]; then
		FS_END=${FW_SIZE}
	fi

	PADDING_END=$(tail -c +$((${FS_END}+1)) "${IMG}" | od -An -v -tx1 -w16 | awk '
		{
			for (i = 1; i <= NF; i++) {
				if ($i == last && ($i == "00" || $i == "ff")) {
					run++
				} else {
					if (run >= 64) padding_end = n
					run = ($i == "00" || $i == "ff") ? 1 : 0
					last = $i
				}
				n++
			}
		}
		END {
			if (run >= 64) padding_end = n
			if (padding_end != "") print padding_end
		}')

	if [ "${PADDING_END}" != "" ]; then
		FOOTER_OFFSET=$((${FS_END}+${PADDING_END}))
	fi
fi

FOOTER_SIZE=$((${FW_SIZE}-${FOOTER_OFFSET}))

# If a footer was found, dump it out
if [ "${FOOTER_SIZE}" != "0" ]; then
	echo "Extracting ${FOOTER_SIZE} byte footer from offset ${FOOTER_OFFSET}"
	tail -c ${FOOTER_SIZE} "${IMG}" > "${FOOTER_IMAGE}"
fi

# The file system is everything between its offset and the footer
echo "Extracting ${FS_TYPE} file system at offset ${FS_OFFSET}"
tail -c +$((${FS_OFFSET}+1)) "${IMG}" | head -c $((${FOOTER_OFFSET}-${FS_OFFSET})) > "${FSIMG}"

# Log the parsed values to the CONFLOG for use when re-building the firmware
echo "FW_SIZE='${FW_SIZE}'" > "${CONFLOG}"
echo "HEADER_TYPE='${HEADER_TYPE}'" >> "${CONFLOG}"
echo "HEADER_SIZE='${HEADER_SIZE}'" >> "${CONFLOG}"
echo "HEADER_IMAGE_SIZE='${HEADER_IMAGE_SIZE}'" >> "${CONFLOG}"
echo "HEADER_IMAGE_OFFSET='${HEADER_IMAGE_OFFSET}'" >> "${CONFLOG}"
echo "FOOTER_SIZE='${FOOTER_SIZE}'" >> "${CONFLOG}"
echo "FOOTER_OFFSET='${FOOTER_OFFSET}'" >> "${CONFLOG}"
echo "FS_TYPE='${FS_TYPE}'" >> "${CONFLOG}"
echo "FS_OFFSET='${FS_OFFSET}'" >> "${CONFLOG}"
echo "FS_COMPRESSION='${FS_COMPRESSION}'" >> "${CONFLOG}"
echo "FS_BLOCKSIZE='${FS_BLOCKSIZE}'" >> "${CONFLOG}"
echo "ENDIANESS='${ENDIANESS}'" >> "${CONFLOG}"

# Extract the file system and save the MKFS variable to the CONFLOG
case ${FS_TYPE} in
	"squashfs")
		echo "Extracting squashfs files..."
		${SUDO} ./unsquashfs_all.sh "${FSIMG}" "${ROOTFS}" 2>/dev/null | grep MKFS >> "${CONFLOG}"
		;;
	"cramfs")
		echo "Extracting CramFS file system..."
		${SUDO} ./uncramfs_all.sh "${FSIMG}" "${ROOTFS}" ${ENDIANESS} 2>/dev/null | grep MKFS >> "${CONFLOG}"
		;;
	"yaffs")
		echo "Extracting YAFFS file system..."
		${SUDO} ./src/yaffs2utils/unyaffs2 "${FSIMG}" "${ROOTFS}" 2>/dev/null 
		echo "MKFS='./src/yaffs2utils/mkyaffs2'" >> "${CONFLOG}"
		;;
	"jffs2")
		echo "Extracting JFFS2 file system..."
		JEFFERSON=$(command -v jefferson)
		if [ "${JEFFERSON}" != "" ]; then
			# jefferson reads the image directly, in user space
			${SUDO} "${JEFFERSON}" -d "${ROOTFS}" "${FSIMG}" >/dev/null 2>&1
		else
			# unjffs2 mounts the image through the kernel's mtdram and mtdblock
			# modules, and extracts to a hard-coded directory of 'rootfs'
			${SUDO} ./src/jffs2/unjffs2 "${FSIMG}" 1>&2 2>/dev/null
			if [ -e "rootfs" ]
			then
				${SUDO} mv rootfs "${ROOTFS}"
			fi
		fi
		echo "MKFS='mkfs.jffs2'" >> "${CONFLOG}"
		;;
	*)
		echo "Unsupported file system '${FS_TYPE}'! Quitting..."
		rm -rf "${DIR}"
		exit 1
		;;
esac

# Check if file system extraction was successful
if [ -d "${ROOTFS}" ] && [ "$(ls -A "${ROOTFS}")" != "" ]; then
	echo "Firmware extraction successful!"
	echo "Firmware parts can be found in '${DIR}/*'"
else
	echo "Firmware extraction failed!"
	rm -rf "${DIR}"
	exit 1
fi

exit 0
