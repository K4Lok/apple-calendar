#!/bin/bash
# Read full details of a single event by UID.
# Usage: cal-read.sh <event-uid> [calendar_name]
# If no calendar is given, all non-blocked calendars are searched.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

EVENT_UID="${1:-}"
CALENDAR_NAME="${2:-}"

if [ -z "$EVENT_UID" ]; then
    echo "Usage: cal-read.sh <event-uid> [calendar_name]"
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

on pad2(n)
    set s to (n as integer) as string
    if (count of s) < 2 then set s to "0" & s
    return s
end pad2

on isoDate(d)
    return (year of d as string) & "-" & my pad2((month of d) as integer) & "-" & my pad2(day of d) & " " & my pad2(hours of d) & ":" & my pad2(minutes of d)
end isoDate

on run argv
    set eventUID to item 1 of argv as string
    set calendarName to item 2 of argv as string
    set blocklistStr to item 3 of argv as string

    tell application "Calendar"
        set blocked to my splitString(blocklistStr, linefeed)
        if calendarName is not "" then
            if blocked contains calendarName then
                return "Error: Calendar '" & calendarName & "' is on the blocklist (config/blocklist.txt)."
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
                    set eventLoc to location of e
                    set eventDesc to description of e
                    set eventURL to url of e
                    set eventRecur to recurrence of e
                    if eventLoc is missing value then set eventLoc to ""
                    if eventDesc is missing value then set eventDesc to ""
                    if eventURL is missing value then set eventURL to ""
                    if eventRecur is missing value then set eventRecur to ""

                    set output to "UID: " & eventUID & linefeed
                    set output to output & "Calendar: " & (name of cal) & linefeed
                    set output to output & "Summary: " & (summary of e) & linefeed
                    set output to output & "Start: " & my isoDate(start date of e) & linefeed
                    set output to output & "End: " & my isoDate(end date of e) & linefeed
                    set output to output & "All Day: " & (allday event of e as string) & linefeed
                    set output to output & "Location: " & eventLoc & linefeed
                    set output to output & "Description: " & eventDesc & linefeed
                    set output to output & "URL: " & eventURL & linefeed
                    set output to output & "Recurrence: " & eventRecur
                    return output
                end if
            end try
        end repeat

        return "Error: Event with UID '" & eventUID & "' not found"
    end tell
end run
EOF
