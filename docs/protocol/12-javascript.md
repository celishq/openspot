# A JavaScript spot

`draft` `optional` · Builds on [01](01-spot.md)

Use this when your spot should answer in the same keystroke, such as a calculator in the panel's search, or wait for
the person or another spot inside a handler. A JavaScript spot is a `.js` file that runs inside Openspot.

```toml
title = "Clocks"
icon = "globe"
```

```js
export default {
  async show(input, env) {
    return ["Europe/Paris", "America/New_York", "Asia/Tokyo"].map((zone) => ({
      item: zone,
      title: new Date().toLocaleTimeString("en-GB", { timeZone: zone, hour: "2-digit", minute: "2-digit" }),
      detail: zone.split("/")[1].replace("_", " "),
    }))
  },
}
```

The sheet shows three rows, the time in Paris, New York and Tokyo, each with its city under it.

| Name                             | Is                                                                     |
| -------------------------------- | ---------------------------------------------------------------------- |
| `export default`                 | The object of handlers, each a function of `(input, env)` named for its call. |
| `input`                          | The inputs of the call, typed by `spot.toml`, with item keys as `input["item.<key>"]`. |
| `env.<noun>.<verb>(...)`         | An `openspot` command, such as `env.timer.add(...)` or `env.toast("Copied")`. |
| `env.<binding>.<action>(inputs)` | A run of an action of a bound spot, which resolves to its values, or `null` when the person closes it. |
| `env.emit(event, values)`        | A send of one of the spot's events.                                    |
| `env.settings`                   | The settings of the spot.                                              |
| `env.open(id)`                   | An open of a spot.                                                     |
| `openspot.frame(objects)`        | The text of a frame, with an object for each block.                    |
| `openspot.call(words, stdin)`    | A run of any other `openspot` command, which returns `{ stdout, code }`. |

- A handler returns a string, the text of a frame; an array of objects, one for each block; an object, whose keys
  become `out.<name>` lines; or nothing. A throw fails the call with its message.
- `env.<noun>.<verb>` takes the words of the command in order, then an object of inputs, then one of options, such as
  `{ dryRun: true }`. The noun and the verb are in camelCase, such as `env.screen.recordStop()`.
- A spot is one file, and has no files, no network and no process: any `import` keeps it from loading.
- A call has 10 seconds of running code. An `await` doesn't count.
- `openspot types` writes `openspot.d.ts` beside the file. With `/** @satisfies {import("./openspot").Handlers} */`
  before `export default`, an editor checks each handler and command.
