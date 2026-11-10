#!/bin/sh
# title=Doom
# icon=gamecontroller
# detail=Play the first episode of Doom
# read=panel
# size=square
engine_commit=e257a09527062bfb986b6e5e0780839b6cbd5b71
engine_sha=26f8f60daa6c6e4d3c01e5eac9fb700d592dede803d13ac848154ff356b2a2e7
engine_url=https://github.com/ozkl/doomgeneric/archive/$engine_commit.tar.gz
engine_size=3090826
wad_sha=1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771
wad_size=1366368
wad_urls='http://deb.debian.org/debian/pool/non-free/d/doom-wad-shareware/doom-wad-shareware_1.9.fixed-5_all.deb
https://snapshot.debian.org/file/732562ea15f0a6623611bdb739a03af72d8dbaf1'

data=$OPENSPOT_DATA

if [ "$1" = read ]; then
  newest=$(ls -t "$data"/screens/*.png 2>/dev/null | head -n 1)
  [ -n "$newest" ] && printf 'grid.small=shot\n\npicture=shot\nicon=%s\n' "$newest"
  exit 0
fi
[ "$1" = run ] || exit 0

layer=$(cd "$(dirname "$0")" && pwd)/doomgeneric_mac.m
source=$data/doomgeneric-$engine_commit
wad=$data/doom1.wad
engine=$data/doom
temp=$(mktemp -d "${TMPDIR:-/tmp}/doom.XXXXXX") || exit 1
job=
trap 'kill $job 2>/dev/null; rm -rf "$temp"' EXIT
trap 'exit 143' TERM

stage() {
  printf 'gauge=progress\ntitle=%s\n' "$1"
  [ -n "$2" ] && printf 'detail=%s\n' "$2"
  printf '%s\n' ---
}

fail() {
  echo "$1" >&2
  exit 1
}

progress() {
  share=$(awk -v part="$2" -v all="$3" 'BEGIN { v = all > 0 ? part / all : 0; if (v > 1) v = 1; printf "%.2f %d", v, v * 100 + 0.5 }')
  [ "$1 $share" = "$shown" ] && return
  shown="$1 $share"
  printf 'gauge=progress\ntitle=%s\nvalue=%s\ndetail=%s%%\n' "$1" "${share% *}" "${share#* }"
  printf '%s\n' ---
}

watch() {
  job=$!
  while kill -0 "$job" 2>/dev/null; do
    progress "$1" "$($2)" "$3"
    sleep 0.25
  done
  wait "$job"
  ended=$?
  job=
  [ "$ended" -eq 0 ] && progress "$1" "$3" "$3"
  return "$ended"
}

download() {
  curl -fsSL -o "$2" "$1" &
  file=$2
  watch "$4" downloaded "$3"
}

downloaded() {
  stat -f %z "$file" 2>/dev/null || echo 0
}

compiled() {
  ls "$temp/objects" | grep -c '\.o$'
}

sha() {
  shasum -a 256 "$1" | cut -d ' ' -f 1
}

if [ ! -x "$engine" ] || [ "$layer" -nt "$engine" ]; then
  if [ ! -d "$source" ]; then
    download "$engine_url" "$temp/engine.tar.gz" "$engine_size" 'Downloading the engine' || fail 'Openspot cannot download the Doom engine. Check the connection to the internet, then press Doom again.'
    [ "$(sha "$temp/engine.tar.gz")" = "$engine_sha" ] || fail 'The downloaded Doom engine is not the expected file, so Openspot did not build it. Press Doom again to download it again.'
    mkdir "$temp/engine"
    tar -xzf "$temp/engine.tar.gz" -C "$temp/engine" && mv "$temp/engine/doomgeneric-$engine_commit/doomgeneric" "$source"
  fi
  built='Openspot cannot build the Doom engine. Install the Command Line Tools with `xcode-select --install`, then press Doom again.'
  mkdir "$temp/objects"
  sed -n 's/^SRC_DOOM = //p' "$source/Makefile" | tr ' ' '\n' | sed -n 's/\.o$//p' | grep -vx doomgeneric_xlib > "$temp/files"
  xargs -P "$(getconf _NPROCESSORS_ONLN)" -I {} clang -c -O2 -w -DNORMALUNIX -D_DEFAULT_SOURCE -I "$source" "$source/{}.c" -o "$temp/objects/{}.o" < "$temp/files" 2>/dev/null &
  watch 'Building the engine' compiled "$(wc -l < "$temp/files")" || fail "$built"
  clang -O2 -w -fobjc-arc -I "$source" "$layer" "$temp"/objects/*.o -framework Cocoa -framework QuartzCore -o "$temp/doom" 2>/dev/null || fail "$built"
  mv "$temp/doom" "$engine"
fi

if [ ! -f "$wad" ]; then
  got=
  for url in $wad_urls; do
    rm -f "$temp/wad.deb"
    download "$url" "$temp/wad.deb" "$wad_size" 'Downloading Doom' && { got=1; break; }
  done
  [ -n "$got" ] || fail 'Openspot cannot download Doom. Check the connection to the internet, then press Doom again.'
  tar -xOf "$temp/wad.deb" data.tar.xz 2>/dev/null | tar -xJOf - ./usr/share/games/doom/doom1.wad > "$temp/doom1.wad" 2>/dev/null
  [ "$(sha "$temp/doom1.wad")" = "$wad_sha" ] || fail 'The downloaded Doom is not the expected file, so Openspot did not keep it. Press Doom again to download it again.'
  mv "$temp/doom1.wad" "$wad"
fi

cd "$data" || exit 1
[ -d screens ] || "$engine" -iwad "$wad" -screen > /dev/null 2>&1
stage 'Playing' 'Press to quit'
rm -rf "$temp"
trap - EXIT TERM
"$engine" -iwad "$wad" > "$data/doom.log"
