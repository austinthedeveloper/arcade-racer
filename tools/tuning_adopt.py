#!/usr/bin/env python3
"""Adopt tuned values as the new defaults (EQ-17).

The debug panel (F3, EQ-16) saves its overrides to user://tuning.cfg. Once a tuning session
has been reviewed (the tuning log read, each change argued for or against), this writes the
kept values into the registry's table in scripts/core/tuning.gd, regenerates the golden
traces and prints a before-and-after table for the commit:

    python3 tools/tuning_adopt.py                     # the game's own user://tuning.cfg
    python3 tools/tuning_adopt.py PATH.cfg            # another override file (a preset)
    python3 tools/tuning_adopt.py --only driving/steer_rate,draft/speed_mult
    python3 tools/tuning_adopt.py --dry-run           # the table only, nothing written
    python3 tools/tuning_adopt.py --no-golden         # write the table, leave the traces

Values are clamped and snapped as the game does (Tuning.set_value). Set GODOT for a binary
that isn't `godot` on the PATH (the traces need it). Exits 1 when there is nothing to adopt.
"""
import argparse
import math
import os
import platform
import re
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TUNING_GD = os.path.join(ROOT, "scripts", "core", "tuning.gd")
APP_NAME = "Sundown Run"
ROW = re.compile(r'^(\t"([a-z_]+/[a-z_]+)": \[)([^,]+), ([^,]+), ([^,]+), ([^,]+), (".*"\],)$')


def user_dir():
    """Godot's user:// for this project on this machine."""
    home = os.path.expanduser("~")
    system = platform.system()
    if system == "Darwin":
        base = os.path.join(home, "Library", "Application Support", "Godot")
    elif system == "Windows":
        base = os.path.join(os.environ.get("APPDATA", home), "Godot")
    else:
        base = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(home, ".local", "share")), "godot")
    return os.path.join(base, "app_userdata", APP_NAME)


def parse_table(text):
    """key -> {default, min, max, step, whole} from tuning.gd's TABLE rows."""
    table = {}
    for line in text.split("\n"):
        m = ROW.match(line)
        if m:
            raw = m.group(3)
            table[m.group(2)] = {
                "default": float(raw), "min": float(m.group(4)), "max": float(m.group(5)),
                "step": float(m.group(6)), "whole": "." not in raw,
            }
    return table


def parse_overrides(text):
    """key -> value from a Godot ConfigFile of sections (areas) and name=number lines."""
    out = {}
    section = ""
    for line in text.split("\n"):
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if "=" in line and section:
            name, value = line.split("=", 1)
            try:
                out[section + "/" + name.strip()] = float(value.strip())
            except ValueError:
                pass
    return out


def settle(entry, value):
    """The value as the game takes it: snapped to the step from the minimum, clamped."""
    lo, hi, step = entry["min"], entry["max"], entry["step"]
    v = round((value - lo) / step) * step + lo
    v = min(max(v, lo), hi)
    return float(round(v)) if entry["whole"] else v


def places(entry):
    """Decimal places in the value's step."""
    n = 0
    while n < 4 and abs(entry["step"] * 10 ** n - round(entry["step"] * 10 ** n)) > 1e-4:
        n += 1
    return n


def text(entry, value):
    """A value as the report shows it (as Tuning.text does): whole numbers plain, the rest to
    the step's places."""
    if entry["whole"]:
        return str(int(round(value)))
    return "%.*f" % (max(places(entry), 1), value)


def literal(entry, value):
    """A value as the table holds it: an int for points, else the shortest float (2.5, 12500.0)."""
    if entry["whole"]:
        return str(int(round(value)))
    return repr(round(value, places(entry)))


def plan(table, overrides, only=None):
    """The changes to make: [(key, before, after)] in table order, and the keys skipped
    (unknown, or not in `only`)."""
    changes = []
    skipped = []
    for key, value in overrides.items():
        if key not in table or (only and key not in only):
            skipped.append(key)
    for key, entry in table.items():
        if key not in overrides or (only and key not in only):
            continue
        after = settle(entry, overrides[key])
        if not math.isclose(after, entry["default"], abs_tol=1e-9):
            changes.append((key, entry["default"], after))
    return changes, skipped


def rewrite(text_in, table, changes):
    """tuning.gd with the defaults of `changes` replaced in their rows."""
    new = dict((k, a) for k, _, a in changes)
    out = []
    for line in text_in.split("\n"):
        m = ROW.match(line)
        if m and m.group(2) in new:
            line = "%s%s, %s, %s, %s, %s" % (m.group(1), literal(table[m.group(2)], new[m.group(2)]),
                                             m.group(4), m.group(5), m.group(6), m.group(7))
        out.append(line)
    return "\n".join(out)


def report(table, changes):
    """The before-and-after table, Markdown, for the commit message."""
    lines = ["| Value | Before | After | Change |", "|---|---|---|---|"]
    for key, before, after in changes:
        e = table[key]
        pct = "" if before == 0 else " (%+.0f%%)" % ((after - before) / abs(before) * 100)
        lines.append("| %s | %s | %s | %s%s |" % (key, text(e, before), text(e, after),
                                                  ("+" if after > before else "") + text(e, after - before), pct))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("file", nargs="?", default=os.path.join(user_dir(), "tuning.cfg"))
    ap.add_argument("--only", default="", help="comma-separated keys to adopt; the rest stay as they are")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-golden", action="store_true")
    args = ap.parse_args()
    if not os.path.exists(args.file):
        sys.exit("No override file at %s" % args.file)
    with open(TUNING_GD) as f:
        source = f.read()
    table = parse_table(source)
    with open(args.file) as f:
        overrides = parse_overrides(f.read())
    only = set(k.strip() for k in args.only.split(",") if k.strip()) or None
    changes, skipped = plan(table, overrides, only)
    for key in skipped:
        print("skipped: %s" % key, file=sys.stderr)
    if not changes:
        print("Nothing to adopt: %s matches the defaults." % args.file)
        return 1
    print(report(table, changes))
    if args.dry_run:
        return 0
    with open(TUNING_GD, "w") as f:
        f.write(rewrite(source, table, changes))
    print("\nWrote %d new defaults to scripts/core/tuning.gd" % len(changes))
    if args.no_golden:
        print("Golden traces not regenerated (--no-golden): run tests/golden.gd before committing.")
        return 0
    godot = os.environ.get("GODOT", "godot")
    # Import first, or golden.gd silently writes one-line traces
    subprocess.run([godot, "--headless", "--path", ROOT, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    r = subprocess.run([godot, "--headless", "--path", ROOT, "-s", "res://tests/golden.gd"])
    if r.returncode != 0:
        sys.exit("golden.gd failed")
    print("Golden traces regenerated. Run tools/test.sh, then commit with the table above.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
