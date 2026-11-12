#!/usr/bin/env python3
"""Playtest report (EQ-25): turns a folder of playtest logs into a per-stage chart of where
players crash and slow down.

    python3 tools/playtest_report.py LOG_DIR [--out=report.html] [--png=DIR]

LOG_DIR holds the race_*.json files the game writes with Options > Display > PLAYTEST LOG on
(scripts/race/playtest_log.gd), in the playtest folder beside the crash log: user://logs/playtest,
e.g. ~/Library/Application Support/Godot/app_userdata/Sundown Run/logs/playtest on macOS. Logs
from several players can be put in one folder. The HTML report is plain Python; --png also
writes one PNG per stage and needs Pillow (tools/requirements.txt). Nothing is sent anywhere.
"""
import argparse
import glob
import html
import json
import os
import sys

FORMAT = 1
STAGE_ORDER = ["palm_coast", "redrock", "neon", "timberline", "bayou", "harvest", "thunder", "skyline"]
LOST = "#e0a030"  # time lost bars
CRASH = "#d83a3a"  # crash marks


def load(folder):
    """Every readable log in `folder`, as dicts; the files it skipped, as (name, why)."""
    logs, skipped = [], []
    for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
        try:
            with open(path, encoding="utf-8") as f:
                d = json.load(f)
        except (OSError, ValueError) as e:
            skipped.append((os.path.basename(path), str(e)))
            continue
        if not isinstance(d, dict) or d.get("format") != FORMAT or not d.get("stage"):
            skipped.append((os.path.basename(path), "not a playtest log"))
            continue
        logs.append(d)
    return logs, skipped


