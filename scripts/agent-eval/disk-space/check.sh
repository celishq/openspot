#!/bin/sh
. "$TASKS/checks.sh"
lint || exit 1
shown=$("$OPENSPOT" spot run "$(own_id)" </dev/null)
echo "$shown"
printf "%s" "$shown" | python3 -I -c "
import re, shutil, sys
text = sys.stdin.read()
full = [100 * (1 - shutil.disk_usage(p).free / shutil.disk_usage(p).total) for p in (\"/\", \"/System/Volumes/Data\")]
found = [float(n) for n in re.findall(r\"(\d+(?:\.\d+)?)\s*%\", text)]
found += [100 * float(n) for n in re.findall(r\"^value=(0?\.\d+|1(?:\.0+)?)\s*$\", text, re.M)]
print(\"full:\", full, \"found:\", found)
sys.exit(0 if any(abs(a - b) <= 3 for a in full for b in found) else 1)
"
