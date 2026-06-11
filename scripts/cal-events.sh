#!/bin/bash
# List events in a time window, with ISO 8601 dates.
# Usage:
#   cal-events.sh                          Today, owned calendars
#   cal-events.sh --days 7                 Next 7 days
#   cal-events.sh --days -7                Last 7 days through end of today
#   cal-events.sh --from 2026-06-01 --to 2026-06-15
#   cal-events.sh --calendar Personal --days 30
#   cal-events.sh --limit 50 --days 90
#   cal-events.sh 7 Personal               Back-compat positional form
#
# When no --calendar is given, all calendars except those in the blocklist
# (config/blocklist.txt) are scanned. Passing an explicit --calendar is also
# dramatically faster than scanning everything, because Calendar.app evaluates
# the date query per calendar.

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

DAYS=""
FROM=""
TO=""
CALENDAR_NAME=""
LIMIT="0"

# Flag parsing with a positional fallback ([days] [calendar]).
POS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --days) DAYS="$2"; shift 2 ;;
        --from) FROM="$2"; shift 2 ;;
        --to) TO="$2"; shift 2 ;;
        --calendar) CALENDAR_NAME="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) POS+=("$1"); shift ;;
    esac
done
if [ -z "$DAYS" ] && [ -z "$FROM" ]; then
    [ -n "${POS[0]:-}" ] && DAYS="${POS[0]}"
fi
[ -z "$CALENDAR_NAME" ] && [ -n "${POS[1]:-}" ] && CALENDAR_NAME="${POS[1]}"
[ -z "$DAYS" ] && [ -z "$FROM" ] && DAYS="0"

BLOCKLIST="$(read_blocklist)"

osascript - "$BLOCKLIST" "$CALENDAR_NAME" "$DAYS" "$FROM" "$TO" "$LIMIT" <<'EOF'
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

on midnightOf(dateStr)
    set parts to my splitString(dateStr, "-")
    set d to current date
    set year of d to (item 1 of parts) as integer
    set month of d to (item 2 of parts) as integer
    set day of d to (item 3 of parts) as integer
    set hours of d to 0
    set minutes of d to 0
    set seconds of d to 0
    return d
end midnightOf

on run argv
    set blocklistStr to item 1 of argv as string
    set calendarName to item 2 of argv as string
    set daysStr to item 3 of argv as string
    set fromStr to item 4 of argv as string
    set toStr to item 5 of argv as string
    set theLimit to (item 6 of argv as string) as integer

    set oneDay to 24 * 60 * 60

    tell application "Calendar"
        set today to current date
        set startOfDay to today - (time of today)

        if fromStr is not "" and toStr is not "" then
            set startDate to my midnightOf(fromStr)
            set endDate to (my midnightOf(toStr)) + oneDay
        else
            set daysAhead to daysStr as integer
            if daysAhead ≥ 0 then
                set startDate to startOfDay
                set endDate to startOfDay + ((daysAhead + 1) * oneDay)
            else
                set startDate to startOfDay + (daysAhead * oneDay)
                set endDate to startOfDay + oneDay
            end if
        end if

        -- Resolve which calendars to scan (everything except blocked).
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

        set results to {}
        set truncated to false
        repeat with cal in cals
            try
                set calEvents to (every event of cal whose start date ≥ startDate and start date < endDate)
                repeat with e in calEvents
                    set eventLoc to location of e
                    if eventLoc is missing value then set eventLoc to ""
                    set eventLine to (uid of e) & " | " & (summary of e) & " | " & my isoDate(start date of e) & " | " & my isoDate(end date of e) & " | " & (allday event of e as string) & " | " & eventLoc & " | " & (name of cal)
                    set end of results to eventLine
                    if theLimit > 0 and (count of results) ≥ theLimit then
                        set truncated to true
                        exit repeat
                    end if
                end repeat
            end try
            if truncated then exit repeat
        end repeat

        if (count of results) = 0 then return "No events found"

        set output to ""
        repeat with r in results
            set output to output & r & linefeed
        end repeat
        if truncated then set output to output & "(truncated at limit " & theLimit & "; pass a larger --limit or narrow the window)" & linefeed
        return output
    end tell
end run
EOF
