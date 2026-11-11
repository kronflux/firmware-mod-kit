#!/bin/sh
# Builds the tools one component at a time, showing a line of progress for
# each instead of the compiler output, which is collected in a log file.
#
# Usage: quiet-build.sh <log file> <component>...
#
# A component is a directory to run make in, or "@target" for a target of the
# Makefile in the current directory. $MAKE names the make program to use.

LOG="$1"
shift

MAKE="${MAKE:-make}"
TOTAL=$#
TMP="$LOG.tmp"

# Use colours on a terminal, unless NO_COLOR is set (see https://no-color.org)
if [ -t 1 ] && [ -z "$NO_COLOR" ] && [ "$TERM" != "dumb" ]; then
	BOLD=$(printf '\033[1m')
	DIM=$(printf '\033[2m')
	RED=$(printf '\033[1;31m')
	GREEN=$(printf '\033[1;32m')
	YELLOW=$(printf '\033[33m')
	BLUE=$(printf '\033[1;34m')
	RESET=$(printf '\033[0m')
else
	BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

ERRORS='(^|[^a-z])error[: ]|undefined reference|multiple definition|No such file|cannot find'

printf '%s==>%s %sBuilding the Firmware Mod Kit tools%s\n' "$BLUE" "$RESET" "$BOLD" "$RESET"
printf '    %sCompiler output goes to %s ("make V=1" shows it instead)%s\n' "$DIM" "$LOG" "$RESET"

: > "$LOG"
N=0
BUILT=0
WARNED=0

for COMPONENT in "$@"; do
	N=$((N + 1))

	case "$COMPONENT" in
		@*) NAME="${COMPONENT#@}"; set_args="$NAME" ;;
		*)  NAME="${COMPONENT%/}"; set_args="-C $COMPONENT" ;;
	esac

	printf '  %s[%2d/%d]%s %-48s ' "$DIM" "$N" "$TOTAL" "$RESET" "$NAME"

	# $set_args is split on purpose: it holds either a target or "-C <dir>"
	$MAKE $set_args > "$TMP" 2>&1
	STATUS=$?
	cat "$TMP" >> "$LOG"

	if [ $STATUS -ne 0 ]; then
		printf '%sFAILED%s\n\n' "$RED" "$RESET"
		grep -E -B2 -A6 "$ERRORS" "$TMP" | head -n 60
		rm -f "$TMP"
		printf '\n%s==>%s %sBuilding %s failed.%s The complete output is in %s\n' \
			"$RED" "$RESET" "$BOLD" "$NAME" "$RESET" "$(pwd)/$LOG"
		exit 1
	fi

	# Anything besides make's own messages means that something was built
	if grep -q -v -E '^make(\[[0-9]+\])?[: ]|^[[:space:]]*$' "$TMP"; then
		BUILT=$((BUILT + 1))
		WARNINGS=$(grep -c 'warning:' "$TMP")
		if [ "$WARNINGS" -gt 0 ]; then
			WARNED=$((WARNED + WARNINGS))
			[ "$WARNINGS" -eq 1 ] && PLURAL="" || PLURAL="s"
			printf '%sok%s %s(%d warning%s)%s\n' "$GREEN" "$RESET" "$YELLOW" "$WARNINGS" "$PLURAL" "$RESET"
		else
			printf '%sok%s\n' "$GREEN" "$RESET"
		fi
	else
		printf '%sup to date%s\n' "$DIM" "$RESET"
	fi
done

rm -f "$TMP"

if [ $BUILT -eq 0 ]; then
	printf '%s==>%s %sAll %d components were already up to date.%s\n' "$GREEN" "$RESET" "$BOLD" "$TOTAL" "$RESET"
else
	printf '%s==>%s %sAll %d components are ready%s (%d built).\n' "$GREEN" "$RESET" "$BOLD" "$TOTAL" "$RESET" "$BUILT"
	if [ $WARNED -gt 0 ]; then
		printf '    %sThe %d compiler warnings come from the bundled third-party sources and are expected.%s\n' "$DIM" "$WARNED" "$RESET"
	fi
fi
