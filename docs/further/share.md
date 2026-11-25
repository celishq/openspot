# Share your spot

You'll share Ports from [Your first spot](../first-spot.md): a page about it, a picture with made-up ports, and one
file that a friend opens.

```text
ports.spot/
  spot.toml
  ports.sh
  readme.md
  sample.sh
```

## Write its page

`readme.md` is the page people read about your spot, in the Store and before they add it:

```md
Lists the programs that listen on a port, such as a server you forgot on :3000. Press a row to stop it.

![Ports in the panel](ports.png)

It runs `lsof` when you open it, and sends nothing over the network.
```

A line that starts with `#` is a heading, and a line can hold **bold**, `code` and links. A picture line, such as the
one above, shows a picture or a video, from a file in the folder or a web address.

The Store shows `detail` from `spot.toml` under your spot's name:

```toml
title = "Ports"
icon = "network"
detail = "Stop what listens on a port"
```

## Show it with made-up data

`sample.sh` prints what your spot shows, without reading anything on the Mac:

```sh
#!/bin/sh
printf 'item=4120\ntitle=:3000\ndetail=node\n\nitem=812\ntitle=:5432\ndetail=postgres\n'
```

Make it executable. Try on your spot's page in the Store shows your sheet with it, so people see your spot before they
add it. Put what it prints in `sample.frame` beside it, and a store shows it without running your code.

## Share it

Press `⌘K` on your card, then Share (`⌘⇧C`). Or run:

```text
openspot spot share ports
```

Openspot signs a release of your spot with your account, and copies `Ports.spot` to the clipboard. Paste it into a
message. The first time, Openspot opens Account, so you can make one.

- The release goes into `releases.jsonl` in your folder. Each share of changed files adds the next version, and a share
  with no change adds none. Don't edit the file: Openspot refuses a spot whose files don't match its last release.
- The file leaves out hidden files and the `tests` folder. Openspot never sends the program it built from a Swift spot.
  It builds a new one from your sources.
- A shared spot holds 25 MB at most. A bigger one fails to share and says so.
- Your files go as they are, so check them for secrets first.

To offer your spot in the Store instead, put its folder in a folder of spots that your friend adds with Add Source….

## Add a shared spot

Your friend double-clicks `Ports.spot`, or pastes it into the panel with `⌘V`. The Store opens at its page, with your
readme and the trust lines. Install shows the review first, and adds the file as they saw it: a file changed since is
refused. [The review before an add](../../TRUST.md#the-review-before-an-add) lists what it shows. From the terminal, `openspot spot add` takes the file, a folder or a git URL:

```text
openspot spot add ~/Downloads/Ports.spot
```

When you share a new version, adding it again updates the spot. An update that adds a use waits for their yes. One
signed by another account says so.

A spot that a friend installs from a store updates from it by itself, until they edit it. They see the day of each
version, such as "Updated 3 Nov", never a hash.

## Next

- [Signed releases](../../TRUST.md#signed-releases)
- [The openspot command](../reference/commands.md)
