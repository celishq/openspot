# 05 Stay

`draft` `optional` · Needs 01.

A plugin keeps state in this order of preference: files in `OPENSPOT_DATA`, a capability that stays loaded (07), or
`stay=true`.

A script with `stay=true` in its header keeps running while something wants it (L3), so that a model or a connection stays
loaded between calls. It starts when something first wants it (Y3). Each call reaches the running script, and no call
starts a second copy (Y2).

It gets one block on stdin for each call, with a blank line after it: `name`, `value`, one `field.<id>` for each value of
the sheet, and the `id` of the call. A `drop` has one `value` line for each path (Y1). It answers with frames.

```text
name=input
value=Hello
id=4

```

- **Calls that run.** Once the script prints one `end=<id>`, as a block of its own, each later call runs until its own
  `end`, and a second press sends the block `stop=<id>`. A script that never prints `end` shows no running mark, and a
  press does not stop its calls (Y7).
- **The end.** When nothing wants it, Openspot closes its stdin. 2 seconds later its group gets the terminate signal, and 2
  seconds after that Openspot kills what still runs (Y4).
- **Two copies.** A copy that Openspot ends gets no more calls, but it can finish its last calls for up to 4 seconds while
  a new copy starts. So two copies share state only through whole files (R8).
- **A restart.** If it ends and something still wants it, the next call starts it again. After 3 failures in one minute,
  Openspot tells the person, and does not start it again until a scan finds its file changed (Y5).
- **No promise.** Openspot can stop it at any time, so what must survive goes in `OPENSPOT_DATA` (Y6).

## Decisions

| Decision | Rejected |
|---|---|
| A staying script says so in its header, because a normal script reads stdin to its end. | The app keeps any process that stays alive. |
| A stop is the block `stop=<id>`, so no name of a part or an action can clash with it. | `name=stop`. |
| `stay` exists beside capabilities, because a socket or a compiled program has its own state. | Only capabilities. |
