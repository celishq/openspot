# Prints a line for each block of the sheet, its order and its rank before it, split by tabs and its lines joined by \001:
# the spot that costs most first, then each spot under the section of its state with a bar for the acts of each day, then
# each search that found nothing, the most often first. Openspot's own spots are left out.
function row(order, rank, block) {
  gsub(/\n/, "\001", block)
  printf "%d\t%09.2f\t%s\n", order, rank, block
}

BEGIN {
  split("used failing slow unused searched", sid, " ")
  split("Used · last 14 days|Failing|Slow to answer|Unused for 14 days|Searched, found nothing", titles, "|")
  for (i = 1; i <= 5; i++) { sections[i, "id"] = sid[i]; sections[i, "title"] = titles[i] }
}

END {
  for (r = 1; r <= n; r++) {
    load(r)
    id = v["text"]
    if (id ~ /^openspot\//) continue
    graph = ""; via = ""
    for (i = 1; i <= ndays; i++) graph = graph (i == 1 ? "value=" : ",") days[i]
    if (graph != "") graph = graph "\n"
    for (i = 1; i <= nkeys; i++) if (keys[i] ~ /^runs\.by\./) via = via (via == "" ? "Started by " : ", ") name(substr(keys[i], 9))
    acts = counted ? v["acts"] / counted : 0
    day = v["cpu"] / (v["seen"] > 0 ? v["seen"] : 1)
    s = state()
    if (s == "bad") {
      order = 2
      detail = v["failures"] " of " v["runs"] " failed · " words[v["failures.timeout"] > 0 ? "timeout" : v["failures.output"] > 0 ? "output" : "exit"]
    } else if (s == "warn") {
      order = 3
      detail = "95 in 100 answer within " seconds(v["p95"]) " · half within " seconds(v["p50"])
    } else if (s == "unused") {
      order = 4
      detail = seconds(day) " CPU a day" (v["hidden.cpu"] > 0 ? ", " seconds(v["hidden.cpu"] / (v["seen"] > 0 ? v["seen"] : 1)) " while hidden" : "")
    } else {
      order = 1
      detail = (v["acts"] == 0 && via != "" ? via : sprintf("%.1f a day", acts)) " · " seconds(day) " CPU"
    }
    tone = s == "bad" ? "tone=bad\n" : s == "warn" ? "tone=warn\n" : ""
    row(order, 100000 - acts * 100, "series=" id "\nparent=" sections[order, "id"] "\ntitle=" v["title"] "\ndetail=" detail "\nroute=spot:" id "\n" tone graph sprintf("acts=%.2f\ncpu=%.3f\nstate=%s\n", acts, day, s))
    listed[order] = 1
    if (topcpu == "" || day > topcpu) { topcpu = day; toptitle = v["title"]; topdetail = seconds(day) " CPU a day" }
  }
  for (i = 1; i <= searches; i++) {
    row(5, 100000 - searchedTimes[i], "text=search:" searched[i] "\nparent=" sections[5, "id"] "\ntitle=" searched[i] "\ndetail=Searched " times(searchedTimes[i]) ", found nothing\nopen.title=Copy prompt\nclose=false\n")
    listed[5] = 1
  }
  for (order in listed) row(order, -1, "box=" sections[order, "id"] "\nparent=spots\ntitle=" sections[order, "title"] "\n")
  row(0, 0, "text=top\nclass=hidden card:flex\ntitle=" (toptitle == "" ? "No spot ran yet" : toptitle) "\ndetail=" topdetail "\n")
}
