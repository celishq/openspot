#!/bin/sh
# The form that the Look row of Confetti's Settings opens, with the looks that ship with it.
printf 'frame=\ntitle=Look\n\nchoice=look\ntitle=Look\nvalue=colorful\n'
for file in "$(dirname "$0")"/looks/*.look; do
  id=${file##*/}
  printf '\noption=%s\ntitle=%s\n' "${id%.look}" "$(sed -n 's/^title=//p' "$file" | head -n 1)"
done
