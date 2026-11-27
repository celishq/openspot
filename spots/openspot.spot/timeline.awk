# Turns the entries that `openspot timeline list` prints into the rows of the Timeline sheet: a group for each day, and
# a row for each entry, with its time and the detail its spot gave under its title, or else what it holds, such as
# `09:57 · 3 lines` or `09:57 · github.com`, and the spot it came from when that is not Clipboard. The icon is the one
# its spot gave, or else that of its kind; a colour such as `#ff3b30` shows as a square of itself. The peek its spot
# gave follows its row, so ⌘P shows it.
BEGIN {
  RS = ""; FS = "\n"; count = 0
  split("Sunday Monday Tuesday Wednesday Thursday Friday Saturday", names, " ")
  for (i = 1; i <= 7; i++) weekdays[i - 1] = names[i]
  split("January February March April May June July August September October November December", months, " ")
}

function day_title(day,    y, m, d) {
  if (day == today) return "Today"
  if (day == yesterday) return "Yesterday"
  y = substr(day, 1, 4) + 0
  m = substr(day, 6, 2) + 0
  d = substr(day, 9, 2) + 0
  return weekdays[weekday(y, m, d)] ", " months[m] " " d
}

function weekday(y, m, d) {
  if (m < 3) y--
  return (y + int(y / 4) - int(y / 100) + int(y / 400) + substr("032503514624", m, 1) + d) % 7
}

function what(kind, value, long, count,    host, lines) {
  if (kind == "url") {
    host = value
    sub(/^[a-zA-Z]+:\/\//, "", host)
    sub(/[\/?#].*/, "", host)
    return host
  }
  if (kind == "file") return (count > 1 ? count " files" : (picture(value) ? "Image" : (video(value) ? "Video" : "File")))
  if (long) return "Long text"
  lines = gsub(/\\n/, "&", value) + 1
  return (lines > 1 ? lines " lines" : length(value) " characters")
}

function picture(path) {
  return tolower(path) ~ /\.(png|jpe?g|gif|heic|tiff|webp|bmp)$/
}

function video(path) {
  return tolower(path) ~ /\.(mov|mp4|m4v)$/
}

function source(spot,    name) {
  name = spot
  sub(/.*\//, "", name)
  return toupper(substr(name, 1, 1)) substr(name, 2)
}

{
  delete f
  files = 0
  for (i = 1; i <= NF; i++) {
    n = index($i, "=")
    key = substr($i, 1, n - 1)
    value = substr($i, n + 1)
    if (key == "file" && files++ > 0) continue
    f[key] = value
  }
  if (f["item"] == "") next
  kind = f["kind"]
  day = substr(f["at"], 1, 10)
  detail = substr(f["at"], 12, 5) " · " (f["detail"] != "" ? f["detail"] : what(kind, f[kind], f["text.file"] != "", files))
  if (f["spot"] != "clipboard") detail = detail " · " source(f["spot"])
  if (count++ == 0) {
    printf "title=Timeline\n\n"
    printf "button=press\ntitle=Copy\nscope=item\n\n"
    printf "button=paste\ntitle=Paste\nshortcut=cmd+return\nscope=item\n\n"
    printf "button=forget\ntitle=Forget\nshortcut=cmd+backspace\nscope=item\nclose=false\n\n"
    printf "items=list\n"
  }
  if (day != last) {
    printf "\nbox=day-%s\nparent=list\ntitle=%s\n", day, day_title(day)
    last = day
  }
  icon = f["icon"] != "" ? f["icon"] : (kind == "url" ? "link" : (kind == "file" ? ((picture(f["file"]) || video(f["file"])) && files == 1 ? f["file"] : "doc") : (f["text"] ~ /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/ ? tolower(f["text"]) : "textformat")))
  printf "\nitem=%s\nparent=day-%s\ntitle=%s\ndetail=%s\nicon=%s\nkind=%s\n", f["item"], day, f["title"], detail, icon, kind
  if (kind == "url" || (kind == "text" && f["text.file"] == "")) printf "%s=%s\n", kind, f[kind]
  if (kind == "text" && f["text.file"] != "") printf "file=%s\n", f["text.file"]
  if (kind == "text" || kind == "url") printf "keywords=%s\n", substr(f[kind], 1, 200)
  if (kind == "file") printf "file=%s\n", f[kind]
  printf "open.title=Copy\n"
  if (f["peek.file"] != "") printf "peek.file=%s\n", f["peek.file"]
}

END {
  if (count == 0) printf "\nitem=empty\ntitle=Copy something, and it shows here.\nicon=doc.on.clipboard\nhides=copy\nhides=forget\n"
}
