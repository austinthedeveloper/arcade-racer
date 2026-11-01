#!/usr/bin/env python3
"""Check the roadmap docs (docs/roadmap/) against the GitHub issues and project board.

The docs hold the wording; GitHub holds the state. A feature row is done when its issue is
closed. This reports where the two disagree and can fix the parts that are mechanical:

    python3 tools/roadmap_sync.py                # report only (reads GitHub, writes nothing)
    python3 tools/roadmap_sync.py --write-docs   # tick done rows (ID cell "RC-1 ✓") and rewrite
                                                 # the status block in docs/roadmap/00-overview.md
    python3 tools/roadmap_sync.py --fix-board    # set the project Status to Done for closed
                                                 # issues (and back to Todo for reopened ones)

Needs the gh CLI, signed in. Exits 1 when the report finds a mismatch.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DOCS = os.path.join(ROOT, "docs", "roadmap")
OVERVIEW = os.path.join(DOCS, "00-overview.md")
OWNER = "austinthedeveloper"
REPO = OWNER + "/arcade-racer"
PROJECT = 4
DONE_MARK = " ✓"
ROW = re.compile(r"^\| ([A-Z]{2}-\d+)( ✓)? \| \*\*(.+?)\.\*\*.*?\| *(\S*) *\|")
CELL = re.compile(r"^\| [A-Z]{2}-\d+(?: ✓)? \|")
BEGIN, END = "<!-- roadmap-status:begin -->", "<!-- roadmap-status:end -->"


def gh(*args):
    return json.loads(subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout)


def doc_features():
    """[(id, name, done mark, doc file)] in doc order. Rows with no size are cross-references
    to a feature in another group (CP-8 is EQ-3) and have no issue of their own."""
    out = []
    for name in sorted(os.listdir(DOCS)):
        if not re.match(r"0[1-9]-.*\.md$", name):
            continue
        with open(os.path.join(DOCS, name)) as f:
            for line in f:
                m = ROW.match(line)
                if m and m.group(4):
                    out.append((m.group(1), m.group(3), bool(m.group(2)), name))
    return out


def issues():
    """Feature id -> {number, title, name, closed} for every roadmap issue."""
    out = {}
    for i in gh("issue", "list", "--repo", REPO, "--state", "all", "--limit", "500",
                "--json", "number,title,state"):
        m = re.match(r"([A-Z]{2}-\d+) (.+)", i["title"])
        if m:
            out[m.group(1)] = {"number": i["number"], "title": i["title"], "name": m.group(2),
                               "closed": i["state"] == "CLOSED"}
    return out


def board():
    """Issue number -> {item id, status}, plus the project id and Status field options."""
    items = gh("project", "item-list", str(PROJECT), "--owner", OWNER, "--limit", "500", "--format", "json")["items"]
    by_number = {i["content"]["number"]: {"id": i["id"], "status": i.get("status")}
                 for i in items if i.get("content", {}).get("number")}
    fields = gh("project", "field-list", str(PROJECT), "--owner", OWNER, "--format", "json")["fields"]
    status = next(f for f in fields if f["name"] == "Status")
    project_id = gh("project", "view", str(PROJECT), "--owner", OWNER, "--format", "json")["id"]
    return by_number, project_id, status["id"], {o["name"]: o["id"] for o in status["options"]}


def report(features, by_id, items):
    """Problems as text lines: missing issues, wording drift, ticks and board status out of step."""
    problems = []
    ids = {f[0] for f in features}
    for fid, name, ticked, doc in features:
        issue = by_id.get(fid)
        if issue is None:
            problems.append("%s (%s) has no issue" % (fid, doc))
            continue
        if issue["name"] != name:
            problems.append("%s #%d is titled %r, the doc says %r" % (fid, issue["number"], issue["name"], name))
        if ticked != issue["closed"]:
            problems.append("%s is %s in %s but #%d is %s" % (
                fid, "ticked" if ticked else "not ticked", doc, issue["number"],
                "closed" if issue["closed"] else "open"))
        status = items.get(issue["number"], {}).get("status")
        if issue["number"] not in items:
            problems.append("%s #%d is not on the project board" % (fid, issue["number"]))
        elif issue["closed"] != (status == "Done"):
            problems.append("%s #%d is %s but the board says %s" % (
                fid, issue["number"], "closed" if issue["closed"] else "open", status))
    for fid, issue in sorted(by_id.items()):
        if fid not in ids:
            problems.append("#%d %s has no row in docs/roadmap" % (issue["number"], issue["title"]))
    return problems


def write_docs(features, by_id):
    """Tick done rows in the group docs and rewrite the overview's status block."""
    for name in sorted(os.listdir(DOCS)):
        if not re.match(r"0[1-9]-.*\.md$", name):
            continue
        path = os.path.join(DOCS, name)
        with open(path) as f:
            lines = f.readlines()

        def tick(line):
            m = ROW.match(line)
            if not m or m.group(1) not in by_id:
                return line
            mark = DONE_MARK if by_id[m.group(1)]["closed"] else ""
            return CELL.sub("| %s%s |" % (m.group(1), mark), line, count=1)

        with open(path, "w") as f:
            f.writelines(tick(line) for line in lines)
    with open(OVERVIEW) as f:
        text = f.read()
    if BEGIN not in text:
        sys.exit("%s has no %s ... %s block" % (OVERVIEW, BEGIN, END))
    head, rest = text.split(BEGIN, 1)
    tail = rest.split(END, 1)[1]
    with open(OVERVIEW, "w") as f:
        f.write(head + BEGIN + "\n" + status_block(features, by_id) + END + tail)


def status_block(features, by_id):
    """Per group: done out of total, and which."""
    groups = {}
    for fid, _, _, doc in features:
        groups.setdefault(doc, []).append(fid)
    lines = ["| Group | Done | Finished | Open |", "|---|---|---|---|"]
    for doc, fids in groups.items():
        done = [f for f in fids if by_id.get(f, {}).get("closed")]
        left = [f for f in fids if f not in done]
        link = lambda f: "[%s](https://github.com/%s/issues/%d)" % (f, REPO, by_id[f]["number"]) if f in by_id else f
        lines.append("| [%s](%s) | %d / %d | %s | %s |" % (
            fids[0].split("-")[0], doc, len(done), len(fids),
            ", ".join(link(f) for f in done) or "none", ", ".join(link(f) for f in left) or "none"))
    return "\n".join(lines) + "\n"


def fix_board(by_id, items, project_id, field_id, options):
    for fid, issue in sorted(by_id.items()):
        item = items.get(issue["number"])
        if item is None:
            continue
        want = "Done" if issue["closed"] else (item["status"] if item["status"] != "Done" else "Todo")
        if item["status"] != want:
            subprocess.run(["gh", "project", "item-edit", "--id", item["id"], "--project-id", project_id,
                            "--field-id", field_id, "--single-select-option-id", options[want]], check=True,
                           capture_output=True)
            print("board: %s #%d %s -> %s" % (fid, issue["number"], item["status"], want))


def main():
    args = set(sys.argv[1:])
    if args - {"--write-docs", "--fix-board"}:
        sys.exit(__doc__)
    features = doc_features()
    by_id = issues()
    items, project_id, field_id, options = board()
    if "--fix-board" in args:
        fix_board(by_id, items, project_id, field_id, options)
        items = board()[0]
    if "--write-docs" in args:
        write_docs(features, by_id)
        features = doc_features()
    problems = report(features, by_id, items)
    for p in problems:
        print(p)
    print("%d features, %d issues, %d problems" % (len(features), len(by_id), len(problems)))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
