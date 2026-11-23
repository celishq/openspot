import json
import sys
from pathlib import Path

place, task, n, result, seconds = sys.argv[1:6]
place = Path(place)
try:
    report = json.loads((place / "report.json").read_text())
except (OSError, ValueError):
    report = {}
calls = [line.split("\t", 2) for line in (place / "calls.tsv").read_text().splitlines() if line.count("\t") >= 2]


def is_help(words):
    parts = words.split()
    return bool(parts) and (parts[0] in ("help", "guide", "--help") or "--help" in parts)


usage = sum(1 for code, _, _ in calls if code == "2")
hangs = sum(1 for code, _, _ in calls if code == "142")
help_bytes = sum(int(size) for _, size, words in calls if is_help(words))
print("\t".join([
    task, n, result, seconds, str(report.get("num_turns", "")), "%.3f" % float(report.get("total_cost_usd", 0) or 0),
    str(len(calls)), str(usage), str(hangs), str(help_bytes),
]))
