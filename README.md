<div align="center">
  <img src="app/Shell/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png" width="160" alt="Openspot icon">
  <h1>Openspot</h1>
  <p><strong>The Mac launcher that you shape with small tools.</strong><br>Make tools for yourself with your agent, and share them with others.</p>
  <p>
    <a href="https://github.com/celishq/openspot/releases/latest">Download</a> ·
    <a href="app/Shell/GUIDE.md">Make a tool</a> ·
    <a href="CONTRIBUTING.md">Contribute</a>
  </p>
  <sub>Requires macOS 26 or later.</sub>
</div>

<br>

Openspot is a minimal launcher for your Mac. Think Winamp, for Mac launchers.

Need a tool for one job, or for one day? Tell your coding agent what it should do. A moment later, the tool is in your launcher. You need no Xcode, no developer account and no release.

Openspot gives each tool the same clean look and the power of your Mac. Your tools shape the rest. When a tool works, send it to a friend. They see what it does and add it, with nothing else to install.

## Features

- **Small.** Only 7 MB on your Mac.
- **Fast.** Openspot draws the panel when it starts, so it opens the moment you press your key.
- **One look.** A tool prints data, and Openspot draws it. So each tool looks like part of your Mac.
- **Any language.** Write tools in shell, Python, Swift or any language you like. A Swift tool can even open its own window.
- **Made for agents.** One guide tells your agent all that it needs.
- **Safe to share.** Send a tool as one file. Your friend sees what it runs before they add it.

## Get started

1. Download the [latest release](https://github.com/celishq/openspot/releases/latest).
2. Open the disk image and drag Openspot to Applications.
3. Open Openspot and press `⌃Space`. You can change the key in Settings.

## Make your own tool

**Ask your agent.** Paste this into your coding agent, and change the last line:

```text
Read https://raw.githubusercontent.com/celishq/openspot/main/app/Shell/GUIDE.md.
Then make an Openspot tool in ~/.config/openspot/plugins that shows the weather here.
```

**Make one yourself.** Save this as `~/.config/openspot/plugins/hello.sh` and run `chmod +x` on it. It shows the next time you open the panel.

```sh
#!/bin/sh
# name=Hello
# symbol=hand.wave
echo "toast=Hello"
```

**Share it.** Select the tool in the panel and press ⌘⇧C. Then paste the `.spot` file into a chat.

**Add one you got.** Double-click the `.spot` file, read what it runs and press ⌘⏎.

The [`plugins`](plugins) folder has more tools to copy, such as battery, windows and a color picker.

## License

[MIT](LICENSE)
