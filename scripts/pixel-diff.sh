#!/bin/sh
set -e
cd "$(dirname "$0")/.."
work=$PWD/.temp/pixels
usage="Usage: sh scripts/pixel-diff.sh shoot <name> | compare <name> <name>"

spot() {
  mkdir -p "$work/state/spots/$1.spot"
  cat > "$work/state/spots/$1.spot/$1.sh"
  chmod +x "$work/state/spots/$1.spot/$1.sh"
}

fixtures() {
  rm -rf "$work/state"
  mkdir -p "$work/state/spots" "$work/state/config" "$work/state/core"
  cp -R spots/openspot.spot "$work/state/core/"
  spot rows <<'SPOT'
#!/bin/sh
# title=Rows
# icon=list.bullet
# on=sheet.open
printf "row=a\ntitle=Alpha\ndetail=The first row\nicon=star\n\nrow=b\ntitle=Beta\ndetail=The second row\nicon=heart\nvalue=true\n\nrow=c\ntitle=Gamma\nicon=bolt\ntone=good\nshortcut=⌃⌥K\n\nrow=d\ntitle=Delta\nicon=leaf\n"
SPOT
  spot parts <<'SPOT'
#!/bin/sh
# title=Parts
# icon=square.grid.2x2
# on=sheet.open
printf "%s\n" "grid=n n g g" "grid=t t t t" "grid=s s s s" "grid=f f f f" "grid=- - - -" "grid=b b c c" "grid.large=n n g g" "grid.large=t t t t" "" \
  "number=n" "title=Cups today" "value=3" "" "graph=g" "title=Load" "value=0.42" "" "text=t" "title=Disk" "detail=Half full" "value=0.5" "tone=warn" "" \
  "switch=s" "title=Focus" "detail=Until 18:00" "value=true" "" "field=f" "type=slider" "title=Volume" "value=40" "" \
  "button=b" "title=Go" "look=strong" "" "choice=c" "title=Mode" "value=x" "" "option=x" "title=One" "" "option=y" "title=Two"
SPOT
  spot asks <<'SPOT'
#!/bin/sh
# title=Asks
# icon=plus.circle
# on=sheet.open
if [ "$1" = add ]; then
  printf "%s\n" "title=Add a thing" "" "field=name" "title=Name" "placeholder=A name" "" "field=note" "title=Note" "type=multiline" "" "switch=on" "title=Keep it" "value=true"
  exit 0
fi
printf "button=add\ntitle=Add\nform=true\nscope=spot\n\nrow=a\ntitle=One\n\nrow=b\ntitle=Two\n"
SPOT
  spot cups <<'SPOT'
#!/bin/sh
# title=Coffee
# icon=cup.and.saucer.fill
# on=panel.open
printf "number=cups\ntitle=Cups today\nvalue=3\n"
SPOT
  spot focus <<'SPOT'
#!/bin/sh
# title=Focus
# icon=moon.fill
# on=panel.open
printf "switch=focus\ntitle=Focus\ndetail=Until 18:00\nvalue=true\n"
SPOT
  spot load <<'SPOT'
#!/bin/sh
# title=Load
# icon=cpu
# on=panel.open
printf "grid.small=ring\ngrid.wide=load ring\ngrid.large=load load\ngrid.large=ring cups\n\ngraph=load\ntitle=Load\nvalue=0.2\nvalue=0.5\nvalue=0.35\nvalue=0.8\nvalue=0.6\nmax=1\n\ngraph=ring\ntitle=Disk\nvalue=0.6\n\nnumber=cups\ntitle=Cups\nvalue=3\nunit=cups\ndisplay=3 cups\n"
SPOT
  {
    for id in rows asks cups focus; do printf '[[spots]]\nid = "%s"\nsize = "small"\ngrid = true\n\n' "$id"; done
    printf '[[spots]]\nid = "parts"\nsize = "large"\ngrid = true\n\n[[spots]]\nid = "load"\nsize = "wide"\ngrid = true\n'
  } > "$work/state/config/config.toml"
}

stop() {
  quiet=0
  while [ "$quiet" -lt 20 ]; do
    if pgrep -f "$work/" >/dev/null; then
      pkill -f "$work/" || true
      quiet=0
    else
      quiet=$((quiet + 1))
    fi
    sleep 0.1
  done
}

shoot() {
  out=$work/$1
  stop
  trap stop EXIT
  rm -rf "$out"
  mkdir -p "$out"
  (cd app && xcodegen generate >/dev/null)
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project app/Openspot.xcodeproj -scheme Openspot \
    -configuration Release SWIFT_ACTIVE_COMPILATION_CONDITIONS=OPENSPOT_TOOLS -derivedDataPath "$work/build" build -quiet >"$out/build.log" 2>&1 \
    || { grep error: "$out/build.log"; exit 1; }
  app=$work/build/Build/Products/Release/Openspot.app
  codesign --force --deep -s - "$app" 2>/dev/null
  fixtures
  run() {
    OPENSPOT_SPOTS="$work/state/spots" OPENSPOT_CONFIG="$work/state/config" OPENSPOT_CORE="$work/state/core" "$@"
  }
  run "$app/Contents/MacOS/Openspot" check >/dev/null || true
  for look in dark light; do
    run env OPENSPOT_PROBE="$out/probe.txt" OPENSPOT_ACTION=pixels OPENSPOT_SHOTS="$out/$look" OPENSPOT_SEEN=1 OPENSPOT_GLASS=off OPENSPOT_APPEARANCE="$look" \
      "$app/Contents/MacOS/Openspot" >"$out/run-$look.log" 2>&1
    stop
  done
  mkdir -p "$out/picture"
  sh "$work/state/spots/parts.spot/parts.sh" | run "$app/Contents/MacOS/Openspot" render "$out/picture/parts.png"
  for size in small wide large; do
    sh "$work/state/spots/load.spot/load.sh" | run "$app/Contents/MacOS/Openspot" render --card "$size" "$out/picture/load-$size.png"
  done
  run "$app/Contents/MacOS/Openspot" render --panel "$out/picture/panel.png"
  find "$out" -name '*.png' | sort
}

case "$1" in
  shoot) [ -n "$2" ] || { echo "$usage" >&2; exit 2; }; shoot "$2" ;;
  compare) [ -n "$3" ] || { echo "$usage" >&2; exit 2; }; rm -rf "$work/marks"; swift scripts/pixel-diff.swift "$work/$2" "$work/$3" "$work/marks" ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
