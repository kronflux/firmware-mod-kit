Build_Tools ()
{
	# Check to see if the tools have already been built first
	if [ ! -e "./src/crcalc/crcalc" ]
	then
		echo "Preparing tools ..."
		cd src 
		if [ ! -f "./Makefile" ]; then	
			./configure 2>&1 >> /dev/null
		fi
		make -s
		if [ $? -eq 0 ]; then
			cd - 2>&1 >> /dev/null
		else
			echo "Tools build failed! Check pre-requisites. Quitting..."
			exit 1
		fi
	fi
}

# Locate binwalk. An explicit $BINWALK wins, otherwise it is looked up in PATH.
Find_Binwalk ()
{
	if [ -z "$BINWALK" ]; then
		BINWALK=$(command -v binwalk)
	fi

	if [ -z "$BINWALK" ]; then
		echo "ERROR: binwalk not found! Install binwalk 2.x or 3.x, or set BINWALK to its location." >&2
		return 1
	fi
}

# Turn the result table printed by binwalk into one line per result:
#
#   <decimal offset><TAB><hex offset><TAB><description>
#
# binwalk 2.x and 3.x print the same three columns, but 3.x wraps long
# descriptions onto indented continuation lines, which are joined back up here.
Binwalk_Results ()
{
	awk '
		function flush() { if (rec != "") print rec; rec = "" }
		/^[0-9]+[ \t]+0x[0-9A-Fa-f]+[ \t]/ {
			flush()
			offset = $1; hex = $2
			sub(/^[0-9]+[ \t]+0x[0-9A-Fa-f]+[ \t]+/, "")
			sub(/[ \t]+$/, "")
			rec = offset "\t" hex "\t" $0
			next
		}
		/^[ \t]+[^ \t]/ && rec != "" {
			sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "")
			rec = rec " " $0
			next
		}
		{ flush() }
		END { flush() }'
}

# Scan the firmware image $1 with binwalk and print the results, sorted by
# offset, in the format described above.
Binwalk_Scan ()
{
	Find_Binwalk || return 1

	if $BINWALK -V 2>/dev/null | grep -q '^binwalk [3-9]'; then
		# binwalk 3.x reports a container such as a TRX image as a single
		# result and hides everything inside it, so the file systems have
		# to be searched for separately.
		{
			$BINWALK "$1" 2>/dev/null
			$BINWALK --include=squashfs,cramfs,jffs2,yaffs "$1" 2>/dev/null
		} | Binwalk_Results | sort -n -u -k1,1
	else
		$BINWALK "$1" 2>/dev/null | Binwalk_Results | sort -n -u -k1,1
	fi
}
