"""Reproducible assets (EQ-19): rebuilds every sprite with the sprite tools, into the
checkout, and fails if any picture differs from the committed one by a pixel.

    python3 tools/check_sprites.py               # rebuild, compare, exit 1 on a difference
    python3 tools/check_sprites.py --no-rebuild  # compare what an earlier rebuild left
    python3 tools/check_sprites.py --out=DIR     # also copy each differing file into DIR

Pixels, not bytes: the same picture saved by another zlib (another Pillow wheel, another
OS) is a different file. A file whose pixels match is put back as committed, so afterwards
the working tree shows only the real differences, ready to commit after a deliberate tool
change. Needs the pinned libraries (pip install -r tools/requirements.txt): another
Pillow resamples some sprites one or two levels differently. CI runs this as the
"Reproducible sprites" job (.github/workflows/ci.yml). Not covered: tools/make_audio.py
(sounds, its own seeded run) and tools/make_car_renders.py (needs Blender and a model).
"""
import io
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CONCEPT = "assets/concept"

# Every sprite tool, in the order the README's commands give (the LOD pass last, after the
# sprites it reduces). Arguments are relative to the project root.
TOOLS = [
    ("make_car_sprites.py", CONCEPT, "."),
    ("make_stage_sprites.py", CONCEPT, "."),
    ("make_ui_sprites.py", CONCEPT, "."),
    ("make_icon.py", CONCEPT, "."),
    ("make_span_sprites.py", CONCEPT, "."),
    ("make_powerup_sprites.py", CONCEPT, "."),
    ("make_fx_sprites.py", CONCEPT, "."),
    ("make_drawn_props.py", "."),
    ("make_lod_sprites.py", "."),
]

# Color levels a pixel may be off by and still match: the same pinned libraries round a few
# of the FX smoke's pixels one level apart on macOS and on CI's Linux.
TOLERANCE = 1

# What the tools write: anything else that changes is not theirs.
OUTPUTS = ("assets/sprites/", "icon.png", "icon.ico", "icon.icns")
IMAGE_EXTS = (".png", ".ico", ".icns")


def git(*args, binary=False):
    out = subprocess.run(["git", "-C", PROJECT, *args], capture_output=True, check=True)
    return out.stdout if binary else out.stdout.decode()


def changed_outputs():
    """Paths under OUTPUTS that differ from HEAD or are new, from git status."""
    paths = []
    for line in git("status", "--porcelain", "--untracked-files=all", "--", *OUTPUTS).splitlines():
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        paths.append((line[:2], path.strip('"')))
    return paths


def frames(data):
    """Every picture in an image file's bytes as RGBA arrays: one for a PNG, one per size
    for an .ico or .icns."""
    img = Image.open(io.BytesIO(data))
    sizes = sorted(img.info.get("sizes", ())) if img.format in ("ICO", "ICNS") else []
    if not sizes:
        return [np.asarray(img.convert("RGBA"))]
    out = []
    for size in sizes:
        img = Image.open(io.BytesIO(data))
        if len(size) == 3:  # .icns: (width, height, scale)
            img.size = size[:2]
            img.load(scale=size[2])
        else:
            img.size = size
        out.append(np.asarray(img.convert("RGBA")))
    return out


def pixel_diff(old, new):
    """How two image files' bytes differ as pictures: None when every pixel matches (to within
    TOLERANCE), else a short description (size change, or how many pixels differ and by how
    much at most)."""
    a, b = frames(old), frames(new)
    if len(a) != len(b):
        return "%d pictures, was %d" % (len(b), len(a))
    for fa, fb in zip(a, b):
        if fa.shape != fb.shape:
            return "size %dx%d, was %dx%d" % (fb.shape[1], fb.shape[0], fa.shape[1], fa.shape[0])
        d = np.abs(fa.astype(int) - fb.astype(int))
        if d.max() > TOLERANCE:
            return "%d of %d pixels differ, by up to %d" % ((d.max(axis=2) > TOLERANCE).sum(), d.shape[0] * d.shape[1], d.max())
    return None


def file_diff(path, old, new):
    """None when the rebuilt file `new` matches the committed `old`: pixels for a picture,
    content for the manifest (key order aside), bytes otherwise."""
    if path.endswith(IMAGE_EXTS):
        return pixel_diff(old, new)
    if path.endswith(".json"):
        return None if json.loads(old) == json.loads(new) else "content differs"
    return None if old == new else "content differs"


def compare(restore=True):
    """The rebuilt outputs against HEAD, as (path, reason) for each real difference. Files
    whose pixels match go back to their committed bytes when `restore`."""
    problems, same = [], []
    for status, path in changed_outputs():
        if status == "??":
            problems.append((path, "new file, not in the repository"))
            continue
        if "D" in status:
            problems.append((path, "deleted"))
            continue
        with open(os.path.join(PROJECT, path), "rb") as f:
            new = f.read()
        reason = file_diff(path, git("show", "HEAD:" + path, binary=True), new)
        if reason:
            problems.append((path, reason))
        else:
            same.append(path)
    if restore and same:
        git("checkout", "--", *same)
    return problems


def rebuild():
    for tool, *args in TOOLS:
        print("rebuilding:", tool, " ".join(args), flush=True)
        run = subprocess.run([sys.executable, os.path.join("tools", tool), *args], cwd=PROJECT,
                             capture_output=True, text=True)
        if run.returncode:
            sys.stdout.write(run.stdout + run.stderr)
            sys.exit("%s failed" % tool)


def keep(problems, out_dir):
    """Copies each differing rebuilt file under `out_dir` at its project path (CI uploads
    them, so a difference can be looked at, or taken as the new art)."""
    for path, _ in problems:
        src = os.path.join(PROJECT, path)
        if os.path.exists(src):
            dst = os.path.join(out_dir, path)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)


def main():
    out_dir = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--out=")), None)
    if "--no-rebuild" not in sys.argv[1:]:
        dirty = changed_outputs()
        if dirty:
            sys.exit("sprites already differ from HEAD (%s ...): commit or restore them first" % dirty[0][1])
        rebuild()
    problems = compare()
    for path, reason in problems:
        print("DIFFERS:", path, "-", reason)
    if out_dir:
        keep(problems, out_dir)
    if problems:
        print("%d rebuilt files differ from the repository. If a tool changed on purpose, commit"
              " what it wrote; otherwise the tool or its libraries no longer reproduce the art"
              " (tools/requirements.txt pins them)." % len(problems))
        sys.exit(1)
    print("every sprite rebuilds to the committed pixels")


if __name__ == "__main__":
    main()
