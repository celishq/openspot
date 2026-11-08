# 08 Sharing

`final` `optional` · Needs 01.

A spot travels as a `.spot` file. It is JSON, with a format number and the files:

```json
{
  "files": [
    { "executable": true, "path": "weather.sh", "text": "#!/bin/sh\nsay hello\n" }
  ],
  "format": 1
}
```

- `path` is relative to the plugins folder. A file that is not text uses `data`, in base64, in place of `text`.
- A script in a folder takes the whole folder. A widget file takes each script that it places or opens.
- Hidden files and `$OPENSPOT_DATA` stay behind.
- A Swift script can travel with `<name>.program` beside it, a program compiled for both kinds of Mac. The source gives the
  header, and the program runs in its place. A program file is never a spot of its own (P6).
- On install, a file with the same path replaces the old one, which goes to the Trash.

Before a person installs a shared spot, Openspot shows all the text it can, says what runs by itself and names each file
that it cannot show, a program first. Only a modified key installs it (P4). A `.spot` file has no signature. Openspot warns
the sender about secrets, and does not look for them (P7). A core spot needs no review, because it is signed with the app
(P9).

## Decisions

| Decision | Rejected |
|---|---|
| A `.spot` file of JSON: a chat takes a file of any size, any editor shows JSON, and each header already holds each fact. | Encoded text, a zip, a link. |
| A spot travels with what it needs, such as the metrics of a widget or the other files of a folder. | Only single scripts. |
| A file of the same path replaces the old one, because a new name would break the IDs that a widget places. | A new name for each clash. |
