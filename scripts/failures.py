import json
import sys


def walk(node, test):
    if node.get("nodeType") == "Test Case":
        test = node.get("name", "")
    if node.get("nodeType") == "Failure Message":
        print(f"  {test}: {node.get('name', '')[:300]}")
    for child in node.get("children", []):
        walk(child, test)


for root in json.load(sys.stdin).get("testNodes", []):
    walk(root, "")
