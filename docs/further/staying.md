# Keep your spot running

You'll build CPU trend: a chart of the CPU over the last minutes. It keeps its points in memory, so the chart grows
while the panel is open and is still there when you open it again.

## Make the folder

`cpu-trend.spot/spot.toml`:

```toml
title = "CPU trend"
icon = "cpu"
stay = true

[on]
"system.load" = true
```

`cpu-trend.spot/cpu-trend.sh`:

```sh
#!/bin/sh
. "$OPENSPOT_SH"
points=
main() {
  if [ "$1" = system.load ]; then
    load=$(value value)
    cpu=${load#cpu=}
    points="$points,${cpu%% *}"
  fi
  printf 'frame=\nclass=gap-part\n\nseries=cpu\ntitle=CPU\nvalue=%s\nmax=100\nunit=%%\nclass=h-32\n' "${points#,}"
}
openspot_serve main "$@"
```

Every 5 seconds the chart gains a bar.

## How it works

Most spots start fresh each time: Openspot runs the script, reads what it prints, and the script ends. With
`stay = true`, Openspot starts your script once and keeps it running. Each time it would run `cpu-trend.sh show` or
`cpu-trend.sh system.load`, it sends that word to the running script instead. So `points` lives on between them.

That helps in two cases. A spot that's slow to start, such as one that loads a big file, pays that cost once. And a
spot that remembers something, such as these points, keeps it in memory instead of in a file.

`openspot_serve main "$@"` does the reading for you. It runs `main` once for each word Openspot sends, with the word as
`$1` and the inputs ready for `value`. The same script still works without `stay`, so you can try it from the terminal:

```text
openspot spot run cpu-trend show
```

`system.load` comes every 5 seconds with a value such as `cpu=12 memory=40`. The script keeps the number after `cpu=`.

## When it runs

Your script runs while your spot shows: while the panel is open with its card, or while it's in the menu bar. When
nothing shows it, Openspot closes its stdin. End your script then, with each program it started. When the person clicks
outside the panel and opens it again soon, the sheet shows your last answer at once, and Openspot starts your script and
asks it again. With
`"app.launch" = true` in `[on]`, it runs from when Openspot starts until it quits.

## Without the helper

A program in another language reads the same thing on stdin. Each word comes as one block: `call=` with a number, `arg=`
with the word, then the inputs, and a blank line.

```ini
call=7
arg=system.load
input.value=cpu=12 memory=40
```

Your program prints `call=7` and `---`, then its answer, then `---`, `end=7` and `---`. A block `stop=7` asks it to stop
that one.

## Next

- [Write it in Swift](swift.md)
- [What your script prints](../reference/blocks.md)
