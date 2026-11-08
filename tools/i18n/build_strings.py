#!/usr/bin/env python3
"""Build game/i18n/strings.csv for Godot's CSV translation importer.

Merges the base tables exported from the reference data with the native
override tables (native_*.json), checks that both languages have the same
keys and the same {placeholders}, and writes one CSV with columns
keys,en,zh_CN. Godot imports it into strings.en.translation and
strings.zh_CN.translation.

Usage: python3 tools/i18n/build_strings.py
"""
import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game" / "i18n" / "source"
OUT = ROOT / "game" / "i18n" / "strings.csv"
PH = re.compile(r"\{([a-zA-Z0-9_]+)\}")


def load(name):
    p = SRC / name
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


def main():
    en = load("base_en.json")
    zh = load("base_zh_CN.json")
    en.update(load("native_en.json"))
    zh.update(load("native_zh_CN.json"))
    problems = []
    for k in sorted(set(en) ^ set(zh)):
        problems.append("missing in %s: %s" % ("zh_CN" if k in en else "en", k))
    for k in sorted(set(en) & set(zh)):
        if set(PH.findall(en[k])) != set(PH.findall(zh[k])):
            problems.append("placeholder mismatch: %s" % k)
    for p in problems:
        print(p, file=sys.stderr)
    keys = sorted(set(en) | set(zh))
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        w.writerow(["keys", "en", "zh_CN"])
        for k in keys:
            w.writerow([k, en.get(k, zh.get(k, "")), zh.get(k, en.get(k, ""))])
    print("wrote %d keys to %s (%d problems)" % (len(keys), OUT.relative_to(ROOT), len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
