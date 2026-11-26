# Build and check a spot

You can build a whole spot from the terminal, without the panel: start it, run it, look at it, check it, then hand it
over. A coding agent works the same way. Each step is one `openspot` command.

## Start from a spot that works

```text
openspot spot new "Weather" --from list
```

It writes a spot folder in your spots folder, such as `weather.spot`, and prints the file to change. Its ID is the
path of the folder with no extension, here `weather`. The kind is `button`, `list`, `number` or `form`: pick the one
closest to what your spot shows, then change it. Before you write much, read a spot that already does something close.
The spots that come with Openspot are a good place to look.

## Run each call

```text
openspot spot run weather show
openspot spot run weather press item=kyiv
```

Each run calls your spot as the panel does, and prints what it printed. Try each word your spot answers, with the
inputs the panel would give it. A spot with `[actions]` or `[on]` takes the name of a handler, then each input as
`<name>=<value>`.

## Look at it

```text
openspot render spot weather --card wide card.png
openspot render spot weather sheet.png
```

The first draws the card, the second the sheet. Open the pictures: a run can print the right lines and still look wrong.

## When a call fails

```text
openspot spot log weather
```

It prints the last calls that Openspot made to your spot, each with its stdin, its stdout, its stderr and its exit code.

## Check it

```text
openspot check spots --json ~/.config/openspot/spots
```

It loads and runs each spot of the folder once. It prints `[]` when it finds nothing wrong, or a fault for each mistake,
such as a key that Openspot doesn't know. Fix each one, and check again until it prints `[]`.

## Hand it over

```text
openspot spot open weather --select
```

It opens the panel with your spot selected, so the person sees it at once. Then tell them what the spot runs on their
Mac: each command it starts, each file it reads or writes, and each site it fetches.
