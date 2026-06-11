#!/bin/bash
# Delete an event by UID.
# Usage: cal-delete.sh <event-uid> [calendar_name]
# If no calendar is given, all non-blocked calendars are searched.
#
# A blocklisted calendar (config/blocklist.txt) is refused.
# Deleting a recurring event removes the ENTIRE series — see SKILL.md.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

EVENT_UID="${1:-}"
CALENDAR_NAME="${2:-}"

if [ -z "$EVENT_UID" ]; then
    echo "Usage: cal-delete.sh <event-uid> [calendar_name]"
    exit 1
fi

BLOCKLIST="$(read_blocklist)"

osascript - "$EVENT_UID" "$CALENDAR_NAME" "$BLOCKLIST" <<'EOF'
on splitString(theString, theDelimiter)
    set oldD to AppleScript's text item delimiters
    set AppleScript's text item delimiters to theDelimiter
    set arr to every text item of theString
    set AppleScript's text item delimiters to oldD
    return arr
end splitString

on run argv
    set eventUID to item 1 of argv as string
    set calendarName to item 2 of argv as string
    set blocklistStr to item 3 of argv as string

    set blocked to my splitString(blocklistStr, linefeed)

    tell application "Calendar"
        if calendarName is not "" then
            if blocked contains calendarName then
                return "Error: Calendar '" & calendarName & "' is on the blocklist (config/blocklist.txt). Refusing to delete."
            end if
            try
                set cals to {calendar calendarName}
            on error
                return "Error: Calendar '" & calendarName & "' not found"
            end try
        else
            set cals to {}
            repeat with c in calendars
                if blocked does not contain (name of c) then set end of cals to c
            end repeat
        end if

        repeat with cal in cals
            try
                set matchingEvents to (every event of cal whose uid is eventUID)
                if (count of matchingEvents) > 0 then
                    set e to item 1 of matchingEvents
                    set eventName to summary of e

                    if blocked contains (name of cal) then
                        return "Error: Event is in '" & (name of cal) & "', which is on the blocklist. Refusing to delete."
                    end if
                    if not (writable of cal) then
                        return "Error: Calendar '" & (name of cal) & "' is read-only"
                    end if

                    delete e
                    return "Deleted event: " & eventName & " (" & eventUID & ")"
                end if
            end try
        end repeat

        return "Error: Event with UID '" & eventUID & "' not found"
    end tell
end run
EOF
