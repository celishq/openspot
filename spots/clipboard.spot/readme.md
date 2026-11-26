Puts what you copied in the last 2 minutes in the panel's field: files as files, a link as a link, a picture as an image file, and anything else as text. It skips a password that a password manager copied. Copy something, open the panel, press Tab, and pick a spot that takes it.

It reads the clipboard for the field only when the panel opens. It counts the 2 minutes from the moment Openspot first sees the copy, at the latest the next open of the panel, so a copy made while Openspot was not looking shows once more at that open.

It also keeps each copy in the timeline for 30 days, in its kind, with a copy of a picture and of a file of up to 25 MB. Turn off Keep history in its Settings to keep nothing. `openspot timeline list --spot clipboard` prints what it kept.
