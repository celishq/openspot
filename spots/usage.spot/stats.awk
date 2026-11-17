# Reads the blocks of openspot spot stats, one record for each block and one line for each field, and judges each spot.
BEGIN { RS = ""; FS = "\n"; words["timeout"] = "timed out"; words["exit"] = "stopped with an error"; words["output"] = "printed what Openspot cannot read" }

function seconds(s) { return s < 1 ? sprintf("%d ms", s * 1000 + 0.5) : sprintf("%.1f s", s) }
function bytes(b) { return b >= 1048576 ? sprintf("%.0f MB", b / 1048576) : sprintf("%.0f KB", b / 1024) }
function times(count) { return count (count == 1 ? " time" : " times") }
function name(id) { return title[id] != "" ? title[id] : id }
function perday(id) { return seen[id] > 0 ? cpu[id] / seen[id] : 0 }
function join(list, part, gap) { return list (list == "" ? "" : gap) part }

/^row=/ {
  n++; rec[n] = $0; id = substr($1, 5); ids[n] = id
  for (i = 2; i <= NF; i++) {
    if ($i ~ /^title=/) title[id] = substr($i, 7)
    else if ($i ~ /^cpu=/) cpu[id] = substr($i, 5)
    else if ($i ~ /^seen=/) seen[id] = substr($i, 6)
  }
}
/^use=/ { if ($0 ~ /\ndeclared=false/) for (i = 1; i <= NF; i++) if ($i ~ /^spot=/) undeclared[substr($i, 6)]++ }
/^search=/ { searches++; searched[searches] = substr($1, 8); searchedTimes[searches] = substr($2, 7) }

# Loads row r: each key once in v, its keys in order in keys, the acts of each day in days, the days that counted acts,
# and the spots it shows in shows, the cards it is on in cards.
function load(r,   lines, count, i, k) {
  delete v; delete keys; delete days; delete shows; delete cards
  nkeys = 0; ndays = 0; nshows = 0; ncards = 0; counted = 0; started = 0
  count = split(rec[r], lines, "\n")
  for (i = 1; i <= count; i++) {
    k = lines[i]; sub(/=.*/, "", k)
    keys[++nkeys] = k
    v[k] = substr(lines[i], length(k) + 2)
    if (k == "days") { days[++ndays] = v[k]; if (v[k] != "-") counted++ }
    else if (k == "shows") shows[++nshows] = v[k]
    else if (k == "cards") cards[++ncards] = v[k]
    else if (k ~ /^runs\.by\./) started++
  }
}

# The state of the loaded spot: card when it shows other spots, bad when a call failed in 14 days, warn when 95 in 100 of
# its answers take more than a second, unused when 14 days of counts hold no act and no card or spot reaches it, else used.
function state() {
  if (nshows) return "card"
  if (v["failures"] + 0 > 0) return "bad"
  if (v["p95"] + 0 > 1) return "warn"
  if (counted >= 14 && v["acts"] + 0 == 0 && !ncards && !started) return "unused"
  return "used"
}

# Whether the loaded spot offers Improve: it fails, answers slowly, or makes a call its header doesn't declare.
function improves(   s) { s = state(); return s == "bad" || s == "warn" || undeclared[v["row"]] > 0 }
