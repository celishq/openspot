#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
catalog="$root/app/Shell/Assets.xcassets"

mkdir -p "$catalog"
printf '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' > "$catalog/Contents.json"

render() {
  set_dir="$catalog/$2.appiconset"
  rm -rf "$set_dir"
  mkdir -p "$set_dir"
  images=""
  for slot in 16:1 16:2 32:1 32:2 128:1 128:2 256:1 256:2 512:1 512:2; do
    points=${slot%:*}
    scale=${slot#*:}
    pixels=$((points * scale))
    file="icon_${points}x${points}@${scale}x.png"
    rsvg-convert -w "$pixels" -h "$pixels" "$root/app/Icon/$1" -o "$set_dir/$file"
    images="$images    {\n      \"filename\" : \"$file\",\n      \"idiom\" : \"mac\",\n      \"scale\" : \"${scale}x\",\n      \"size\" : \"${points}x${points}\"\n    },\n"
  done
  printf '{\n  "images" : [\n%b  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' \
    "$(printf '%s' "$images" | sed '$ s/},\\n$/}\\n/')" > "$set_dir/Contents.json"
}

render openspot.svg AppIcon
render openspot-nightly.svg AppIconNightly
