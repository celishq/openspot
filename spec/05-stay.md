# 05 Stay

`draft` `optional` · Needs 01 and 02.

```sh
#!/bin/sh
# title=Relay
# stay=true
# read=launch
. "$OPENSPOT_SH"
while next; do
  case "$(arg 1)" in
    read) printf 'end=%s\n\ntext=peer\ntitle=Waiting\n---\n' "$call" ;;
    ping) printf 'toast=Pong\nend=%s\n---\n' "$call" ;;
    *) printf 'end=%s\n---\n' "$call" ;;
  esac
done
```

A script with `stay=true` in its header is one process that talks both ways over stdio (Y1). Use it to keep a connection,
a model or a local server alive between calls. Each call reaches the running process, and no call starts a second copy (Y2).

## Calls on stdin

Openspot writes each call to stdin as one block, then a blank line. `call=<n>` numbers the call, and a read has
`reason=<word>` with the word that `OPENSPOT_REASON` gives in 01. One `arg` line follows for each argument of the same
call in 01, in order. The values of the sheet follow, as stdin holds them in 01.

```text
call=4
arg=wifi
arg=home
arg=false
wifi=false

```

`call`, `reason` and `arg` are reserved, so no component can take them as its id. Stdin stays open while the script runs.

The shell helper of 01 reads the calls. `next` reads one call and fails at the end of stdin. It sets `call` and `reason`,
and `arg <n>` and `value <id>` give the arguments and the values of that call. After a stop block, `stop` holds the number
of the call to stop.

## Frames on stdout

The script prints frames at any time, also with no call, such as when a message comes from another process. It ends each
call with `end=<n>` in the head of a frame (Y7). The frame that ends a read is its answer, and it replaces all that the
spot shows. Any other frame changes only what it prints, so a frame that no read asked for never replaces the sheet.

A call shows as running until its `end`, and a second press sends the block `stop=<n>`. A call that never ends runs until
the script ends. A newer search sends `stop=<n>` for the search before it, whose answer then changes nothing.

## Its life

It runs while something wants it: its open sheet, a widget or the menu bar that shows it, the open panel with `panel` in
its `read`, or a call that waits for its `end` (Y3). With `launch` in its `read`, it runs from the start of the app to its
quit. When nothing wants it, Openspot closes its stdin. The script must end then, and so must each process that it
started. After 2 seconds its process group gets the terminate signal, and 2 seconds later the kill signal.

If it ends and something still wants it, the next moment or call starts it again. After 3 failures in one minute, Openspot
tells the person, and starts it again only when a scan finds its file changed (Y5). Openspot can stop it at any time, so
what must survive goes in `OPENSPOT_DATA`. `OPENSPOT_STAY=true` is in its environment.

## Decisions

| Decision                                                                              | Rejected                                                   |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| A staying script says so in its header, because a script that runs once reads stdin to its end before it answers. | A script that keeps running after its first answer stays. |
| A call holds the same `arg` words as the arguments of a call in 01, so one `case` handles both. | `name`, `value` and `field.<id>`.                          |
| The answer to a read is the frame that ends it, so a frame from a peer can come at any time. | The first frame after a read.                              |
| A stop is a block of its own, `stop=<n>`, so no id that an author picks can clash with it. | A call named `stop`.                                       |
| The script owns its sockets and its peers, and the app owns only stdio.               | A network capability in the app.                           |
