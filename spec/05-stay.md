# 05 Stay

`draft` `optional` · Needs 01.

```sh
#!/bin/sh
# title=Relay
# mode=always
# read=panel
. "$OPENSPOT_SH"
main() {
  case "$1" in
    read) printf 'text=peer\ntitle=Waiting\n' ;;
    ping) printf 'toast=Pong\n' ;;
  esac
}
openspot_serve main "$@"
```

A script with `mode=stay` or `mode=always` in its header is one process that talks both ways over stdio (Y1). Use it to keep a connection,
a model or a local server alive between calls. Each call reaches the running process, and no call starts a second copy (Y2).

## Calls on stdin

Openspot writes each call to stdin as one block, then a blank line. The block holds the three parts of a call in 01 (C7):
`call=<n>` numbers the call, an `arg` line gives each argument in order, an `env.<name>` line gives each variable of the
call, such as `env.OPENSPOT_REASON=panel`, and one `input` line holds its stdin as one value, with each new line as `\n`
(Y8).

```text
call=4
arg=send
input=peer=127.0.0.1:47800\nmessage=Hello\n

```

A value of the sheet lives inside `input`, so no id that an author picks can clash with a key of the block. Stdin stays
open while the script runs.

The shell helper of 01 reads the calls. `openspot_serve main "$@"` reads each block, runs `main` with its arguments, its
variables and its stdin, as a script that runs once gets them, and prints `call=<n>` before its output and `end=<n>` after it
(Y9). So one `main` runs unchanged with each mode. It runs one call at a time, and `exit` in `main` ends the script.

## Frames on stdout

The script prints frames at any time, also with no call, such as when a message comes from another process. Each frame
follows the rule of 01: a frame with a block is the whole picture, and a frame of only a head carries effects. The script
ends each call with `end=<n>` in the head of a frame (Y7), so a frame can end a call with a new picture, or with effects
alone. A frame of only `call=<n>` starts the output of that call: each frame after it, up to the one with `end=<n>`, answers
the call as a frame of a once script answers it, and a frame of only `end=<n>` ends the call with what it printed (Y8).

A call shows as running until its `end`, and a second press sends the block `stop=<n>`. A call that never ends runs until
the script ends. A newer search, or a newer text of the main search for a spot with `answers`, sends `stop=<n>` for the one before it,
whose answer then changes nothing (I2). `openspot_serve` lets a stopped call run to its end, and its frames change nothing.

## Its life

With `mode=stay`, it runs while something wants it: its open sheet, a widget or the menu bar that shows it, the open panel
with `panel` in its `read` or with `answers`, or a call that waits for its `end` (Y3). With `mode=always`, it runs from the start of the app
to its quit. When nothing wants it, Openspot closes its stdin. The script must end then, and so must each process that it
started. After 2 seconds its process group gets the terminate signal, and 2 seconds later the kill signal.

If it ends and something still wants it, the next moment or call starts it again. After 3 failures in one minute, Openspot
tells the person, and starts it again only when a scan finds its file changed (Y5). Openspot can stop it at any time, so
what must survive goes in `OPENSPOT_DATA`.

## Decisions

| Decision                                                                              | Rejected                                                   |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| A staying script says so in its header, because a script that runs once reads stdin to its end before it answers. | A script that keeps running after its first answer stays. |
| One `mode` key holds the life of the process: `stay` while something wants it, `always` from start to quit. | A `launch` moment beside `mode=stay`.                        |
| A call holds the three parts of a call in 01, and `openspot_serve` gives them to one `main` as a once script gets them (Y8, Y9). | `call`, `reason`, `value` and `arg` lines that a script reads with `next` and `arg`. |
| A frame follows the one rule of 01, so a peer's frame with a block is a new picture.  | A frame that merges what it prints.                        |
| A stop is a block of its own, `stop=<n>`, so no id that an author picks can clash with it. | A call named `stop`.                                       |
| The script owns its sockets and its peers, and the app owns only stdio.               | A network capability in the app.                           |
