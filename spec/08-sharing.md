# 08 Sharing

`final` · Needs 01.

## Share a spot

To send a spot to another person:

1. Select the spot and press ⌘K.
2. Choose "Copy to share", or press ⌘⇧C. This puts a `.spot` file on the clipboard.
3. Paste the file into a chat or a mail. Check it for secrets first, because Openspot does not.

To install a spot that you got, double-click its `.spot` file, drop it on the Openspot item in the menu bar or on the panel, or
copy the file and press ⌘V in the panel. The path of the file in the search field also works. The panel says what the file is before you drop it.
Openspot shows what runs by itself, each file that it replaces and all the text it can. It names each file that it cannot show,
and a program comes first. Nothing runs until you press ⌘⏎ to add it.

A `.spot` file is JSON. It holds a format number and the files:

```json
{
  "files": [
    { "executable": true, "path": "weather.sh", "text": "#!/bin/sh\nsay hello\n" }
  ],
  "format": 1
}
```

- A script in a folder takes the whole folder. A widget takes each script that it places or opens.
- A file that is not text uses `data`, in base64, in place of `text`.
- Hidden files and `$OPENSPOT_DATA` stay behind.
- A compiled program travels, but no one can read it first. Install one only if you trust the sender.
- "Copy to share" compiles a Swift script for both kinds of Mac, and adds `<name>.program` beside it. The sender needs the Command Line Tools, and the receiver needs nothing. The source gives the header, the program runs in its place, and a program file is never a spot of its own. To run an edited source, delete the program.
- A file with the same path is replaced, and the old file goes to the Trash.

## Delete a spot

Select the spot and press ⌘⌫ twice, or press ⌘K and choose "Delete". Its file goes to the Trash. The other files of its folder and
what it keeps in `$OPENSPOT_DATA` stay. A widget file goes whole, with each widget in it.

## Rules

| ID | Rule |
|---|---|
| P4 | Before a person installs a shared spot, Openspot shows all the text it can, says what runs by itself and names each file that it cannot show. Only a modified key installs it. |
| P6 | A `.spot` file can carry a compiled program, and the review says first that no one can read it. "Copy to share" compiles a Swift script into `<name>.program` beside its source, and the program runs in its place. |
| P7 | A `.spot` file has no signature. Openspot warns the sender about secrets, and does not look for them. |
| P9 | A core spot needs no review, because it is signed with the app. |

## Why not

| Decision | Why | Rejected |
|---|---|---|
| A spot travels as a `.spot` file of JSON: a format number and its files | A chat takes a file of any size, any editor shows JSON, and the header already holds each fact. | Encoded text, a zip, a link. |
| A spot travels with what it needs | A widget works only with the metrics it places, and a script in a folder can need its other files. | Only single scripts. |
| A shared file of the same path replaces the old one, which goes to the Trash | A new name would break the IDs that a widget places. | A new name for each clash. |
