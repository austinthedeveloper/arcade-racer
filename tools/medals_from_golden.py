#!/usr/bin/env python3
"""Re-derive the medal times (Medals.TIMES, scripts/race/medals.gd) from the golden traces.

The Normal medal times sit around the autodrive's finish with traffic and rivals, the last line
of each stage's trace in tests/golden/ (test_medals reads the same line). After a play change
regenerates the traces, the autodrive finishes at another time and the table follows it:

    gold   = floor(0.91 x the autodrive's time)   quicker than the autodrive
    silver = ceil(1.02 x)                          the autodrive earns silver on Normal
    bronze = ceil(1.12 x)                          about an eighth slower

    python3 tools/medals_from_golden.py            # rewrite TIMES, print before and after
    python3 tools/medals_from_golden.py --dry-run  # the table only, nothing written

tools/tuning_adopt.py runs this after it regenerates the traces. Paste the printed table into
the commit. Exits 1 when a stage's trace or row is missing.
"""
import math
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MEDALS_GD = os.path.join(ROOT, "scripts", "race", "medals.gd")
STAGES_GD = os.path.join(ROOT, "scripts", "track", "stages", "stages.gd")
GOLDEN = os.path.join(ROOT, "tests", "golden")
GOLD, SILVER, BRONZE = 0.91, 1.02, 1.12


def stage_ids() -> list:
    """Stages.POSTCARDS, in stage order."""
    m = re.search(r"const POSTCARDS := \[([^\]]*)\]", open(STAGES_GD).read())
    return re.findall(r'"([a-z_]+)"', m.group(1))


def scenario(index: int, sid: str) -> str:
    """The stage's golden trace with traffic and rivals (test_medals.autodrive_time)."""
    return "autodrive_traffic" if index == 0 else sid + "_autodrive_traffic"


def autodrive_time(name: str) -> float:
    lines = open(os.path.join(GOLDEN, name + ".txt")).read().strip().split("\n")
    return float(re.search(r" t=([0-9.]+)", lines[-1]).group(1))


def medals(t: float) -> list:
    return [float(math.floor(GOLD * t)), float(math.ceil(SILVER * t)), float(math.ceil(BRONZE * t))]


def main() -> int:
    dry = "--dry-run" in sys.argv[1:]
    text = open(MEDALS_GD).read()
    print("  %-12s %-9s %-15s    %s" % ("stage", "autodrive", "gold/silver/bronze", "after"))
    for i, sid in enumerate(stage_ids()):
        row = re.search(r'"%s": \[([^\]]*)\]' % sid, text)
        path = os.path.join(GOLDEN, scenario(i, sid) + ".txt")
        if row is None or not os.path.exists(path):
            print("no %s for %s" % ("row in medals.gd" if row is None else "trace " + path, sid), file=sys.stderr)
            return 1
        t = autodrive_time(scenario(i, sid))
        before = [float(x) for x in row.group(1).split(",")]
        after = medals(t)
        fmt = lambda v: "/".join("%d" % x for x in v)
        print("  %-12s %9.2f %-15s -> %s%s" % (sid, t, fmt(before), fmt(after), "" if after != before else " (same)"))
        text = text.replace(row.group(0), '"%s": [%s]' % (sid, ", ".join("%.1f" % x for x in after)))
    if not dry:
        open(MEDALS_GD, "w").write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
