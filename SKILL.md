---
name: apple-calendar
description: Read and manage events in the macOS Calendar.app from the command line. Use this whenever the user wants to check their schedule, see what's on today / this week / a specific date range, find a meeting, add or create an event, reschedule or move an event, change a time or location, set up a recurring event, or delete something from their Mac calendar — even when they don't say "Calendar.app" by name (e.g. "am I free Thursday afternoon?", "put lunch with Sam on my calendar", "move my 3pm to 4", "what meetings do I have next week?"). macOS only; works with multiple calendars and an optional blocklist that fences off work/shared/system calendars.
metadata: {"clawdbot":{"emoji":"📅","os":["darwin"]}}
---

# Apple Calendar

Create, read, update, delete, and search events in macOS **Calendar.app** through small
AppleScript wrappers. Run scripts from the skill directory: `cd {baseDir}`.

This skill talks to the *local* Calendar.app, so it sees whatever accounts that app
syncs (iCloud, Google, Exchange, on-device). It works offline against the local store.

## Setup (read once)

1. **Automation permission.** The first script you run will trigger a macOS prompt:
   *"Terminal wants access to control Calendar."* It must be allowed, or every command
   returns an `execution error ... (-1743)`. If it was denied earlier, re-enable it under
   **System Settings → Privacy & Security → Automation**. This is a one-time, per-app grant.
2. **Optional blocklist.** By default the skill works on every calendar. To fence one
   off, copy `config/blocklist.txt.example` to `config/blocklist.txt` and list the
   calendars to keep off-limits — see [Calendar blocklist](#calendar-blocklist).
3. **Find calendar names** with `scripts/cal-list.sh` — names are case-sensitive and must
   match exactly.

## Commands

| Action | Command |
|--------|---------|
| List calendars | `scripts/cal-list.sh` |
| List events | `scripts/cal-events.sh [--days N \| --from DATE --to DATE] [--calendar NAME] [--limit N]` |
| Search events | `scripts/cal-search.sh <query> [--days N \| --from DATE --to DATE] [--calendar NAME] [--limit N]` |
| Read one event | `scripts/cal-read.sh <event-uid> [calendar_name]` |
| Create event | `scripts/cal-create.sh <calendar> <summary> <start> <end> [location] [description] [allday] [recurrence]` |
| Update event | `scripts/cal-update.sh <event-uid> [--summary X] [--start X] [--end X] [--location X] [--description X] [--allday true\|false] [--recurrence X] [--calendar X]` |
| Delete event | `scripts/cal-delete.sh <event-uid> [calendar_name]` |

`--days` accepts negatives: `--days 7` is the next 7 days, `--days -7` is the last 7 days
through the end of today. `cal-events.sh` and `cal-search.sh` also accept the older
positional form (`cal-events.sh 7 Personal`) for convenience.

## How to work with this skill

Most requests are one of two shapes:

**"What's on / am I free?"** → run `cal-events.sh` (or `cal-search.sh` to find a specific
event). Prefer a named `--calendar` when the user points at one; an all-calendar scan
(every non-blocked calendar) is the slow path, so reach for it only when they clearly mean
"everything".

**"Add / move / cancel something"** → mutations need a target. Creating takes a calendar
name; updating and deleting take a **UID**. You usually don't have the UID, so the natural
flow is: search or list to find the event → take its UID from the first column → read it
to confirm you have the right one → then update or delete. Confirm with the user before
deleting, since deletes aren't undoable and a recurring delete removes the whole series.

When the user gives a relative date ("next Tuesday", "tomorrow"), resolve it to a concrete
`YYYY-MM-DD` yourself before calling the scripts — they expect absolute dates.

## Date format (input and output)

One format throughout, so output round-trips straight back into the next command:

- **Timed:** `YYYY-MM-DD HH:MM` (24-hour, local time) — e.g. `2026-06-25 14:00`
- **All-day:** `YYYY-MM-DD`

List/search output is one event per line:

```
UID | Summary | Start | End | AllDay | Location | Calendar
```

`cal-read.sh` prints the full record (adds Description, URL, Recurrence).

## Calendar blocklist

By default the skill works on every calendar. A Mac usually also carries calendars you
*don't* want an assistant editing: a shared work calendar, a partner's calendar,
subscribed holidays, Siri Suggestions. A plain "writable" check won't protect those — a
shared work calendar is writable too. So the boundary is an explicit blocklist: name the
calendars to fence off, and everything else stays accessible.

Create `config/blocklist.txt` with one calendar name per line (`#` comments allowed). Then:

- **Scans** (`cal-events`, `cal-search`, `cal-read` without an explicit calendar) skip
  blocked calendars entirely.
- **Mutations** (`cal-create`, `cal-update`, `cal-delete`) are **refused** for a blocked
  calendar, with a message saying so.
- Naming a blocked calendar explicitly (`--calendar`) returns a clear "on the blocklist"
  error rather than acting on it.

No `config/blocklist.txt` ⇒ nothing is blocked. `cal-list.sh` marks each calendar `ok` or
`blocked` so you can see what's fenced off.

## Recurrence

Pass an iCalendar RRULE as the last `cal-create.sh` argument or via `--recurrence`:

| Pattern | RRULE |
|---------|-------|
| Daily, 10 times | `FREQ=DAILY;COUNT=10` |
| Weekly on Mon/Wed/Fri | `FREQ=WEEKLY;BYDAY=MO,WE,FR` |
| Monthly on the 15th | `FREQ=MONTHLY;BYMONTHDAY=15` |
| Until a date | `FREQ=WEEKLY;UNTIL=20260201` |

Calendar.app exposes only the **master** event over AppleScript, so updating or deleting a
recurring event affects the **entire series**, not a single occurrence. There's no
"this event only" via this interface — tell the user when that matters.

## Notes & limits

- Read-only calendars (Holidays, Birthdays, subscribed feeds) can't be modified; the
  scripts detect this and return a clear error rather than failing cryptically.
- Calendar names are case-sensitive and must match `cal-list.sh` exactly.
- Large all-calendar scans over long windows are slow (Calendar.app cost, not the script).
  Prefer a named `--calendar`, a tighter window, or `--limit N`.
- All user text is passed as separate process arguments, so quotes, apostrophes, and
  non-ASCII (e.g. Chinese) in titles/locations are handled safely.