def by_stage(logs):
    """Per stage: runs, results, mean time lost and crash count per stretch, checkpoints."""
    out = {}
    for d in logs:
        s = out.setdefault(d["stage"], {"runs": 0, "results": {}, "cars": {}, "lost": {}, "crashes": {},
                                        "seen": {}, "stretch_length": d.get("stretch_length", 1), "length": 0.0,
                                        "finish_times": []})
        s["runs"] += 1
        s["results"][d.get("result", "")] = s["results"].get(d.get("result", ""), 0) + 1
        s["cars"][d.get("car", "")] = s["cars"].get(d.get("car", ""), 0) + 1
        s["length"] = max(s["length"], float(d.get("length", 0.0)))
        if d.get("result") == "finish":
            s["finish_times"].append(float(d.get("time", 0.0)))
        for row in d.get("stretches", []):
            i = int(row["index"])
            s["lost"][i] = s["lost"].get(i, 0.0) + float(row.get("lost", 0.0))
            s["seen"][i] = s["seen"].get(i, 0) + 1
        for c in d.get("crashes", []):
            i = int(float(c["distance"]) // s["stretch_length"])
            s["crashes"][i] = s["crashes"].get(i, 0) + 1
    for s in out.values():
        s["mean_lost"] = {i: s["lost"][i] / s["seen"][i] for i in s["lost"]}
        s["stretches"] = max([int(s["length"] // s["stretch_length"]) + 1] + [i + 1 for i in s["seen"]] +
                             [i + 1 for i in s["crashes"]])
    return out


def ordered(stages):
    return sorted(stages, key=lambda k: (STAGE_ORDER.index(k) if k in STAGE_ORDER else 99, k))


def worst(s, n=3):
    """The `n` stretches with the most time lost, then the most crashes: [(index, lost, crashes)]."""
    keys = set(s["mean_lost"]) | set(s["crashes"])
    rows = [(i, s["mean_lost"].get(i, 0.0), s["crashes"].get(i, 0)) for i in keys]
    rows.sort(key=lambda r: (-r[1], -r[2], r[0]))
    return rows[:n]


def svg(s, width=760, height=180):
    """The stage's chart: time lost per stretch (bars, seconds per run), crashes (red ticks below)."""
    n = max(1, s["stretches"])
    left, top, bottom = 40, 12, 40
    plot_h = height - top - bottom
    bw = (width - left - 10) / n
    peak = max([0.5] + list(s["mean_lost"].values()))
    parts = ['<svg viewBox="0 0 %d %d" width="%d" height="%d" role="img">' % (width, height, width, height)]
    for frac in (0.0, 0.5, 1.0):
        y = top + plot_h * (1 - frac)
        parts.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#ccc" stroke-width="0.5"/>' % (left, y, width - 10, y))
        parts.append('<text x="%d" y="%.1f" font-size="10" text-anchor="end">%.1fs</text>' % (left - 4, y + 3, peak * frac))
    for i in range(n):
        lost = s["mean_lost"].get(i, 0.0)
        h = plot_h * lost / peak
        x = left + i * bw
        if h > 0:
            parts.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"><title>stretch %d: %.2f s lost</title></rect>'
                         % (x + 0.5, top + plot_h - h, max(0.5, bw - 1), h, LOST, i, lost))
        crashes = s["crashes"].get(i, 0)
        if crashes:
            parts.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s"><title>stretch %d: %d crash%s</title></rect>'
                         % (x + 0.5, top + plot_h + 4, max(0.5, bw - 1), min(20, 4 * crashes), CRASH, i, crashes,
                            "" if crashes == 1 else "es"))
    parts.append('<text x="%d" y="%d" font-size="10">start</text>' % (left, height - 4))
    parts.append('<text x="%d" y="%d" font-size="10" text-anchor="end">finish</text>' % (width - 10, height - 4))
    parts.append("</svg>")
    return "".join(parts)


def report_html(stages, skipped):
    out = ["<!doctype html><html><head><meta charset='utf-8'><title>Playtest report</title>",
           "<style>body{font-family:sans-serif;margin:16px;max-width:800px}svg{max-width:100%;height:auto}"
           "h2{margin-bottom:4px}.k{display:inline-block;width:10px;height:10px;margin:0 4px 0 12px}</style>",
           "</head><body><h1>Playtest report</h1>",
           "<p>Bars: seconds lost per run in each stretch against top speed"
           "<span class='k' style='background:%s'></span>; red marks under them: crashes"
           "<span class='k' style='background:%s'></span>.</p>" % (LOST, CRASH)]
    if not stages:
        out.append("<p>No playtest logs in this folder.</p>")
    for stage in ordered(stages):
        s = stages[stage]
        res = ", ".join("%d %s" % (v, k.replace("_", " ")) for k, v in sorted(s["results"].items()))
        best = (" Best finish %.2f s." % min(s["finish_times"])) if s["finish_times"] else ""
        out.append("<h2>%s</h2><p>%d run%s: %s.%s</p>" % (html.escape(stage.replace("_", " ").title()), s["runs"],
                                                           "" if s["runs"] == 1 else "s", html.escape(res), best))
        out.append(svg(s))
        rows = worst(s)
        if rows:
            out.append("<p>Worst stretches: " + "; ".join(
                "%d (%.1f s lost, %d crash%s)" % (i, lost, c, "" if c == 1 else "es") for i, lost, c in rows) + ".</p>")
    if skipped:
        out.append("<p>Skipped: " + html.escape(", ".join(name for name, _ in skipped)) + "</p>")
    out.append("</body></html>")
    return "\n".join(out)


def write_pngs(stages, folder, width=760, height=180):
    """One PNG per stage, the same chart as the HTML (needs Pillow). Returns the paths."""
    from PIL import Image, ImageDraw  # only for --png
    os.makedirs(folder, exist_ok=True)
    paths = []
    for stage in ordered(stages):
        s = stages[stage]
        img = Image.new("RGB", (width, height), "white")
        d = ImageDraw.Draw(img)
        n = max(1, s["stretches"])
        left, top, bottom = 40, 20, 30
        plot_h = height - top - bottom
        bw = (width - left - 10) / n
        peak = max([0.5] + list(s["mean_lost"].values()))
        d.text((left, 4), "%s: %d runs, peak %.1f s lost" % (stage, s["runs"], peak), fill="black")
        d.line([(left, top + plot_h), (width - 10, top + plot_h)], fill="#999")
        for i in range(n):
            x = left + i * bw
            h = plot_h * s["mean_lost"].get(i, 0.0) / peak
            if h > 0:
                d.rectangle([x, top + plot_h - h, x + max(1, bw - 1), top + plot_h], fill=LOST)
            c = s["crashes"].get(i, 0)
            if c:
                d.rectangle([x, top + plot_h + 3, x + max(1, bw - 1), top + plot_h + 3 + min(20, 4 * c)], fill=CRASH)
        path = os.path.join(folder, "playtest_%s.png" % stage)
        img.save(path)
        paths.append(path)
    return paths


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("folder", help="a folder of playtest logs (race_*.json)")
    p.add_argument("--out", default="playtest_report.html", help="the HTML report to write")
    p.add_argument("--png", default="", help="also write a PNG per stage into this folder (needs Pillow)")
    a = p.parse_args(argv)
    if not os.path.isdir(a.folder):
        print("no such folder: %s" % a.folder, file=sys.stderr)
        return 1
    logs, skipped = load(a.folder)
    stages = by_stage(logs)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(report_html(stages, skipped))
    print("%d logs, %d stages -> %s" % (len(logs), len(stages), a.out))
    if a.png:
        for path in write_pngs(stages, a.png):
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
