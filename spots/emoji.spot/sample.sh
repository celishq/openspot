#!/bin/sh
printf 'grid=tone tone tone tone tone tone tone\ngrid=a a a a a a a\n\nrepeat=a\ngrid=a b c d e f g\n\n'
printf 'button=open\ntitle=Copy\n\n'
printf 'button=paste\ntitle=Paste\nshortcut=cmd+return\nclose=true\n\n'
printf 'button=next-tone\ntitle=Next skin tone\nshortcut=cmd+t\nscope=spot\n\n'
printf 'choice=tone\ntitle=Skin tone\nvalue=none\n\n'
printf 'option=none\ntitle=Yellow\n\noption=light\ntitle=Light\n\noption=medium-light\ntitle=Medium light\n\n'
printf 'option=medium\ntitle=Medium\n\noption=medium-dark\ntitle=Medium dark\n\noption=dark\ntitle=Dark\n\n'
for glyph in '😀:grinning face' '😂:face with tears of joy' '😍:smiling face with heart-eyes' '🥳:partying face' '😎:smiling face with sunglasses' '🤔:thinking face' '😴:sleeping face' \
  '👍:thumbs up' '👋:waving hand' '🙏:folded hands' '🎉:party popper' '❤️:red heart' '🔥:fire' '✨:sparkles'; do
  printf 'row=%s\ntitle=%s\nicon=%s\n\n' "${glyph%%:*}" "${glyph#*:}" "${glyph%%:*}"
done
