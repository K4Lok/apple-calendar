#!/bin/bash
# Shared helpers for the apple-calendar skill.
# Sourced by the cal-*.sh scripts. Not meant to be run directly.

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOCKLIST_FILE="$SKILL_DIR/config/blocklist.txt"

# Print the configured blocklist, one calendar name per line, with comment
# lines (starting with #) and blank lines stripped.
#
# Empty output means "nothing is blocked" — the skill operates on every
# calendar (the friendly default for a fresh install). When the file lists
# names, those calendars are treated as off-limits: they are excluded from
# scans, and any create/update/delete targeting them is refused. This lets a
# user fence off work/shared/system calendars without naming a calendar on
# every command.
read_blocklist() {
    [ -f "$BLOCKLIST_FILE" ] || return 0
    # Strip trailing whitespace, drop comments and blank lines.
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line%"${line##*[![:space:]]}"}"
        line="${line#"${line%%[![:space:]]*}"}"
        [ -n "$line" ] && printf '%s\n' "$line"
    done < "$BLOCKLIST_FILE"
}
