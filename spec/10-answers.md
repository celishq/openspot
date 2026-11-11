# 10 Answers

`draft` `optional` · Needs 01 and 02.

```sh
#!/bin/sh
# title=Calculator
# icon=equal.square
# answers=^[0-9(]
case "$1" in
  read) [ -n "$2" ] && openspot calc solve "$2" ;;
  open) printf %s "$2" | pbcopy && printf 'toast=Copied %s\n' "$2" ;;
esac
```

A script with `answers=<pattern>` in its header answers the main search (A1). The pattern is a regular expression, and `^`
ties it to the start of the text. Openspot sends each text of the main search that the pattern matches, such as `2*(3+4)`,
as `<script> read <text> [form]...` with `OPENSPOT_REASON=search`, as `search=script` does in a sheet (02). The script
prints the rows that answer the text, or nothing.

- Openspot asks at each change of the text, with no pause, and a newer text stops the older call (A2). Keep the answer
  fast, because a script that runs once for each call starts at each key.
- The rows show first in the main search, each with its own `detail` under its `title` (A3). They stay until the newest
  text is answered, and they go at once when the pattern no longer matches.
- A pick of a row is `<script> open <row id>`, as in 01.
- A script with `answers` and no `read` has no card, so it shows only its answers. With a `read`, it is a spot like any
  other.
- A script with `stay=true` cannot answer the main search.

`openspot calc solve <words>...` prints the answer of a sum, a conversion or a date as a row, so a spot can print it as it
is. The row's id is the plain value, such as `3.75`. `openspot help` lists what it reads.

## Decisions

| Decision                                                                                                         | Rejected                                    |
| ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| A pattern in the header says which text a spot answers, so a scan learns it with no run, and a key starts no other script. | Each script asked at each key.          |
| An answer is the call of a search that the script does, so a script has one shape for both.                    | A new call, such as `answer <text>`.        |
| Answers show first, because they are about the whole text that the person typed.                                 | A rank that each spot gives its rows.       |
