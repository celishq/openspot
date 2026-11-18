#!/bin/sh
printf 'frame=\ngrid=last last last\ngrid=last last last\ngrid=peer peer peer\ngrid=- - -\n'
printf 'grid=message message message\ngrid=message message message\ngrid=. . send\n\n'
printf 'text=last\ntitle=Build 412 passed in 3m 08s\ndetail=From a peer\n\n'
printf 'field=peer\ntitle=To\nvalue=127.0.0.1:47801\n\n'
printf 'field=message\ntype=multiline\nplaceholder=Hello\n\n'
printf 'button=send\ntitle=Send\nshortcut=cmd+return\nclose=false\n'
