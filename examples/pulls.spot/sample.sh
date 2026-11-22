#!/bin/sh
printf 'frame=\nclass=gap-part\n\nnumber=count\nclass=hidden bar:flex\nvalue=5\ntitle=Pull requests\n\nitems=items\n\n'
printf 'button=copy\nparent=items\ntitle=Copy link\nshortcut=cmd+return\n\n'
printf 'text=https://github.com/example/garden/pull/412\nparent=items\ntitle=Add a dark theme to the plant list\ndetail=Checks passed · garden\nicon=checkmark.circle\ntone=good\n\n'
printf 'text=https://github.com/example/garden/pull/409\nparent=items\ntitle=Fix the watering reminder on Sundays\ndetail=Checks failed · garden\nicon=xmark.circle\ntone=bad\n\n'
printf 'text=https://github.com/example/weather-kit/pull/88\nparent=items\ntitle=Cache the forecast for ten minutes\ndetail=Checks running · weather-kit\nicon=clock\ntone=warn\n\n'
printf 'text=https://github.com/example/weather-kit/pull/86\nparent=items\ntitle=Show wind in knots\ndetail=Checks passed · To review · weather-kit\nicon=checkmark.circle\ntone=good\n\n'
printf 'text=https://github.com/example/notes/pull/231\nparent=items\ntitle=Update the README\ndetail=No checks · To review · notes\nicon=arrow.triangle.pull\n'
