# apple-calendar

[![skills.sh](https://skills.sh/b/K4Lok/apple-calendar)](https://skills.sh/K4Lok/apple-calendar)

A [Claude](https://claude.ai) **skill** for working with the macOS **Calendar.app** from the
command line. It lets Claude read your schedule and create, move, reschedule, search, and
delete events — using AppleScript under the hood, so it works against whatever accounts
Calendar.app already syncs (iCloud, Google, Exchange, on-device) and runs offline against the
local store.

> macOS only. Builds on [tyler6204's apple-calendar](https://clawskills.sh/skills/tyler6204-apple-calendar) — see [NOTICE](NOTICE).

## What it does

- **Check your schedule** — "what's on this week?", "am I free Thursday afternoon?"
- **Find an event** — case-insensitive search across title, location, and notes.
- **Add events** — timed or all-day, with location, notes, and recurrence (RRULE).
- **Reschedule / edit** — move an event, change its time, location, or title.
- **Delete** — remove an event by its UID.
- **Look back** — query past dates and arbitrary ranges, not just "today forward".

Highlights over a plain AppleScript wrapper:

| Feature | Why it matters |
|---|---|
| **ISO 8601 dates** (`2026-06-25 14:00`) | Output feeds straight back into the next command; no locale ambiguity. |
| **Calendar blocklist** | Fence off work/shared/system calendars so the assistant can't touch them. |
| **Past & range queries** (`--days -7`, `--from/--to`) | Answer "what did I have last week?". |
| **Safe edits** | Moving an event later never silently fails (handles the AppleScript start-before-end trap), and real errors aren't swallowed. |

## Requirements

- macOS with the built-in **Calendar.app**.
- A shell with `osascript` (ships with macOS).
- **Automation permission**: the first run triggers a macOS prompt — *"Terminal wants access
  to control Calendar."* Allow it, or commands fail with error `-1743`. You can re-enable it
  later under **System Settings → Privacy & Security → Automation**.

## Install

**Recommended — via the [skills](https://www.skills.sh) CLI** (auto-detects your agent's skills directory):

```bash
npx skills add K4Lok/apple-calendar
```

**Or clone manually** into the directory your Claude agent loads skills from.

Claude Code (per-user):

```bash
git clone https://github.com/K4Lok/apple-calendar.git ~/.claude/skills/apple-calendar
```

…or for a single project, clone into that project's `.claude/skills/apple-calendar`.

openclaw / clawhub-style agents use `.agents/skills/` instead:

```bash
git clone https://github.com/K4Lok/apple-calendar.git .agents/skills/apple-calendar
```

That's it — the skill is self-contained (the `scripts/` are plain bash + AppleScript, no
dependencies to install). Claude will pick it up from `SKILL.md`.

## Optional: block calendars you don't want touched

By default the skill works on **every** calendar. To fence some off, copy the example and
list the calendars to keep off-limits (one name per line, exactly as shown by
`scripts/cal-list.sh`):

```bash
cp config/blocklist.txt.example config/blocklist.txt
```

```text
# config/blocklist.txt
Work
Holidays
Siri Suggestions
```

Blocked calendars are excluded from searches and **refused** for create/update/delete.

## Usage

You normally just talk to Claude ("move my 3pm dentist to 4") and it runs the scripts. To run
them directly:

```bash
cd apple-calendar

scripts/cal-list.sh                      # list calendars (shows ok / blocked)
scripts/cal-events.sh --days 7           # next 7 days
scripts/cal-events.sh --days -7          # last 7 days
scripts/cal-events.sh --from 2026-06-01 --to 2026-06-15
scripts/cal-search.sh "dentist" --days 60
scripts/cal-create.sh Personal "Lunch with Sam" "2026-06-28 12:00" "2026-06-28 13:00" "Tai Hing"
scripts/cal-update.sh <event-uid> --start "2026-06-28 13:00" --end "2026-06-28 14:00"
scripts/cal-delete.sh <event-uid>
```

Dates are `YYYY-MM-DD HH:MM` (timed) or `YYYY-MM-DD` (all-day). Full command reference and
recurrence syntax live in [SKILL.md](SKILL.md).

## Notes

- Editing a **recurring** event changes the whole series — Calendar.app only exposes the
  master event over AppleScript.
- Read-only calendars (Holidays, Birthdays, subscribed feeds) can't be modified; the scripts
  return a clear error instead of failing cryptically.
- Calendar names are case-sensitive.

## Credits

Derived from and credit to **tyler6204's** original `apple-calendar` skill
(openclaw / clawhub). See [NOTICE](NOTICE) for the full attribution and list of changes.
