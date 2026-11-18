# Prints the page of the spot want: its acts of each day, what it costs, how fast it answers, how it failed, its uses, the
# change since its last version, and the spots it starts and is started by. An unused spot offers Move to Trash first.
function buttons(improve, unused) {
  if (unused) printf "button=delete\ntitle=Move to Trash\nshortcut=return\nconfirm=Press again to move it to the Trash\nclose=false\n\nbutton=open\ntitle=Open\nclose=false\n\n"
  else printf "button=open\ntitle=Open\nshortcut=return\nclose=false\n\n"
  if (improve) printf "button=improve\ntitle=Improve\nshortcut=cmd+return\nclose=false\n\n"
  printf "button=settings\ntitle=Settings\nclose=false\n"
  if (!unused) printf "\nbutton=delete\ntitle=Move to Trash\nconfirm=Press again to move it to the Trash\nclose=false\n"
}

END {
  for (r = 1; r <= n && ids[r] != want; r++) {}
  if (r > n) { buttons(0, 0); exit }
  load(r)
  for (i = 1; i <= nkeys; i++) {
    k = keys[i]; x = v[k]
    if (k ~ /^reads\./) reads = join(reads, x " at " substr(k, 7), " · ")
    else if (k ~ /^call\./) calls = join(calls, substr(k, 6) " " x, " · ")
    else if (k ~ /^failures\./) kinds = join(kinds, x " " words[substr(k, 10)], " · ")
    else if (k ~ /^runs\.by\./) by = join(by, name(substr(k, 9)) " " times(x), " · ")
    else if (k ~ /^ran\./) ran = join(ran, name(substr(k, 5)) " " times(x), " · ")
  }
  for (i = 1; i <= ndays; i++) graph = graph "value=" (days[i] == "-" ? 0 : days[i]) "\n"
  d = v["seen"] > 0 ? v["seen"] : 1
  day = v["cpu"] / d
  printf "frame=spot:%s\ngrid=acts acts\ngrid=perday cpu\ngrid=answers memory\n", want
  if (change != "") printf "grid=change change\ngrid=changecpu changecpu\n"
  if (by != "") printf "grid=by by\n"
  if (ran != "") printf "grid=ran ran\n"
  printf "grid=hidden hidden\ngrid=failures failures\ngrid=reads reads\ngrid=uses uses\n\n"
  printf "graph=acts\ntitle=Acts, last 14 days\n%s\n", graph
  printf "number=perday\nvalue=%.1f\ntitle=acts a day\n\n", (counted ? v["acts"] / counted : 0)
  printf "number=cpu\nvalue=%.3f\ndisplay=%s\ntitle=CPU a day\n\n", day, seconds(day)
  printf "number=answers\nvalue=%s\ndisplay=%s\ntitle=Slow answers\n\n", v["p95"] + 0, (v["p95"] == "" ? "–" : seconds(v["p95"]))
  printf "number=memory\nvalue=%s\ndisplay=%s\ntitle=Peak memory\n\n", v["memory"] + 0, (v["memory"] == "" ? "–" : bytes(v["memory"]))
  if (change != "") {
    split(change, part, "\t")
    printf "text=change\ntitle=Failed since %s\ndetail=%s\n\n", part[1], part[2]
    printf "text=changecpu\ntitle=CPU a call since\ndetail=%s\n\n", part[3]
  }
  if (by != "") printf "text=by\ntitle=Started by\ndetail=%s\n\n", by
  if (ran != "") printf "text=ran\ntitle=Starts\ndetail=%s\n\n", ran
  printf "text=hidden\ntitle=While hidden\ndetail=%s CPU a day · %d wakeups\n\n", seconds(v["hidden.cpu"] / d), v["hidden.wakeups"] / d
  if (v["failures"] > 0) printf "text=failures\ntitle=Failures\ndetail=%s of %s calls · %s\ntone=bad\n\n", v["failures"], v["runs"], kinds
  else printf "text=failures\ntitle=Failures\ndetail=None of %s calls\n\n", v["runs"] + 0
  printf "text=reads\ntitle=Reads\ndetail=%s\n\n", (reads == "" ? "None" : reads)
  printf "text=uses\ntitle=Uses\ndetail=%s\n\n", (calls == "" ? "None" : calls)
  buttons(improves(), state() == "unused")
}
