#!/bin/sh
printf 'frame=\nclass=gap-part\n\nfield=search\ntype=search\n\nchoice=tone\ntitle=Skin tone\nvalue=none\n\n'
printf 'option=none\ntitle=Yellow\n\noption=light\ntitle=Light\n\noption=medium-light\ntitle=Medium light\n\n'
printf 'option=medium\ntitle=Medium\n\noption=medium-dark\ntitle=Medium dark\n\noption=dark\ntitle=Dark\n\n'
printf 'items=a\nclass=grid grid-cols-7\n\n'
printf 'button=open\nparent=a\ntitle=Copy\n\n'
printf 'button=paste\nparent=a\ntitle=Paste\nshortcut=cmd+return\n\n'
printf 'button=next-tone\nparent=a\ntitle=Next skin tone\nshortcut=cmd+t\nscope=spot\nclose=false\n\n'
for glyph in '😀:grinning face' '😂:face with tears of joy' '😍:smiling face with heart-eyes' '🥳:partying face' '😎:smiling face with sunglasses' '🤔:thinking face' '😴:sleeping face' \
  '👍:thumbs up' '👋:waving hand' '🙏:folded hands' '🎉:party popper' '❤️:red heart' '🔥:fire' '✨:sparkles'; do
  printf 'item=%s\nparent=a\nclass=sr-only\ntitle=%s\nicon=%s\n\n' "${glyph%%:*}" "${glyph#*:}" "${glyph%%:*}"
done
