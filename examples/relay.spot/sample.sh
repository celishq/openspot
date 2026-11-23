#!/bin/sh
printf 'frame=\nclass=grid grid-cols-3 gap-part\n\n'
printf 'text=last\nclass=col-span-3 row-span-2 bar:flex\ntitle=Build 412 passed in 3m 08s\ndetail=From a peer\n\n'
printf 'field=peer\nclass=col-span-3\ntitle=To\nvalue=127.0.0.1:47801\n\n'
printf 'box=line\nclass=col-span-3 h-px bg-tile\n\n'
printf 'field=message\nclass=col-span-3 row-span-2 h-60\ntype=multiline\nplaceholder=Hello\n\n'
printf 'box=blank-1\n\nbox=blank-2\n\n'
printf 'button=send\ntitle=Send\nshortcut=cmd+return\nclose=false\n'
