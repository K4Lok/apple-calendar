#!/bin/bash
# Create a new calendar event.
# Usage: cal-create.sh <calendar> <summary> <start> <end> [location] [description] [allday] [recurrence]
# Date format: "YYYY-MM-DD HH:MM" (timed) or "YYYY-MM-DD" (all-day)
# Recurrence: iCalendar RRULE, e.g. "FREQ=WEEKLY;COUNT=4" or "FREQ=DAILY;UNTIL=20260201"
# Examples:
#   cal-create.sh Personal "Meeting" "2026-01-15 10:00" "2026-01-15 11:00"
#   cal-create.sh Personal "Vacation" "2026-02-01" "2026-02-05" "" "Beach trip" true
#   cal-create.sh Personal "Standup" "2026-01-20 09:00" "2026-01-20 09:30" "Zoom" "" false "FREQ=WEEKLY;COUNT=10"
#
# A calendar listed in config/blocklist.txt is refused — this fences off
# shared/work/system calendars from accidental writes.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

CALENDAR="${1:-}"
SUMMARY="${2:-}"
START_DATE="${3:-}"
END_DATE="${4:-}"
LOCATION="${5:-}"
DESCRIPTION="${6:-}"
ALL_DAY="${7:-false}"
RECURRENCE="${8:-}"

if [ -z "$CALENDAR" ] || [ -z "$SUMMARY" ] || [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
    echo "Usage: cal-create.sh <calendar> <summary> <start> <end> [location] [description] [allday] [recurrence]"
    echo "Date format: 'YYYY-MM-DD HH:MM' (timed) or 'YYYY-MM-DD' (all-day)"
    exit 1
fi

BLOCKLIST="$(read_blocklist)"

osascript - "$CALENDAR" "$SUMMARY" "$START_DATE" "$END_DATE" "$LOCATION" "$DESCRIPTION" "$ALL_DAY" "$RECURRENCE" "$BLOCKLIST" <<'EOF'
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

on parseDate(dateStr)
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
    set calendarName to item 1 of argv as string
    set eventSummary to item 2 of argv as string
    set startDateStr to item 3 of argv as string
    set endDateStr to item 4 of argv as string
    set eventLocation to item 5 of argv as string
    set eventDescription to item 6 of argv as string
    set isAllDay to item 7 of argv as string
    set eventRecurrence to item 8 of argv as string
    set blocklistStr to item 9 of argv as string

    set blocked to my splitString(blocklistStr, linefeed)
    if blocked contains calendarName then
        return "Error: Calendar '" & calendarName & "' is on the blocklist (config/blocklist.txt). Refusing to create. Remove it from the blocklist to permit writes."
    end if

    set startDate to my parseDate(startDateStr)
    set endDate to my parseDate(endDateStr)

    tell application "Calendar"
        try
            set cal to calendar calendarName
        on error
            return "Error: Calendar '" & calendarName & "' not found"
        end try

        if not (writable of cal) then
            return "Error: Calendar '" & calendarName & "' is read-only"
        end if

        set eventProps to {summary:eventSummary, start date:startDate, end date:endDate}
        if isAllDay is "true" then
            set eventProps to eventProps & {allday event:true}
        end if

        set newEvent to make new event at end of events of cal with properties eventProps

        if eventLocation is not "" then set location of newEvent to eventLocation
        if eventDescription is not "" then set description of newEvent to eventDescription
        if eventRecurrence is not "" then set recurrence of newEvent to eventRecurrence

        return "Created event: " & (uid of newEvent) & " | " & eventSummary & " | " & my isoDate(start date of newEvent) & " | " & (name of cal)
    end tell
end run
EOF
