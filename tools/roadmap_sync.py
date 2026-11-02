#!/usr/bin/env python3
"""Check the roadmap docs (docs/roadmap/) against the GitHub issues and project board.

The docs hold the wording; GitHub holds the state. A feature row is done when its issue is
closed. This reports where the two disagree and can fix the parts that are mechanical:

    python3 tools/roadmap_sync.py                # report only (reads GitHub, writes nothing)
    python3 tools/roadmap_sync.py --write-docs   # tick done rows (ID cell "RC-1 ✓") and rewrite
                                                 # the status block in docs/roadmap/00-overview.md
    python3 tools/roadmap_sync.py --fix-board    # set the project Status to Done for closed
                                                 # issues (and back to Todo for reopened ones)
    python3 tools/roadmap_sync.py --create-issues   # open an issue for every row that has none
                                                    # (labels, milestone, project fields), in the
                                                    # shape of the first batch (2026-10-31)

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
## Every cell of a row: id, tick, name, description, size, month, needs, done when.
FULL_ROW = re.compile(r"^\| ([A-Z]{2}-\d+)( ✓)? \| \*\*(.+?)\.\*\* ?(.*?) \| *([^|]*?) *\| *([^|]*?) *\| *([^|]*?) *\| *(.*?) *\|$")
GROUPS = {"RC": "racing core", "WS": "world and stages", "CP": "cars and art pipeline",
          "WH": "input and wheels", "PR": "presentation and audio", "MP": "modes and progression",
          "AC": "options and accessibility", "EQ": "engineering and quality", "ON": "online and mobile"}
MONTHS = ["Nov 2026", "Dec 2026", "Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027"]
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


def doc_rows():
    """Every row's cells, in doc order: dicts with id, name, desc, size, month, needs, done, doc."""
    rows = []
    for name in sorted(os.listdir(DOCS)):
        if not re.match(r"0[1-9]-.*\.md$", name):
            continue
        with open(os.path.join(DOCS, name)) as f:
            for line in f:
                m = FULL_ROW.match(line.rstrip("\n"))
                if m:
                    rows.append({"id": m.group(1), "name": m.group(3), "desc": m.group(4), "size": m.group(5),
                                 "month": m.group(6), "needs": m.group(7), "done": m.group(8), "doc": name})
    return rows


def first_month(month):
    """The month number a row starts in (its Month cell: "1", "2, 3", "Stretch"), or 0."""
    m = re.search(r"\d", month)
    return int(m.group()) if m else 0


def needs_text(needs, by_id):
    """"WS-1, EQ-16" -> "WS-1 (#28), EQ-16 (#101)" (an id without an issue yet stays bare)."""
    if not needs.strip():
        return "nothing"
    return re.sub(r"([A-Z]{2}-\d+)", lambda m: "%s (#%d)" % (m.group(1), by_id[m.group(1)]["number"])
                  if m.group(1) in by_id else m.group(1), needs)


def issue_body(row, by_id):
    month = first_month(row["month"])
    when = "%s (%s)" % (row["month"], MONTHS[month - 1]) if month else row["month"]
    group = GROUPS[row["id"].split("-")[0]]
    return ("**Group:** %s · **Size:** %s · **Month:** %s\n**Source:** [docs/roadmap/%s](https://github.com/%s/blob/main/docs/roadmap/%s)\n\n"
            "%s\n\n**Needs:** %s\n\n**Done when:** %s\n") % (
        group[0].upper() + group[1:], row["size"], when, row["doc"], REPO, row["doc"], row["desc"],
        needs_text(row["needs"], by_id), row["done"])


def create_issues(by_id, items, project_id):
    """An issue, labels, milestone and board item for every row without an issue; then the
    bodies that named a row created after them get its number."""
    fields = {f["name"]: f for f in gh("project", "field-list", str(PROJECT), "--owner", OWNER, "--format", "json")["fields"]}
    milestones = {int(m["title"][1]): m["title"] for m in gh("api", "repos/%s/milestones?state=all" % REPO)}
    created = []
    for row in doc_rows():
        if row["id"] in by_id:
            continue
        prefix = row["id"].split("-")[0]
        month = first_month(row["month"])
        args = ["issue", "create", "--repo", REPO, "--title", "%s %s" % (row["id"], row["name"]),
                "--body", issue_body(row, by_id), "--label", "%s: %s" % (prefix, GROUPS[prefix]),
                "--label", "size: %s" % row["size"], "--label", "roadmap"]
        if month in milestones:
            args += ["--milestone", milestones[month]]
        url = subprocess.run(["gh"] + args, check=True, capture_output=True, text=True).stdout.strip()
        number = int(url.rsplit("/", 1)[1])
        by_id[row["id"]] = {"number": number, "title": "%s %s" % (row["id"], row["name"]), "name": row["name"], "closed": False}
        item = gh("project", "item-add", str(PROJECT), "--owner", OWNER, "--url", url, "--format", "json")
        values = {"Status": "Todo" if month == 1 else "Backlog", "Size": row["size"],
                  "Group": "%s: %s" % (prefix, GROUPS[prefix]), "Month": MONTHS[month - 1] if month else None}
        for field, value in values.items():
            option = next((o["id"] for o in fields[field].get("options", []) if o["name"] == value), None)
            if option:
                subprocess.run(["gh", "project", "item-edit", "--id", item["id"], "--project-id", project_id,
                                "--field-id", fields[field]["id"], "--single-select-option-id", option],
                               check=True, capture_output=True)
        created.append(row)
        print("created #%d %s %s" % (number, row["id"], row["name"]))
    for row in created:  # a dependency created later in the run has its number now
        if re.search(r"[A-Z]{2}-\d+(?! \()", needs_text(row["needs"], {})) and row["needs"].strip():
            subprocess.run(["gh", "issue", "edit", str(by_id[row["id"]]["number"]), "--repo", REPO,
                            "--body", issue_body(row, by_id)], check=True, capture_output=True)


def main():
    args = set(sys.argv[1:])
    if args - {"--write-docs", "--fix-board", "--create-issues"}:
        sys.exit(__doc__)
    features = doc_features()
    by_id = issues()
    items, project_id, field_id, options = board()
    if "--create-issues" in args:
        create_issues(by_id, items, project_id)
        by_id = issues()
        items = board()[0]
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
