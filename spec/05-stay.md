# 05 Stay

`draft` · Needs 01.

A plugin keeps state in this order of preference: files in `OPENSPOT_DATA`, a capability that stays loaded (07), or
`stay=true`.

A script with `# stay=true` in its header runs while something wants it, so that a model or a connection stays loaded
between calls. Something wants it while its sheet is open and the panel is open, while the panel is open and a widget
places it or `panel` is in its `read`, while the menu bar shows it, or at all times with `launch` in its `read`. It starts
when something first wants it, and the sheet shows with its first frame. When nothing wants it, Openspot closes its input.
After 2 seconds its group gets the terminate signal, and 2 seconds after that Openspot kills what still runs.

It gets one block on stdin for each call, with a blank line after it: `name`, `value`, one `field.<id>` for each value
of the sheet, and the `id` of the call. A `drop` has one `value` line for each path. A pick, an action, a form and a drop
reach the script that runs, and no call starts a second copy. It keeps its own state, and answers with frames.

```text
name=input
value=Hello
id=4

```

To show that a call runs, print `end=<id>` when it is done, as a block of its own. Once a script has printed one `end`,
each later call shows as running until its `end`, the script keeps running for it, and a second press sends the block
`stop=<id>`. A script that never prints `end` shows no running mark, and a press does not stop its calls.

If it ends and something still wants it, the next moment or call starts it again. After 3 failures in one minute, Openspot
tells the person, and does not start it again until a scan finds its file changed.

## Rules

| ID | Rule |
|---|---|
| Y1 | A staying script gets one block on stdin for each call: `name`, `value`, `field.<id>` for each value of the sheet, and `id`. |
| Y2 | Each call reaches the running script. No call starts a second copy. |
| Y3 | A staying script starts when something first wants it (L3). |
| Y4 | To end it, Openspot closes its stdin, then terminates its group after 2 seconds and kills it 2 seconds later. |
| Y5 | If it ends and something still wants it, the next call starts it again. After 3 failures in one minute, it waits for a changed file, and the person is told. |
| Y6 | Openspot can stop a staying script at any time. What must survive goes in `OPENSPOT_DATA`. |
| Y7 | Once a script has printed one `end=<id>`, each later call runs until its own `end`, and the script keeps running for it. A second press sends `stop=<id>`. |

## Why not

| Decision | Why | Rejected |
|---|---|---|
| A staying script says so in its header | A normal script reads stdin to its end, so the app must close stdin before the answer. | The app keeps any process that stays alive after `end=<id>`. |
| A stop is the block `stop=<id>` | No name of a part or an action can clash with it. | `name=stop`. |
| `stay` exists beside capabilities | A socket or a compiled program has its own state. | Only capabilities. |
