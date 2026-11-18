# Prints a line for each row of the sheet, its order and its rank before it, split by tabs and its lines joined by \001:
# the spot that costs most first, then each spot under the title of its state with a bar for the acts of each day, then
# each search that found nothing, the most often first. A card of other spots runs nothing, so it shows what the spots on
# it cost. Openspot's own spots are left out.
function row(order, rank, block) {
  gsub(/\n/, "\001", block)
  printf "%d\t%09.2f\t%s\n", order, rank, block
}

END {
  for (r = 1; r <= n; r++) {
    load(r)
    id = v["row"]
    if (id ~ /^openspot\//) continue
    graph = ""; via = ""; list = ""; cost = 0
    for (i = 1; i <= ndays; i++) graph = graph "value=" days[i] "\n"
    for (i = 1; i <= ncards; i++) via = join(via, name(cards[i]), ", ")
    if (via != "") via = "On " via
    for (i = 1; i <= nkeys; i++) if (keys[i] ~ /^runs\.by\./) via = via (via == "" ? "Started by " : ", ") name(substr(keys[i], 9))
    for (i = 1; i <= nshows; i++) { list = join(list, name(shows[i]), ", "); cost += perday(shows[i]) }
    acts = counted ? v["acts"] / counted : 0
    day = v["cpu"] / (v["seen"] > 0 ? v["seen"] : 1)
    s = state()
    if (s == "card") {
      order = 4; section = "Cards of other spots"; day = cost; graph = ""
      detail = "Shows " list " · " seconds(cost) " CPU a day"
    } else if (s == "bad") {
      order = 2; section = "Failing"
      detail = v["failures"] " of " v["runs"] " failed · " words[v["failures.timeout"] > 0 ? "timeout" : v["failures.output"] > 0 ? "output" : "exit"]
    } else if (s == "warn") {
      order = 3; section = "Slow to answer"
      detail = "95 in 100 answer within " seconds(v["p95"]) " · half within " seconds(v["p50"])
    } else if (s == "unused") {
      order = 5; section = "Unused for 14 days"
      detail = seconds(day) " CPU a day" (v["hidden.cpu"] > 0 ? ", " seconds(v["hidden.cpu"] / (v["seen"] > 0 ? v["seen"] : 1)) " while hidden" : "")
    } else {
      order = 1; section = "Used · last 14 days"
      detail = (v["acts"] == 0 && via != "" ? via : sprintf("%.1f a day", acts)) " · " seconds(day) " CPU"
    }
    tone = s == "bad" ? "tone=bad\n" : s == "warn" ? "tone=warn\n" : ""
    row(order, 100000 - acts * 100, "row=" id "\ntitle=" v["title"] "\ndetail=" detail "\nsection=" section "\nroute=spot:" id "\n" tone graph sprintf("acts=%.2f\ncpu=%.3f\nstate=%s\n", acts, day, s))
    if (s != "card" && (topcpu == "" || day > topcpu)) { topcpu = day; toptitle = v["title"]; topdetail = seconds(day) " CPU a day" }
  }
  for (i = 1; i <= searches; i++) {
    row(6, 100000 - searchedTimes[i], "row=search:" searched[i] "\ntitle=" searched[i] "\ndetail=Searched " times(searchedTimes[i]) ", found nothing\nsection=Searched, found nothing\nopen=Copy prompt\nclose=false\n")
  }
  row(0, 0, "text=top\ntitle=" (toptitle == "" ? "No spot ran yet" : toptitle) "\ndetail=" topdetail "\n")
}
