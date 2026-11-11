# openspot calendar and openspot reminders

`draft` · `openspot help calendar` and `openspot help reminders` print this guide. It builds on `openspot guide`, whose
rules it names by their IDs.

```text
#!/bin/sh
# title=Today
# icon=calendar
# read=panel
case "$1" in
  read) openspot calendar events ;;
  open) openspot calendar show "$2" ;;
esac
```

`openspot calendar` reads and adds the events of the person, and `openspot reminders` reads, adds and ticks their
reminders. Each list prints rows (01), and the id of each row goes to each other verb as it is (E1).

| Command                                                  | Does                                                                                    |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `openspot calendar events [--days n] [--hide id]...`     | Prints each event that has not ended, through the end of day `n`. Day 1 is today, and it is the default. |
| `openspot calendar calendars`                            | Prints each calendar as a row.                                                          |
| `openspot calendar add [--dry-run] <words>...`           | Adds an event from the words to the default calendar, and prints its row.              |
| `openspot calendar show <id>`                            | Opens Calendar on the day of an event.                                                  |
| `openspot reminders due [--days n] [--hide id]...`       | Prints each open reminder that is late or due through the end of day `n`, and each of those done today. |
| `openspot reminders lists`                               | Prints each list of reminders as a row.                                                 |
| `openspot reminders add [--dry-run] <words>...`          | Adds a reminder from the words to the default list, and prints its row.                |
| `openspot reminders done <id> [true\|false]`             | Ticks a reminder, or with `false` opens it again. It prints nothing.                   |
| `openspot reminders show <id>`                           | Opens Reminders on a reminder.                                                          |

`--hide` takes the id of a row of `calendars` or `lists`, and leaves out its events or reminders. Repeat it for each one.
An id of the other kind is left alone, so a script can pass one set of hidden ids to both.

## Rows

```text
row=event:3F2A…                      row=reminder:9C41…
title=Standup                        title=Call mom
detail=09:30–09:45 · Work            detail=Late · Yesterday 18:00 · Family
icon=video                           icon=circle
tone=on                              tone=bad
start=2026-11-10T09:30:00+01:00      due=2026-11-09T18:00:00+01:00
end=2026-11-10T09:45:00+01:00        list=7D10…
calendar=A8E2…                       color=#FF9500
color=#1BADF8                        done=false
location=Room 4
meeting=https://meet.google.com/abc-defg-hij
```

A row has the keys of 01: `title`, a `detail` in the language of the Mac that says when and where, an `icon`, and a
`tone`: `on` for an event that is on now, and `bad` for a late reminder. Its other keys hold the data, so a view (03) can draw them (E2):

| Key        | Holds                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------- |
| `start`    | When an event starts, in ISO 8601 with the offset of its zone.                              |
| `end`      | When an event ends.                                                                         |
| `due`      | When a reminder is due. A reminder with no due date has none.                               |
| `allday`   | `true` for an event of whole days, or a reminder due on a day with no time.                 |
| `calendar` | The id of the calendar of an event.                                                         |
| `list`     | The id of the list of a reminder.                                                           |
| `color`    | The colour of that calendar or list, as `#RRGGBB`.                                          |
| `location` | Where an event is.                                                                          |
| `meeting`  | The address of a call that the event's address, location or notes hold, such as a Zoom, Meet or Teams link. |
| `done`     | `true` or `false` on a reminder.                                                            |

A row of `calendars` or `lists` has `title`, the account as its `detail`, and `color`.

An id is one word that starts with `event:` or `reminder:`. Pass it on as it is: its form can change. Each time of a
repeating event has its own id. A reminder that the person ticks today stays in `due` with `done=true` until the day
ends, so that a second press can open it again (E3).

## Add

`add` reads the date in the words with the date finder of macOS, in the languages that it knows, and the rest of the words
is the title (E4). `Call mom tomorrow 9am` is a reminder `Call mom` due tomorrow at 9:00.

- An event needs a date. A time with no end lasts one hour, a range such as `13:00-14:30` sets the end, and a day with no
  time makes an event of the whole day.
- A reminder with no date has no due date, and a day with no time is a reminder due on that day.
- A repeat, such as `every Monday`, is not read, so the item happens once.

`--dry-run` prints the row that `add` would make, with the id `event:new` or `reminder:new`, and changes nothing (E5).
Use it to show what the words will make before the person presses Enter.

## Access

The `calendar` verbs need the person's leave to use Calendars, and the `reminders` verbs need it for Reminders.

- Openspot never asks at its start. A verb outside a read asks macOS the first time, and goes on with the answer (E6).
- In a read, a verb that has not asked yet prints `status=unasked` and exits 0, so that the script can offer a row that
  asks (E7).
- When the person said no, the verb fails with `link=` to its pane in Privacy & Security (E8).

A verb never prints an empty list in place of a list that it cannot read.

## Rules

- `add`, `done` and `show` fail in a read, so that nothing changes or opens by surprise (K4). The lists and `add --dry-run`
  work in a read (E9).
- A list is in the order of time: an event by its start, and a reminder by its due time, so that a ticked one keeps its
  place.

## Decisions

| Decision                                                                                       | Rejected                                                 |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| A list prints rows of 01, and the id of a row goes to each other verb as it is.                | JSON, or a lookup by title.                              |
| Two nouns, which are the names of the two apps of macOS.                                       | One `agenda` noun.                                       |
| `add` finds the date in the words, as Calendar's quick event does.                             | A flag for each part of a date.                          |
| A read never asks for leave, and prints `status=unasked`.                                      | A prompt at the first read, or at the start of the app.  |
| `show` opens the app, so a script never builds an address of Calendar or Reminders.           | `open` with an `ical://` or `x-apple-reminderkit://` address. |
| A reminder ticked today stays in `due`, so a second press opens it again.                      | A reminder that leaves the list at its tick, and a confirm. |
