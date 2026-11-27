Keeps the Mac awake. Open its sheet and pick how long: 30 minutes, 2 hours, Custom… for any number of minutes, until you turn it off, or while a process runs. While it is on,
the card shows the time left, and Turn off is the first row. Quitting Openspot turns it off.

**While a process runs…** lists what runs in your terminals, agents first. A Claude Code agent shows the title of its chat
and its folder. Pick one, and the Mac stays awake until it ends.

Turn off **Keep the display on** to let the screen sleep and lock while the Mac keeps working. It is on by default.

Turn on **Work with the lid closed** to keep the Mac working with its lid closed. A Mac with no lid doesn't show it. The first time, macOS asks you to
turn on Openspot in Login Items & Extensions, which lets Openspot's power helper keep the Mac awake. While it is on, the Mac never sleeps, even closed in a bag, so it can grow
hot and drain its battery.

It runs the `caffeinate` command of macOS while it is on, and `openspot power lid-closed` when you work with the lid
closed.
