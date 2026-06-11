#!/bin/bash
# Search events by text in summary, location, or description (case-insensitive).
# Usage:
#   cal-search.sh "dentist"                       Next 30 days, owned calendars
#   cal-search.sh "standup" --days 14
#   cal-search.sh "review" --days -90             Look back 90 days
#   cal-search.sh "kickoff" --from 2026-06-01 --to 2026-12-31
#   cal-search.sh "1:1" --calendar Work --days 60
#   cal-search.sh "meeting" 14 Work               Back-compat positional form

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib.sh"

QUERY=""
DAYS=""
FROM=""
TO=""
CALENDAR_NAME=""
LIMIT="0"

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
QUERY="${POS[0]:-}"
if [ -z "$DAYS" ] && [ -z "$FROM" ]; then
    [ -n "${POS[1]:-}" ] && DAYS="${POS[1]}"
fi
[ -z "$CALENDAR_NAME" ] && [ -n "${POS[2]:-}" ] && CALENDAR_NAME="${POS[2]}"
[ -z "$DAYS" ] && [ -z "$FROM" ] && DAYS="30"

if [ -z "$QUERY" ]; then
    echo "Usage: cal-search.sh <query> [--days N | --from DATE --to DATE] [--calendar NAME] [--limit N]"
    exit 1
fi

BLOCKLIST="$(read_blocklist)"

osascript - "$QUERY" "$BLOCKLIST" "$CALENDAR_NAME" "$DAYS" "$FROM" "$TO" "$LIMIT" <<'EOF'
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
    set searchQuery to item 1 of argv as string
    set blocklistStr to item 2 of argv as string
    set calendarName to item 3 of argv as string
    set daysStr to item 4 of argv as string
    set fromStr to item 5 of argv as string
    set toStr to item 6 of argv as string
    set theLimit to (item 7 of argv as string) as integer

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
                    set eventSummary to summary of e
                    set eventLoc to location of e
                    set eventDesc to description of e
                    if eventLoc is missing value then set eventLoc to ""
                    if eventDesc is missing value then set eventDesc to ""

                    set matchFound to false
                    ignoring case
                        if eventSummary contains searchQuery then
                            set matchFound to true
                        else if eventLoc contains searchQuery then
                            set matchFound to true
                        else if eventDesc contains searchQuery then
                            set matchFound to true
                        end if
                    end ignoring

                    if matchFound then
                        set eventLine to (uid of e) & " | " & eventSummary & " | " & my isoDate(start date of e) & " | " & my isoDate(end date of e) & " | " & (allday event of e as string) & " | " & eventLoc & " | " & (name of cal)
                        set end of results to eventLine
                        if theLimit > 0 and (count of results) ≥ theLimit then
                            set truncated to true
                            exit repeat
                        end if
                    end if
                end repeat
            end try
            if truncated then exit repeat
        end repeat

        if (count of results) = 0 then return "No events found matching: " & searchQuery

        set output to ""
        repeat with r in results
            set output to output & r & linefeed
        end repeat
        if truncated then set output to output & "(truncated at limit " & theLimit & ")" & linefeed
        return output
    end tell
end run
EOF
