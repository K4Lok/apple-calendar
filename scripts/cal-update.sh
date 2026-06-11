#!/bin/bash
# Update fields of an existing event by UID. Only the flags you pass are changed.
# Usage: cal-update.sh <event-uid> [--calendar NAME] [--summary TEXT] [--start DATE]
#                      [--end DATE] [--location TEXT] [--description TEXT]
#                      [--allday true|false] [--recurrence RRULE]
# Date format: "YYYY-MM-DD HH:MM" (timed) or "YYYY-MM-DD" (all-day)
# Examples:
#   cal-update.sh ABC123 --summary "Updated Meeting"
#   cal-update.sh ABC123 --start "2026-01-16 14:00" --end "2026-01-16 15:00"
#   cal-update.sh ABC123 --location "Room 101" --description "Bring laptop"
#
# A blocklisted calendar (config/blocklist.txt) is refused.
# Editing a recurring event changes the whole series (Calendar.app exposes only
# the master event over AppleScript) — see SKILL.md.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

EVENT_UID=""
CALENDAR_NAME=""
SUMMARY=""
START_DATE=""
END_DATE=""
LOCATION=""
DESCRIPTION=""
ALL_DAY=""
RECURRENCE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --calendar) CALENDAR_NAME="$2"; shift 2 ;;
        --summary) SUMMARY="$2"; shift 2 ;;
        --start) START_DATE="$2"; shift 2 ;;
        --end) END_DATE="$2"; shift 2 ;;
        --location) LOCATION="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --allday) ALL_DAY="$2"; shift 2 ;;
        --recurrence) RECURRENCE="$2"; shift 2 ;;
        *) [ -z "$EVENT_UID" ] && EVENT_UID="$1"; shift ;;
    esac
done

if [ -z "$EVENT_UID" ]; then
    echo "Usage: cal-update.sh <event-uid> [--summary TEXT] [--start DATE] [--end DATE] [--location TEXT] [--description TEXT] [--allday true|false] [--recurrence RRULE] [--calendar NAME]"
    exit 1
fi

BLOCKLIST="$(read_blocklist)"

osascript - "$EVENT_UID" "$CALENDAR_NAME" "$SUMMARY" "$START_DATE" "$END_DATE" "$LOCATION" "$DESCRIPTION" "$ALL_DAY" "$RECURRENCE" "$BLOCKLIST" <<'EOF'
on splitString(theString, theDelimiter)
    set oldD to AppleScript's text item delimiters
    set AppleScript's text item delimiters to theDelimiter
    set arr to every text item of theString
    set AppleScript's text item delimiters to oldD
    return arr
end splitString

on parseDate(dateStr)
    if dateStr is "" then return missing value
    set dateParts to my splitString(dateStr, " ")
    set ymd to my splitString(item 1 of dateParts, "-")
    set d to current date
    set year of d to (item 1 of ymd) as integer
    set month of d to (item 2 of ymd) as integer
    set day of d to (item 3 of ymd) as integer
    if (count of dateParts) > 1 then
        set hm to my splitString(item 2 of dateParts, ":")
        set hours of d to (item 1 of hm) as integer
        set minutes of d to (item 2 of hm) as integer
        set seconds of d to 0
    else
        set hours of d to 0
        set minutes of d to 0
        set seconds of d to 0
    end if
    return d
end parseDate

on run argv
    set eventUID to item 1 of argv as string
    set calendarName to item 2 of argv as string
    set newSummary to item 3 of argv as string
    set newStartStr to item 4 of argv as string
    set newEndStr to item 5 of argv as string
    set newLocation to item 6 of argv as string
    set newDescription to item 7 of argv as string
    set newAllDay to item 8 of argv as string
    set newRecurrence to item 9 of argv as string
    set blocklistStr to item 10 of argv as string

    set blocked to my splitString(blocklistStr, linefeed)

    tell application "Calendar"
        if calendarName is not "" then
            if blocked contains calendarName then
                return "Error: Calendar '" & calendarName & "' is on the blocklist (config/blocklist.txt). Refusing to update."
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

        -- Locate the event first. The try guards only the lookup (a calendar may
        -- not contain the UID); it must NOT wrap the mutations below, or a real
        -- save error would be swallowed and reported as "not found".
        set foundEvent to missing value
        set foundCalName to ""
        set foundWritable to false
        repeat with cal in cals
            try
                set matchingEvents to (every event of cal whose uid is eventUID)
                if (count of matchingEvents) > 0 then
                    set foundEvent to item 1 of matchingEvents
                    set foundCalName to (name of cal)
                    set foundWritable to (writable of cal)
                    exit repeat
                end if
            end try
        end repeat

        if foundEvent is missing value then return "Error: Event with UID '" & eventUID & "' not found"
        if blocked contains foundCalName then
            return "Error: Event is in '" & foundCalName & "', which is on the blocklist. Refusing to update."
        end if
        if not foundWritable then return "Error: Calendar '" & foundCalName & "' is read-only"

        if newSummary is not "" then set summary of foundEvent to newSummary

        -- When changing both start and end, set them in an order that never
        -- leaves the event transiently inverted (start after end), which
        -- Calendar.app rejects with error -10025. One of the two orders is
        -- always valid, so pick based on the current end date.
        if newStartStr is not "" and newEndStr is not "" then
            set ns to my parseDate(newStartStr)
            set ne to my parseDate(newEndStr)
            if ns ≤ (end date of foundEvent) then
                set start date of foundEvent to ns
                set end date of foundEvent to ne
            else
                set end date of foundEvent to ne
                set start date of foundEvent to ns
            end if
        else if newStartStr is not "" then
            set start date of foundEvent to my parseDate(newStartStr)
        else if newEndStr is not "" then
            set end date of foundEvent to my parseDate(newEndStr)
        end if

        if newLocation is not "" then set location of foundEvent to newLocation
        if newDescription is not "" then set description of foundEvent to newDescription
        if newAllDay is "true" then
            set allday event of foundEvent to true
        else if newAllDay is "false" then
            set allday event of foundEvent to false
        end if
        if newRecurrence is not "" then set recurrence of foundEvent to newRecurrence

        return "Updated event: " & eventUID
    end tell
end run
EOF
