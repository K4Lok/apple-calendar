#!/bin/bash
# List all calendars with writability and blocklist status.
# Usage: cal-list.sh
#
# Output columns: Name | writable|read-only | ok|blocked
# "blocked" means the calendar is listed in config/blocklist.txt and is
# excluded from scans and refused for mutations.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"
BLOCKLIST="$(read_blocklist)"

osascript - "$BLOCKLIST" <<'EOF'
on splitString(theString, theDelimiter)
    set oldD to AppleScript's text item delimiters
    set AppleScript's text item delimiters to theDelimiter
    set arr to every text item of theString
    set AppleScript's text item delimiters to oldD
    return arr
end splitString

on run argv
    set blocklistStr to item 1 of argv as string
    set blocked to my splitString(blocklistStr, linefeed)

    tell application "Calendar"
        set calNames to name of every calendar
        set calWritable to writable of every calendar
        set output to ""
        repeat with i from 1 to count of calNames
            set calName to item i of calNames
            if (item i of calWritable) then
                set writeStatus to "writable"
            else
                set writeStatus to "read-only"
            end if
            if blocked contains calName then
                set blockStatus to "blocked"
            else
                set blockStatus to "ok"
            end if
            set output to output & calName & " | " & writeStatus & " | " & blockStatus & linefeed
        end repeat
        return output
    end tell
end run
EOF
