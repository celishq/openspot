# openspot screen

`draft` · `openspot help screen` prints this guide. It builds on `openspot guide`, whose rules it names by their IDs.

```sh
#!/bin/sh
# title=Shot
# icon=camera.viewfinder
file=$(openspot screen shot) || exit 1
[ -n "$file" ] || exit 0
openspot clipboard copy "$file" && echo "toast=Copied the picture."
```

`openspot screen` takes pictures and recordings of the screen. Each one goes to a file, and the command prints the path
(S1). The script does the rest, such as a copy, an upload or an edit in its own window.

| Command                                                                                | Does                                                                   |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `openspot screen sources`                                                              | Prints each display, window, microphone and camera as a row (01).      |
| `openspot screen shot [source] [--cursor] [file]`                                      | Takes a picture, and prints its path.                                  |
| `openspot screen record start [source] [input]... [--cursor] [--events <file>] [file]` | Starts a recording, and prints nothing.                                |
| `openspot screen record stop`                                                          | Ends the recording, and prints the path of each file, the video first. |
| `openspot screen record status`                                                        | Prints one block: `state=recording` with its files and `seconds`, or `state=idle`. |

## Sources

A source is one word that says what to capture (S2). The id of each row that `openspot screen sources` prints is its word,
so a script can show the rows in its sheet and keep the picks of the person with `openspot setting`.

| Source                                   | Captures                                                    |
| ---------------------------------------- | ----------------------------------------------------------- |
| `display`, `display:<id>`                | A whole display.                                            |
| `window`, `window:front`, `window:<id>`  | One window. `front` is the front window of the front app.   |
| `area`, `area:<x>,<y>,<width>,<height>`  | A part of one display.                                      |

The values of an area are read as `openspot window move` reads them: a number from 0 to 1, a percent or a fraction is a
part of the main display, and any other number is points from the top left of the main display. So `area:0,0,1,1` is the
whole main display, and `area:0,0,1/2,1` is its left half. An area that does not lie on one display fails.

A source with no value lets the person pick one of its kind. With no source, the person picks any kind: a drag picks an
area, a click picks the window under the pointer, and a click where no window is picks the display. Escape cancels: the
command prints nothing and exits 0 (S3).

## Inputs

A recording takes inputs after its source (S4).

| Input                    | Records                                                                          |
| ------------------------ | -------------------------------------------------------------------------------- |
| `mic`, `mic:<id>`        | A microphone, into the sound of the video. `mic` is the one that macOS uses now. |
| `system`                 | The sound of the Mac, into the sound of the video. Openspot's own sound is left out. |
| `camera`, `camera:<id>`  | A camera, into its own file beside the video, such as `Talk.camera.mov`.         |

The camera has its own file, so an editor can place it, size it or leave it out.

`--cursor` draws the pointer in a picture or a video. `--events <file>` writes what the pointer and the keys do while it
records, one JSON object on each line (S5):

```text
{"type":"frame","width":1512,"height":982,"scale":2}
{"type":"move","t":0.016,"x":740.5,"y":402}
{"type":"down","t":1.2,"x":740.5,"y":402,"button":"left"}
{"type":"up","t":1.31,"x":740.5,"y":402,"button":"left"}
{"type":"key","t":2.04,"key":"s","modifiers":["cmd"]}
```

The first line gives the size of the video in points and its pixels for each point. `t` is the second of the video, and
`x` and `y` are points from its top left. A key needs Input Monitoring: the first recording with `--events` asks macOS
for it, and until the person allows it, the file has no keys (S6).

## Files

The extension of the file sets its format: `.png`, `.jpg` or `.heic` for a picture, and `.mp4` or `.mov` for a video.
With no file, it goes to the folder where macOS keeps screenshots, with a name such as
`Screenshot 2026-11-10 at 09.41.07.png` or `Screen Recording 2026-11-10 at 09.41.07.mp4` (S7).

## Rules

- `shot`, `record start` and `record stop` fail in a read (K4), so that nothing captures the screen by surprise.
  `sources` and `record status` work in a read (S8).
- A capture never shows a window of Openspot (S9).
- One recording runs at a time. It goes on after the call that started it ends, until `openspot screen record stop` (S10).
- When macOS does not allow a capture, the command fails with `link=` to its pane in System Settings: Screen Recording,
  Microphone or Camera (S11).

## Decisions

| Decision                                                                                | Rejected                                                              |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| A capture writes a file and prints its path, and the script chains the next act.        | A copy, an upload or an editor inside the command.                    |
| A recording runs in a helper, so a short call starts it and another stops it.           | One call that records until a stop, whose result a stopped call loses. |
| A source is one word, the id of its row in `sources`.                                    | A flag for each kind of source.                                       |
| Openspot draws its own overlay to pick a source.                                        | The sharing picker of macOS, which cannot pick an area.               |
| The camera writes its own file.                                                         | A camera bubble drawn into the video.                                 |
| The events are JSON lines.                                                              | A new text format.                                                    |
