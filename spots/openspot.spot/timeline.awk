# Turns the entries that `openspot timeline list` prints into the rows of the Timeline sheet: a group for each day, and
# a row for each entry, with its source and its time under its title. The card shows the newest entry.
BEGIN { RS = ""; FS = "\n"; count = 0 }

function day_title(day,    line) {
  if (day == today) return "Today"
  if (day == yesterday) return "Yesterday"
  if (!(day in titles)) {
    line = ""
    ("date -j -f %F " day " '+%A, %B %e'" | getline line)
    gsub(/  +/, " ", line)
    titles[day] = (line == "" ? day : line)
  }
  return titles[day]
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
    if ((key == "file" || key == "picture") && files++ > 0) continue
    f[key] = value
  }
  if (f["item"] == "") next
  kind = "text"
  if ("url" in f) kind = "url"
  if ("file" in f) kind = "file"
  if ("picture" in f) kind = "picture"
  day = substr(f["at"], 1, 10)
  detail = source(f["spot"]) " · " substr(f["at"], 12, 5)
  if (count++ == 0) {
    printf "title=%s\ndetail=%s\n", f["title"], detail
    if (card) exit
    printf "\n"
    printf "button=copy\ntitle=Copy\nshortcut=cmd+c\nscope=item\n\n"
    printf "button=forget\ntitle=Forget\nshortcut=cmd+backspace\nscope=item\nclose=false\n\n"
    printf "items=list\n"
  }
  if (day != last) {
    printf "\nbox=day-%s\nparent=list\ntitle=%s\n", day, day_title(day)
    last = day
  }
  icon = (kind == "url" ? "link" : (kind == "file" ? "doc" : (kind == "picture" ? f["picture"] : "text.alignleft")))
  printf "\nitem=%s\nparent=day-%s\ntitle=%s\ndetail=%s\nicon=%s\nkind=%s\n", f["item"], day, f["title"], detail, icon, kind
  if (kind == "url" || (kind == "text" && f["text.file"] == "")) printf "%s=%s\n", kind, f[kind]
  if (kind == "text" && f["text.file"] != "") printf "file=%s\n", f["text.file"]
  if (kind == "text" || kind == "url") printf "keywords=%s\n", substr(f[kind], 1, 200)
  if (kind == "file" || kind == "picture") printf "file=%s\n", f[kind]
  if (f["text.file"] != "") printf "whole=%s\n", f["text.file"]
  printf "open.title=%s\n", (kind == "url" ? "Open" : "Paste")
}

END {
  if (card) exit
  if (count == 0) printf "\nitem=empty\ntitle=Copy something, and it shows here.\nicon=doc.on.clipboard\nhides=copy\nhides=forget\n"
}
