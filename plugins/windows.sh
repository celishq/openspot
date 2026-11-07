#!/bin/sh
# name=Windows
# symbol=macwindow
# subtitle=Give each command a key in Settings
# grid=false
# command=full:Full screen
# command=center:Centre
# command=left:Left side
# command=right:Right side
script='
const margin = 20;

function near(first, second) {
  return Math.abs(first - second) <= margin;
}

function frame(slot, area, window) {
  if (slot === "full") return area;
  if (slot === "center") {
    const w = Math.round(area.w * 0.65);
    const h = Math.round(area.h * 0.65);
    return { x: area.x + Math.round((area.w - w) / 2), y: area.y + Math.round((area.h - h) / 2), w, h };
  }
  const isLeft = slot === "left";
  const atSide = isLeft ? near(window.x, area.x) : near(window.x + window.w, area.x + area.w);
  const isDocked = atSide && near(window.y, area.y) && near(window.h, area.h);
  const widths = [1 / 4, 1 / 3, 1 / 2].map((part) => Math.round(area.w * part));
  const w = (isDocked && widths.find((width) => width > window.w + margin)) || widths[0];
  return { x: isLeft ? area.x : area.x + area.w - w, y: area.y, w, h: area.h };
}

function areas() {
  ObjC.import("AppKit");
  const screens = $.NSScreen.screens.js;
  const top = screens[0].frame.size.height;
  return screens.map((screen) => {
    const { origin, size } = screen.visibleFrame;
    return { x: origin.x, y: top - origin.y - size.height, w: size.width, h: size.height };
  });
}

function area(window) {
  const x = window.x + window.w / 2;
  const y = window.y + window.h / 2;
  const all = areas();
  return all.find((one) => x >= one.x && x < one.x + one.w && y >= one.y && y < one.y + one.h) || all[0];
}

function place(slot) {
  const app = Application("System Events").processes.whose({ frontmost: true })[0];
  if (app.name() === "Openspot" || app.windows.length === 0) return;
  const window = app.windows[0];
  const [x, y] = window.position();
  const [w, h] = window.size();
  const target = frame(slot, area({ x, y, w, h }), { x, y, w, h });
  window.size = [target.w, target.h];
  const [realW, realH] = window.size();
  const across = { full: 0, left: 0, center: 0.5, right: 1 }[slot];
  const down = slot === "center" ? 0.5 : 0;
  window.position = [Math.round(target.x + (target.w - realW) * across), Math.round(target.y + (target.h - realH) * down)];
  window.size = [target.w, target.h];
}

function run(argv) {
  if (argv[0] !== "frame") return place(argv[0]);
  const [ax, ay, aw, ah, x, y, w, h] = argv.slice(2).map(Number);
  const result = frame(argv[1], { x: ax, y: ay, w: aw, h: ah }, { x, y, w, h });
  return [result.x, result.y, result.w, result.h].join(" ");
}
'
case "$1" in
  frame)
    osascript -l JavaScript -e "$script" "$@"
    ;;
  full|center|left|right)
    if ! osascript -l JavaScript -e "$script" "$1" >/dev/null 2>&1; then
      printf 'open=x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\n'
      echo "Openspot cannot move the window. Allow it in Accessibility, then press the key again." >&2
      exit 1
    fi
    ;;
  *)
    printf 'toast=Give each command a key in Settings\n'
    ;;
esac
