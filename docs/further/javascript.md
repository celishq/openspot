# Write it in JavaScript

You'll build Tip: type `tip 42` in the panel, and three totals show as you type, with a 15, 20 and 25% tip. Press one
to copy it.

## Make the folder

`tip.spot/spot.toml`:

```toml
title = "Tip"
icon = "percent"
uses = ["clipboard"]

[on]
search = "^tip [0-9.]+$"
```

`tip.spot/tip.js`:

```js
export default {
  search({ text }) {
    const bill = Number(text.slice(4))
    return [15, 20, 25].map((share) => {
      const total = (bill * (1 + share / 100)).toFixed(2)
      return { item: total, title: total, detail: `${bill} with a ${share}% tip` }
    })
  },
  async press({ item }, env) {
    openspot.call(["clipboard", "copy"], item)
    await env.toast(`Copied ${item}`)
  },
}
```

Don't make `tip.js` executable. Type `tip 42` in the panel, and the rows 48.30, 50.40 and 52.50 show in the same
keystroke.

## How it works

Openspot runs a `.js` spot inside the app, so it answers at once. Each word Openspot asks is a function of the object
that `export default` gives. `search` answers the panel's search, and `press` a press, as `tip.sh search` and
`tip.sh press` would.

Each function gets two things. The first is the inputs, by name: `text` here, `item` in `press`. A number, a `bool` or
a list in your `spot.toml` comes as a number, a boolean or an array. A key of the pressed row, such as `path=`, comes as
`input["item.path"]`.

The second, `env`, runs `openspot` commands. `env.toast("Copied")` is `openspot toast Copied`, and
`env.timer.add(time, "remind")` is `openspot timer add <time> remind`. Each one waits, gives back what the command
printed, and throws when the command fails. A command needs its use in `uses`, as in a script.

`openspot.call(words, stdin)` runs a command too, but it answers before the function goes on, with
`{ stdout, code }`. Use it when you need the answer in the same keystroke, or when the command reads stdin, as
`clipboard copy` does.

## What a function returns

| It returns              | Openspot shows                                                       |
| ----------------------- | -------------------------------------------------------------------- |
| An array of objects     | One block for each object, with its keys as lines, such as `item`.  |
| A string                | The lines in it, as a script prints them.                            |
| Another object          | The action's values: each key becomes an `out.<key>` line.           |
| Nothing                 | Nothing. The panel closes after a press.                             |

A function that throws fails with its message, as a script that prints `error=` does.

## What `env` holds

| Name                              | Is                                                                            |
| --------------------------------- | ----------------------------------------------------------------------------- |
| `env.<noun>.<verb>(...)`          | An `openspot` command: its words in order, then an object of its inputs, then its options, such as `env.timer.add(t, "remind", { words: "Stand-up" })`. |
| `env.<binding>.<action>(inputs)`  | An action of a spot you bind. It gives back its values, or `null` when people close it. |
| `env.emit(event, values)`         | `openspot emit`: sends one of your spot's events.                            |
| `env.cache.get(name)`, `env.cache.set(name, value)` | Your spot's cache, at once and with no `await`; see [Keep a copy that goes old](../remember/cache.md). |
| `env.open(id)`                    | `openspot spot open`: opens the panel on a spot.                             |
| `env.settings`                    | Your spot's settings, by name.                                                |

A verb of two words is in camelCase, such as `env.screen.recordStop()` for `openspot screen record stop`.

## What it can't do

A JavaScript spot is one file. It can't `import`, read files, reach the network or start a program, except through an
`openspot` command. Each word Openspot asks gets 10 seconds of running code. Time spent in an `await` doesn't count.

## Let your editor check it

```text
openspot types tip
```

This writes `openspot.d.ts` beside `tip.js`, with a type for each input, setting and command your spot can use. Put
`/** @satisfies {import("./openspot").Handlers} */` before `export default`, and your editor checks each function.

## Next

- [Write it in Swift](swift.md)
- [Use another spot](../connect/other-spots.md)
