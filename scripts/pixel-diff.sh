#!/bin/sh
set -e
cd "$(dirname "$0")/.."
work=$PWD/.temp/pixels
usage="Usage: sh scripts/pixel-diff.sh shoot <name> | compare <name> <name>"

spot() {
  mkdir -p "$work/state/spots/$1.spot"
  printf 'title = "%s"\nicon = "%s"\n' "$2" "$3" > "$work/state/spots/$1.spot/spot.toml"
  [ -z "$4" ] || printf 'on = ["%s"]\n' "$4" >> "$work/state/spots/$1.spot/spot.toml"
  cat > "$work/state/spots/$1.spot/$1.sh"
  chmod +x "$work/state/spots/$1.spot/$1.sh"
}

fixtures() {
  rm -rf "$work/state"
  mkdir -p "$work/state/spots" "$work/state/config" "$work/state/core"
  cp -R spots/openspot.spot "$work/state/core/"
  spot rows Rows list.bullet '' <<'SPOT'
#!/bin/sh
printf "text=a\ntitle=Alpha\ndetail=The first row\nicon=star\n\ntext=b\ntitle=Beta\ndetail=The second row\nicon=heart\nvalue=true\n\ntext=c\ntitle=Gamma\nicon=bolt\ntone=good\nshortcut=⌃⌥K\n\ntext=d\ntitle=Delta\nicon=leaf\n"
SPOT
  spot parts Parts square.grid.2x2 '' <<'SPOT'
#!/bin/sh
printf "%s\n" "frame=" "grid=n n g g" "grid=t t t t" "grid=s s s s" "grid=f f f f" "grid=- - - -" "grid=b b c c" "grid.large=n n g g" "grid.large=t t t t" "" \
  "number=n" "title=Cups today" "value=3" "" "number=g" "title=Load" "value=42" "max=100" "unit=%" "" "number=t" "title=Disk" "detail=Half full" "value=50" "max=100" "unit=%" "tone=warn" "" \
  "switch=s" "title=Focus" "detail=Until 18:00" "value=true" "" "field=f" "type=slider" "title=Volume" "value=40" "" \
  "button=b" "title=Go" "look=strong" "" "choice=c" "title=Mode" "value=x" "" "option=x" "title=One" "" "option=y" "title=Two"
SPOT
  spot asks Asks plus.circle '' <<'SPOT'
#!/bin/sh
if [ "$1" = add ]; then
  printf "%s\n" "frame=" "title=Add a thing" "" "field=name" "title=Name" "placeholder=A name" "" "field=note" "title=Note" "type=multiline" "" "switch=on" "title=Keep it" "value=true"
  exit 0
fi
printf "button=add\ntitle=Add\nform=true\nscope=spot\n\ntext=a\ntitle=One\n\ntext=b\ntitle=Two\n"
SPOT
  spot cups Coffee cup.and.saucer.fill panel.open <<'SPOT'
#!/bin/sh
printf "number=cups\ntitle=Cups today\nvalue=3\n"
SPOT
  spot focus Focus moon.fill panel.open <<'SPOT'
#!/bin/sh
printf "switch=focus\ntitle=Focus\ndetail=Until 18:00\nvalue=true\n"
SPOT
  spot load Load cpu panel.open <<'SPOT'
#!/bin/sh
printf "frame=\ngrid.small=ring\ngrid.wide=load ring\ngrid.large=load load\ngrid.large=ring cups\n\nnumber=load\ntitle=Load\nvalue=20\nvalue=50\nvalue=35\nvalue=80\nvalue=60\nmax=100\nunit=%%\n\nnumber=ring\ntitle=Disk\nvalue=60\nmax=100\nunit=%%\n\nnumber=cups\ntitle=Cups\nvalue=3\nunit=cups\ndisplay=3 cups\n"
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
    "$app/Contents/MacOS/Openspot" --spots "$work/state/spots" --config "$work/state/config" --core "$work/state/core" "$@"
  }
  run check spots >/dev/null || true
  for look in dark light; do
    run --probe "$out/probe.txt" --probe-action pixels --shots "$out/$look" --seen --glass off --appearance "$look" \
      >"$out/run-$look.log" 2>&1
    stop
  done
  mkdir -p "$out/picture"
  sh "$work/state/spots/parts.spot/parts.sh" | run render sheet "$out/picture/parts.png"
  for size in small wide large; do
    sh "$work/state/spots/load.spot/load.sh" | run render card "$size" "$out/picture/load-$size.png"
  done
  run render panel "$out/picture/panel.png"
  find "$out" -name '*.png' | sort
}

case "$1" in
  shoot) [ -n "$2" ] || { echo "$usage" >&2; exit 2; }; shoot "$2" ;;
  compare) [ -n "$3" ] || { echo "$usage" >&2; exit 2; }; rm -rf "$work/marks"; swift scripts/pixel-diff.swift "$work/$2" "$work/$3" "$work/marks" ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
