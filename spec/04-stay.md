# 04 Stay

`draft` `optional` · Needs 01 and 02.

```sh
#!/bin/sh
# title=Relay
# stay=true
# read=launch
while IFS= read -r line; do
  case "$line" in
    call=*) call=${line#call=}; name= ;;
    arg=*) [ -n "$name" ] || name=${line#arg=} ;;
    '')
      case "$name" in
        read) printf 'text=peer\ntitle=Waiting\n---\n' ;;
        ping) printf 'toast=Pong\nend=%s\n---\n' "$call" ;;
      esac ;;
  esac
done
```

A script with `stay=true` in its header is one process that talks both ways over stdio (Y1). Use it to keep a connection,
a model or a local server alive between calls. Each call reaches the running process, and no call starts a second copy (Y2).

## Calls on stdin

Openspot writes each call to stdin as one block, then a blank line. `call=<n>` numbers the call. One `arg` line follows for
each argument of the same call in 01, in order. The values of the sheet follow, as stdin holds them in 01.

```text
call=4
arg=wifi
arg=home
arg=false
wifi=false

```

`call` and `arg` are reserved, so no component can take them as its id. Stdin stays open while the script runs.

## Frames on stdout

The script prints frames at any time, also with no call, such as when a message comes from another process. Each frame
follows 02: the answer to a `read` replaces all that the spot shows, and any other frame changes only what it prints (U11).

`end=<n>` in the head ends call `n` (Y7). Once a script has printed one `end`, each later call shows as running until its
own `end`, and a second press sends the block `stop=<n>`. A script that never prints `end` shows no running mark, and a
press does not stop its calls.

## Its life

It runs while something wants it: its open sheet, a widget or the menu bar that shows it, the open panel with `panel` in
its `read`, or a call that waits for its `end` (Y3). With `launch` in its `read`, it runs from the start of the app to its
quit. When nothing wants it, Openspot closes its stdin.
The script must end then. After 2 seconds its process group gets the terminate signal, and 2 seconds later the kill
signal (Y4).

If it ends and something still wants it, the next moment or call starts it again. After 3 failures in one minute, Openspot
tells the person, and starts it again only when a scan finds its file changed (Y5). Openspot can stop it at any time, so
what must survive goes in `OPENSPOT_DATA` (Y6).

`OPENSPOT_STAY=true` is in its environment. The shell helper of 01 then leaves stdin alone, so `esc` works and `value`
gives nothing.

## Decisions

| Decision                                                                              | Rejected                                                   |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| A staying script says so in its header, because a script that runs once reads stdin to its end before it answers. | A script that keeps running after its first answer stays. |
| A call holds the same `arg` words as the arguments of a call in 01, so one `case` handles both. | `name`, `value` and `field.<id>`.                          |
| A stop is a block of its own, `stop=<n>`, so no id that an author picks can clash with it. | A call named `stop`.                                       |
| The script owns its sockets and its peers, and the app owns only stdio.               | A network capability in the app.                           |
