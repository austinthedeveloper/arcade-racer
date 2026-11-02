#!/usr/bin/env python3
"""Prints one version's section of CHANGELOG.md, for the GitHub Release notes.

A pre-release tag (0.2.0-alpha) uses its own section if there is one, else its base
version's (0.2.0). Exits 1 when the version has no section or it is empty, so the
release workflow stops before building a release nobody described.

--json prints {"version": ..., "notes": ...} instead: tools/export.sh bundles that as
assets/whats_new.json, which the title screen shows once after an update (WhatsNew, PR-17).

Usage:
    python3 tools/changelog.py [--json] 0.2.0 [path/to/CHANGELOG.md]
"""
import json
import os
import re
import sys

HEADING = re.compile(r"^## \[([^\]]+)\]")


def sections(text):
    """{version: body} for every '## [version]' heading, body without the heading."""
    out, name, lines = {}, None, []
    for line in text.splitlines():
        m = HEADING.match(line)
        if m:
            if name is not None:
                out[name] = "\n".join(lines).strip()
            name, lines = m.group(1), []
        elif name is not None:
            lines.append(line)
    if name is not None:
        out[name] = "\n".join(lines).strip()
    return out


def notes(text, version):
    found = sections(text)
    for v in (version, version.split("-")[0]):
        if found.get(v):
            return found[v]
    return None


def main():
    as_json = "--json" in sys.argv[1:]
    args = [a for a in sys.argv[1:] if a != "--json"]
    if not args:
        print(__doc__.strip())
        return 2
    version = args[0].lstrip("v")
    path = args[1] if len(args) > 1 else os.path.join(os.path.dirname(__file__), "..", "CHANGELOG.md")
    with open(path, encoding="utf-8") as f:
        body = notes(f.read(), version)
    if body is None:
        print("CHANGELOG.md has no section for %s: rename Unreleased to [%s] - <date>" % (version, version),
              file=sys.stderr)
        return 1
    print(json.dumps({"version": version, "notes": body}, indent=1) if as_json else body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
