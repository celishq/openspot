#!/bin/sh
# Draws the image under each example of GUIDE.md. A line ![...](docs/images/<name>.png) after a sh or js example draws
# that example as an installed spot: its sheet, or its card when a line <!-- card: <size> --> comes right before the image.
# A line <!-- draw: <command> --> right before the image draws what that command prints instead of a read, with the
# example's header and $EXAMPLE as the path of the example. Each spot that a card of other spots names gets a stub with a
# sample value. A copy of the example goes beside the image as <name>.example, which GuideImageTests compare with the
# guide. It also draws the panel of the sample spots in docs/sample, the image of the README, as docs/images/panel.png.
# OPENSPOT_APP names the app to draw with.
set -e
cd "$(dirname "$0")/.."
app=${OPENSPOT_APP:-.temp/dd/Build/Products/Debug/Openspot.app/Contents/MacOS/Openspot}
work=$PWD/.temp/docs-images
rm -rf "$work"
mkdir -p "$work/plugins" "$work/config" "$work/core" "$work/examples" docs/images
awk -v out="$work/examples" '
  /^```(sh|js)$/ { inside = 1; text = ""; kind = substr($0, 4); next }
  inside && /^```$/ { inside = 0; last = text; lastkind = kind; draw = ""; card = ""; next }
  inside { text = text $0 "\n"; next }
  /^<!-- draw: .* -->$/ { draw = $0; sub(/^<!-- draw: /, "", draw); sub(/ -->$/, "", draw); next }
  /^<!-- card: [a-z]+ -->$/ { card = $3; next }
  /^!\[[^]]*\]\(docs\/images\/[^)]*\.png\)$/ {
    name = $0; sub(/.*docs\/images\//, "", name); sub(/\.png\)$/, "", name)
    printf "%s", last > (out "/" name ".example"); close(out "/" name ".example")
    printf "%s", lastkind > (out "/" name ".kind"); close(out "/" name ".kind")
    printf "%s", draw > (out "/" name ".draw"); close(out "/" name ".draw")
    printf "%s", card > (out "/" name ".card"); close(out "/" name ".card")
    last = ""; draw = ""; card = ""
  }
' GUIDE.md
stub() {
  case "$1" in
    battery) title=Battery value="84%%" ;;
    cpu) title=CPU value="12%%" ;;
    memory) title=Memory value="61%%" ;;
    *) title=$1 value="42" ;;
  esac
  printf '#!/bin/sh\n# title=%s\n# on=clock.60\nprintf '"'"'text=v\\ntitle=%s\\n'"'"'\n' "$title" "$value" > "$work/plugins/$1.sh"
  chmod +x "$work/plugins/$1.sh"
}
for example in "$work"/examples/*.example; do
  name=$(basename "$example" .example)
  kind=$(cat "$work/examples/$name.kind")
  draw=$(cat "$work/examples/$name.draw")
  card=$(cat "$work/examples/$name.card")
  rm -rf "$work"/plugins/*
  if [ -n "$draw" ]; then
    cp "$example" "$work/plugins/$name.source"
    {
      printf '#!/bin/sh\n'
      sed '1{/^#!/d;}' "$example" | sed -E -n '/^(#|\/\/)/!q; p' | sed 's|^//|#|'
      printf 'EXAMPLE="%s"\n%s\n' "$work/plugins/$name.source" "$draw"
    } > "$work/plugins/$name.sh"
    chmod +x "$work/plugins/$name.sh"
  else
    cp "$example" "$work/plugins/$name.$kind"
    [ "$kind" = js ] || chmod +x "$work/plugins/$name.$kind"
  fi
  for word in $(sed -n -e 's/^# grid\.[a-z]*=//p' -e 's/^# to=//p' "$example"); do
    [ -f "$work/plugins/$word.sh" ] || stub "$word"
  done
  size=""
  [ -n "$card" ] && size="--card $card"
  OPENSPOT_PLUGINS="$work/plugins" OPENSPOT_CONFIG="$work/config" OPENSPOT_CORE="$work/core" \
    "$app" render --spot "$name" $size "docs/images/$name.png"
  cp "$example" "docs/images/$name.example"
  echo "docs/images/$name.png"
done
rm -rf "$work/config"/*
cp docs/sample/config.toml "$work/config/config.toml"
OPENSPOT_PLUGINS="$PWD/docs/sample" OPENSPOT_CONFIG="$work/config" OPENSPOT_CORE="$work/core" \
  "$app" render --panel docs/images/panel.png
echo docs/images/panel.png
