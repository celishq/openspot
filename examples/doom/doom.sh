#!/bin/sh
# title=Doom
# icon=gamecontroller
# detail=Play the first episode of Doom
# read=panel
# size=square
# view=screen.swift
engine_commit=e257a09527062bfb986b6e5e0780839b6cbd5b71
engine_sha=26f8f60daa6c6e4d3c01e5eac9fb700d592dede803d13ac848154ff356b2a2e7
engine_size=3090826
engine_urls=https://github.com/ozkl/doomgeneric/archive/$engine_commit.tar.gz
game_sha=1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771
game_size=1366368
game_urls='http://deb.debian.org/debian/pool/non-free/d/doom-wad-shareware/doom-wad-shareware_1.9.fixed-5_all.deb
https://snapshot.debian.org/file/732562ea15f0a6623611bdb739a03af72d8dbaf1'

data=$OPENSPOT_DATA
engine=$data/doom-$engine_commit
source=$data/doomgeneric-$engine_commit
game=$data/doom1.wad
layer=$(cd "$(dirname "$0")" && pwd)/doomgeneric_mac.m

card() {
  newest=$(ls -t "$data"/screens/*.png 2>/dev/null | head -n 1)
  [ -n "$newest" ] && printf 'grid=screen\ngrid=play\n\nview=screen\npicture=%s\n\nbutton=play\ntitle=Play\nshortcut=return\n' "$newest"
}

fail() {
  echo "$1" >&2
  exit 1
}

progress() {
  share=$(awk -v part="$2" -v all="$3" 'BEGIN { v = all > 0 ? part / all : 0; if (v > 1) v = 1; printf "%.2f %d", v, v * 100 + 0.5 }')
  [ "$1 $share" = "$shown" ] && return
  shown="$1 $share"
  printf 'gauge=progress\ntitle=%s\nvalue=%s\ndetail=%s%%\n---\n' "$1" "${share% *}" "${share#* }"
}

watch() {
  job=$!
  while kill -0 "$job" 2>/dev/null; do
    progress "$1" "$("$3" "$4")" "$2"
    sleep 0.25
  done
  wait "$job"
  ended=$?
  job=
  [ "$ended" -eq 0 ] && progress "$1" "$2" "$2"
  return "$ended"
}

size() {
  stat -f %z "$1" 2>/dev/null || echo 0
}

objects() {
  ls "$1" | grep -c '\.o$'
}

fetch() {
  for url in $1; do
    rm -f "$2"
    curl -fsSL -o "$2" "$url" &
    watch "Downloading $4" "$3" size "$2" && return
  done
  fail "Openspot cannot download $4. Check the connection to the internet, then press Doom again."
}

check() {
  [ "$(shasum -a 256 "$1" | cut -d ' ' -f 1)" = "$2" ] ||
    fail "The download of $3 is not the expected file, so Openspot did not keep it. Press Doom again to download it again."
}

build_engine() {
  if [ ! -d "$source" ]; then
    fetch "$engine_urls" "$temp/engine.tar.gz" "$engine_size" 'the Doom engine'
    check "$temp/engine.tar.gz" "$engine_sha" 'the Doom engine'
    mkdir "$temp/engine"
    tar -xzf "$temp/engine.tar.gz" -C "$temp/engine" && mv "$temp/engine/doomgeneric-$engine_commit/doomgeneric" "$source"
  fi
  unbuilt='Openspot cannot build the Doom engine. Install the Command Line Tools with `xcode-select --install`, then press Doom again.'
  mkdir "$temp/objects"
  sed -n 's/^SRC_DOOM = //p' "$source/Makefile" | tr ' ' '\n' | sed -n 's/\.o$//p' | grep -vx doomgeneric_xlib > "$temp/files"
  xargs -P "$(getconf _NPROCESSORS_ONLN)" -I {} clang -c -O2 -w -DNORMALUNIX -D_DEFAULT_SOURCE -I "$source" "$source/{}.c" -o "$temp/objects/{}.o" < "$temp/files" 2>/dev/null &
  watch 'Building the Doom engine' "$(wc -l < "$temp/files")" objects "$temp/objects" || fail "$unbuilt"
  clang -O2 -w -fobjc-arc -I "$source" "$layer" "$temp"/objects/*.o -framework Cocoa -framework QuartzCore -o "$temp/doom" 2>/dev/null || fail "$unbuilt"
  mv "$temp/doom" "$engine"
}

get_game() {
  fetch "$game_urls" "$temp/game.deb" "$game_size" 'Doom'
  tar -xOf "$temp/game.deb" data.tar.xz 2>/dev/null | tar -xJOf - ./usr/share/games/doom/doom1.wad > "$temp/doom1.wad" 2>/dev/null
  check "$temp/doom1.wad" "$game_sha" 'Doom'
  mv "$temp/doom1.wad" "$game"
}

play() {
  printf 'gauge=progress\ntitle=Playing\ndetail=Press to quit\n---\n'
  rm -rf "$temp"
  trap - EXIT TERM
  "$engine" -iwad "$game" > doom.log
}

case "$1" in
  read) card; exit 0 ;;
  run | play) ;;
  *) exit 0 ;;
esac
temp=$(mktemp -d "${TMPDIR:-/tmp}/doom.XXXXXX") || exit 1
job=
trap 'kill $job 2>/dev/null; rm -rf "$temp"' EXIT
trap 'exit 143' TERM

[ -x "$engine" ] && [ ! "$layer" -nt "$engine" ] || build_engine
[ -f "$game" ] || get_game
cd "$data" || exit 1
[ -d screens ] || "$engine" -iwad "$game" -screen > /dev/null 2>&1
play
