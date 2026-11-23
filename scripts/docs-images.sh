#!/bin/sh
set -e
cd "$(dirname "$0")/.."
app=${OPENSPOT_APP:-.temp/dd/Build/Products/Debug/Openspot.app/Contents/MacOS/Openspot}
work=$PWD/.temp/docs-images
echo "This shows each picture in the middle of the main screen and takes the keyboard focus for about a second per picture. A key typed then is lost."
rm -rf "$work"
mkdir -p "$work/spots" "$work/config" "$work/core" "$work/examples" docs/images
awk -v out="$work/examples" '
  /^```(toml|sh|js|swift)$/ { inside = 1; text = ""; kind = substr($0, 4); next }
  inside && /^```$/ {
    inside = 0
    if (kind == "toml") { toml = text; next }
    if (kind != "js" && text !~ /^#!/) { more[++extras] = text; toml = ""; next }
    last = text; lastkind = kind; lasttoml = toml; toml = ""; draw = ""; card = ""; extras = 0; next
  }
  inside { text = text $0 "\n"; next }
  /^<!-- draw: .* -->$/ { draw = $0; sub(/^<!-- draw: /, "", draw); sub(/ -->$/, "", draw); next }
  /^<!-- card: [a-z]+ -->$/ { card = $3; next }
  /^!\[[^]]*\]\(docs\/images\/[^)]*\.png\)$/ {
    name = $0; sub(/.*docs\/images\//, "", name); sub(/\.png\)$/, "", name)
    printf "%s", last > (out "/" name ".example"); close(out "/" name ".example")
    printf "%s", lasttoml > (out "/" name ".toml"); close(out "/" name ".toml")
    printf "%s", lastkind > (out "/" name ".kind"); close(out "/" name ".kind")
    printf "%s", draw > (out "/" name ".draw"); close(out "/" name ".draw")
    printf "%s", card > (out "/" name ".card"); close(out "/" name ".card")
    for (i = 1; i <= extras; i++) { printf "%s", more[i] > (out "/" name ".more." i); close(out "/" name ".more." i) }
    last = ""; lasttoml = ""; draw = ""; card = ""; extras = 0
  }
' GUIDE.md
stub() {
  case "$1" in
    battery) title=Battery value="84%%" ;;
    cpu) title=CPU value="12%%" ;;
    memory) title=Memory value="61%%" ;;
    *) title=$1 value="42" ;;
  esac
  mkdir -p "$work/spots/$1.spot"
  printf 'title = "%s"\n\n[on]\nevery = 60\n' "$title" > "$work/spots/$1.spot/spot.toml"
  printf '#!/bin/sh\nprintf '"'"'item=v\\ntitle=%s\\n'"'"'\n' "$value" > "$work/spots/$1.spot/$1.sh"
  chmod +x "$work/spots/$1.spot/$1.sh"
}
for example in "$work"/examples/*.example; do
  name=$(basename "$example" .example)
  kind=$(cat "$work/examples/$name.kind")
  draw=$(cat "$work/examples/$name.draw")
  card=$(cat "$work/examples/$name.card")
  rm -rf "$work"/spots/*
  spot="$work/spots/$name.spot"
  mkdir -p "$spot"
  manifest="$work/examples/$name.toml"
  cp "$manifest" "$spot/spot.toml"
  if [ -n "$draw" ]; then
    cp "$example" "$work/$name.source"
    printf '#!/bin/sh\nEXAMPLE="%s"\n%s\n' "$work/$name.source" "$draw" > "$spot/$name.sh"
    chmod +x "$spot/$name.sh"
  else
    cp "$example" "$spot/$name.$kind"
    [ "$kind" = js ] || chmod +x "$spot/$name.$kind"
  fi
  number=0
  for file in $(sed -n -E 's/^(view|views|source) = //p' "$manifest" | tr -d '[]",'); do
    number=$((number + 1))
    cp "$work/examples/$name.more.$number" "$spot/$file"
  done
  for word in $(sed -n -E -e 's/^"grid\.[a-z]+" = //p' -e 's/^to = //p' "$manifest" | tr -d '[]",'); do
    [ -d "$work/spots/$word.spot" ] || stub "$word"
  done
  size=""
  [ -n "$card" ] && size="--card $card"
  "$app" --picture-on-screen --spots "$work/spots" --config "$work/config" --core "$work/core" \
    render spot "$name" $size "docs/images/$name.png"
  cp "$example" "docs/images/$name.example"
  cp "$manifest" "docs/images/$name.toml"
  echo "docs/images/$name.png"
done
rm -rf "$work/config"/* "$work/spots"/*
cp -R docs/sample/. "$work/spots/"
rm "$work/spots/config.toml"
for spot in system battery cpu memory devices; do cp -R "spots/$spot.spot" "$work/spots/"; done
cp docs/sample/config.toml "$work/config/config.toml"
"$app" --spots "$work/spots" --config "$work/config" --core "$work/core" check spots >/dev/null
"$app" --picture-on-screen --spots "$work/spots" --config "$work/config" --core "$work/core" \
  render panel docs/images/panel.png
echo docs/images/panel.png
