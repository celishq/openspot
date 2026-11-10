# 07 Files out

`draft` `optional` · Needs 01 and 02.

```sh
#!/bin/sh
# title=Shelf
# icon=tray.full
# drop=*
# read=sheet
list="$OPENSPOT_DATA/files"
case "$1" in
  read)
    [ -f "$list" ] || exit 0
    while IFS= read -r path; do
      [ -e "$path" ] && printf 'row=%s\ntitle=%s\nicon=%s\nfile=%s\n\n' "$path" "${path##*/}" "$path" "$path"
    done < "$list"
    ;;
  drop) shift; printf '%s\n' "$@" >> "$list" ;;
  drag)
    shift
    for path; do grep -vxF "$path" "$list" > "$list.new"; mv "$list.new" "$list"; done
    ;;
esac
```

A row with `file=<path>` stands for that file (O1). The person can drag the row out of the sheet into any app that takes
files, as they drag a file out of Finder. The path starts with `/`. A row whose file does not exist drags nothing.

The app that takes the drop chooses to copy or to move the file, as it does for a drag out of Finder. After a move, the
path is gone, so a read leaves out each file that does not exist.

When the drop ends in another app, Openspot calls `<script> drag <row id> [row id]...`, with the id of each row that the
drag held (O2). A drag that ends with no drop sends nothing. The script removes the rows, as a shelf does, or keeps them.
With no answer, Openspot reads again (M4). `drag` is a default id of 01, and it reaches only a script that prints `file`,
which then cannot give a component that id.

A drag of the picture in the head of the sheet drags every row that has a `file` at once, and `drag` gets the id of
each (O3).

## Decisions

| Decision                                                                    | Rejected                                                    |
| --------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `file` names the file of a row, apart from its id and its picture.          | A row id that is a path, which makes the id say two things. |
| `drag` tells the script after the drop, and the script says what stays.     | A key that removes a row after a drag.                      |
| Openspot drags the file itself, and the other app copies or moves it.        | A file promise that the script writes on request.           |
