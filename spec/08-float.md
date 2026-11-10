# 08 Float

`draft` `optional` · Needs 01 and 02.

```sh
#!/bin/sh
# title=Shelf
# icon=tray.full
# drop=*
# read=sheet
# float=true
```

`float=true` in the header offers the spot as a float (T1). Settings then lists it, and the person can give it a key or a
shake of the pointer. That key or shake shows the spot in a small window of its own at the pointer, outside the panel:
its sheet, or its card when it has no sheet. The window stays while the person works in other apps, and the same key or
shake closes it.

The script runs as it does in the panel, with the same calls and the same frames, and it never learns where it shows. A
spot that does not offer a float shows only in the panel.

## Decisions

| Decision                                                                         | Rejected                                                     |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| The header offers a float, and the person gives it a key or a shake in Settings. | A key or a shake in the header, which a shared script could claim. |
| Only a spot that offers a float takes one, so Settings lists only those.          | A Float row for every spot.                                  |
| The script never learns where it shows.                                          | A call or an environment variable that names the window.     |
