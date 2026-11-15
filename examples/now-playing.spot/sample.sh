#!/bin/sh
here=$(cd "$(dirname "$0")" && pwd)
printf 'grid.large=cover cover cover song song song\ngrid.large=cover cover cover time time time\ngrid.large=cover cover cover prev play next\nmain=song\n\n'
printf 'picture=cover\nicon=%s\n\n' "$here/cover.jpg"
printf 'text=song\ntitle=Midnight Drive\ndetail=Neon Coast\n\n'
printf 'graph=time\ntitle=1:42\nvalue=0.42\n\n'
printf 'button=prev\ntitle=Previous\nicon=backward.fill\nlook=bare\n\n'
printf 'button=play\ntitle=Pause\nicon=pause.fill\nlook=bare\n\n'
printf 'button=next\ntitle=Next\nicon=forward.fill\nlook=bare\n'
