#!/bin/sh
set -u
cd "$(dirname "$0")/.."
urls=${*:-$(grep -oE 'https://[^"]+/usd\.json' app/Core/Calc/CalcRates.swift)}
[ -n "$urls" ] || { echo "FAIL no address found in app/Core/Calc/CalcRates.swift"; exit 1; }
ecb=$(curl -fsS --max-time 20 https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml 2>/dev/null |
  sed -n "s/.*currency='USD' rate='\([0-9.]*\)'.*/\1/p")
status=0
for url in $urls; do
  if ! body=$(curl -fsS --max-time 20 "$url" 2>&1); then
    echo "FAIL $url: no file ($body)"
    status=1
    continue
  fi
  printf '%s' "$body" | python3 -I -c '
import datetime, json, sys
url, ecb = sys.argv[1], sys.argv[2]
try:
    file = json.load(sys.stdin)
    day = datetime.date.fromisoformat(file["date"])
    rates = file["usd"]
except Exception as error:
    sys.exit(f"FAIL {url}: not a rates file ({error})")
faults = []
age = (datetime.datetime.now(datetime.timezone.utc).date() - day).days
if age > 2:
    faults.append(f"its date {day} is {age} days old")
if len(rates) < 300:
    faults.append(f"it knows {len(rates)} currencies, under 300")
missing = [code for code in ("eur", "uah", "btc") if not rates.get(code)]
if missing:
    faults.append("it has no " + ", ".join(missing))
check = ""
if ecb and rates.get("eur"):
    bank = 1 / float(ecb)
    eur = rates["eur"]
    gap = abs(eur - bank) / bank
    check = f", EUR {eur:.4f} against {bank:.4f} of the ECB"
    if gap > 0.03:
        faults.append(f"its EUR rate is {gap:.1%} from the ECB")
elif not ecb:
    check = ", ECB rate not read"
if faults:
    sys.exit(f"FAIL {url}: " + "; ".join(faults))
print(f"OK {url}: {day}, {len(rates)} currencies{check}")
' "$url" "$ecb" || status=1
done
exit $status
