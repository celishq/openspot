#!/bin/sh
# title=Doom
# icon=gamecontroller
# detail=Play the first episode of Doom
engine_commit=e257a09527062bfb986b6e5e0780839b6cbd5b71
engine_sha=26f8f60daa6c6e4d3c01e5eac9fb700d592dede803d13ac848154ff356b2a2e7
engine_url=https://github.com/ozkl/doomgeneric/archive/$engine_commit.tar.gz
wad_sha=1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771
wad_urls='http://deb.debian.org/debian/pool/non-free/d/doom-wad-shareware/doom-wad-shareware_1.9.fixed-5_all.deb
https://snapshot.debian.org/file/732562ea15f0a6623611bdb739a03af72d8dbaf1'

[ "$1" = run ] || exit 0

data=$OPENSPOT_DATA
layer=$(cd "$(dirname "$0")" && pwd)/doomgeneric_mac.m
source=$data/doomgeneric-$engine_commit
wad=$data/doom1.wad
engine=$data/doom
temp=$(mktemp -d "${TMPDIR:-/tmp}/doom.XXXXXX") || exit 1
trap 'rm -rf "$temp"' EXIT
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

sha() {
  shasum -a 256 "$1" | cut -d ' ' -f 1
}

if [ ! -x "$engine" ] || [ "$layer" -nt "$engine" ]; then
  if [ ! -d "$source" ]; then
    stage 'Downloading the engine'
    curl -fsSL -o "$temp/engine.tar.gz" "$engine_url" || fail 'Openspot cannot download the Doom engine. Check the connection to the internet, then press Doom again.'
    [ "$(sha "$temp/engine.tar.gz")" = "$engine_sha" ] || fail 'The downloaded Doom engine is not the expected file, so Openspot did not build it. Press Doom again to download it again.'
    mkdir "$temp/engine"
    tar -xzf "$temp/engine.tar.gz" -C "$temp/engine" && mv "$temp/engine/doomgeneric-$engine_commit/doomgeneric" "$source"
  fi
  stage 'Building the engine'
  built='Openspot cannot build the Doom engine. Install the Command Line Tools with `xcode-select --install`, then press Doom again.'
  mkdir "$temp/objects"
  sed -n 's/^SRC_DOOM = //p' "$source/Makefile" | tr ' ' '\n' | sed -n 's/\.o$//p' | grep -vx doomgeneric_xlib |
    xargs -P "$(getconf _NPROCESSORS_ONLN)" -I {} clang -c -O2 -w -DNORMALUNIX -D_DEFAULT_SOURCE -I "$source" "$source/{}.c" -o "$temp/objects/{}.o" 2>/dev/null ||
    fail "$built"
  clang -O2 -w -fobjc-arc -I "$source" "$layer" "$temp"/objects/*.o -framework Cocoa -framework QuartzCore -o "$temp/doom" 2>/dev/null || fail "$built"
  mv "$temp/doom" "$engine"
fi

if [ ! -f "$wad" ]; then
  stage 'Downloading Doom'
  got=
  for url in $wad_urls; do
    rm -f "$temp/wad.deb"
    curl -fsSL -o "$temp/wad.deb" "$url" && { got=1; break; }
  done
  [ -n "$got" ] || fail 'Openspot cannot download Doom. Check the connection to the internet, then press Doom again.'
  tar -xOf "$temp/wad.deb" data.tar.xz 2>/dev/null | tar -xJOf - ./usr/share/games/doom/doom1.wad > "$temp/doom1.wad" 2>/dev/null
  [ "$(sha "$temp/doom1.wad")" = "$wad_sha" ] || fail 'The downloaded Doom is not the expected file, so Openspot did not keep it. Press Doom again to download it again.'
  mv "$temp/doom1.wad" "$wad"
fi

stage 'Playing' 'Press to quit'
rm -rf "$temp"
trap - EXIT TERM
cd "$data" || exit 1
"$engine" -iwad "$wad" > "$data/doom.log"
