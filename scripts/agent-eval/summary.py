import csv
import statistics
import sys
from pathlib import Path

NUMBERS = ["seconds", "turns", "cost", "calls", "usage", "hangs", "help"]


def rows(path):
    with open(path) as file:
        return list(csv.DictReader(file, delimiter="\t"))


def number(text):
    try:
        return float(text)
    except ValueError:
        return 0.0


def line(name, runs):
    passed = sum(1 for run in runs if run["result"] == "pass")
    medians = [statistics.median(number(run[key]) for run in runs) for key in NUMBERS]
    cost = sum(number(run["cost"]) for run in runs)
    return [name, f"{passed}/{len(runs)}"] + [f"{value:g}" for value in medians] + [f"{cost:.2f}"]


def table(path):
    runs = rows(path)
    tasks = sorted({run["task"] for run in runs})
    lines = [line(task, [run for run in runs if run["task"] == task]) for task in tasks]
    return lines + [line("all", runs)]


head = ["task", "pass"] + [f"median {key}" for key in NUMBERS] + ["cost all"]
labels = [Path(path).parent.name for path in sys.argv[1:]]
tables = [table(path) for path in sys.argv[1:]]
width = [max(len(cell) for cell in column) for column in zip(head, *[row for rows_ in tables for row in rows_])]
for label, lines in zip(labels, tables):
    print(label)
    for row in [head] + lines:
        print("  ".join(cell.ljust(size) for cell, size in zip(row, width)).rstrip())
    print()
