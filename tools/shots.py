#!/usr/bin/env python3
"""Screenshot regression: compares freshly rendered screenshots with the small reference
images in tests/shots/ (tools/shots.sh renders them and calls this).

    python3 tools/shots.py compare <rendered_dir> [<ref_dir>]   # exit 1 on a mismatch
    python3 tools/shots.py update  <rendered_dir> [<ref_dir>]   # rewrite the references
    python3 tools/shots.py selftest                            # the comparison's own checks

Each screenshot is shrunk to REF_SIZE before anything else (that is also what is stored),
then compared two ways:
  - a difference hash (dHash, HASH_W x HASH_H bits) on the grey image: catches things
    moving, appearing or disappearing, but not a change of color;
  - the mean absolute difference of the colors on a COLOR_W x COLOR_H grid (0..255 per
    channel): catches a change of color or brightness, global or local.
A shot passes when both stay within the tolerances (MAX_HASH_BITS, MAX_COLOR_DIFF; the
--max-hash-bits / --max-color-diff flags override them). On a failure a side-by-side
image (reference | rendered | difference) is written next to the rendered shot.
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops

REF_SIZE = (160, 90)  # the 640x360 screen, a quarter each way
HASH_W, HASH_H = 16, 16  # 256 bits
COLOR_W, COLOR_H = 32, 18
# Three consecutive local runs (macOS, --fixed-fps 60) all came out at 0 bits and 0.00
# color: the renders are repeatable. The slack is for another GPU or driver's rounding;
# a deliberate tint of the menu backdrop and the road failed five of six shots at 2-21
# bits / 3.2-15 color (the hash alone missed the road: 2 bits); the dark Neon Strip road
# changed least, 1.7, and passed.
MAX_HASH_BITS = 12  # of 256
MAX_COLOR_DIFF = 2.0  # mean, 0..255


def reduce(img: Image.Image) -> Image.Image:
    """The stored form of a screenshot: RGB, REF_SIZE."""
    return img.convert("RGB").resize(REF_SIZE, Image.Resampling.BOX)


def dhash(img: Image.Image) -> int:
    """Difference hash: each bit says whether a pixel is brighter than its right neighbour."""
    g = img.convert("L").resize((HASH_W + 1, HASH_H), Image.Resampling.BOX)
    px = g.tobytes()
    bits = 0
    for y in range(HASH_H):
        row = px[y * (HASH_W + 1):(y + 1) * (HASH_W + 1)]
        for x in range(HASH_W):
            bits = (bits << 1) | (1 if row[x] > row[x + 1] else 0)
    return bits


def hash_distance(a: Image.Image, b: Image.Image) -> int:
    return bin(dhash(a) ^ dhash(b)).count("1")


def color_diff(a: Image.Image, b: Image.Image) -> float:
    """Mean absolute per-channel difference on a coarse grid, 0..255."""
    size = (COLOR_W, COLOR_H)
    ca = a.convert("RGB").resize(size, Image.Resampling.BOX)
    cb = b.convert("RGB").resize(size, Image.Resampling.BOX)
    diff = ImageChops.difference(ca, cb).tobytes()
    return sum(diff) / len(diff)


def compare(ref: Image.Image, shot: Image.Image, max_bits: int, max_color: float):
    """(passed, hash bits, color difference) for a reference and a reduced shot."""
    bits = hash_distance(ref, shot)
    col = color_diff(ref, shot)
    return bits <= max_bits and col <= max_color, bits, col


def side_by_side(ref: Image.Image, shot: Image.Image) -> Image.Image:
    w, h = REF_SIZE
    out = Image.new("RGB", (w * 3, h))
    out.paste(ref, (0, 0))
    out.paste(shot, (w, 0))
    out.paste(ImageChops.difference(ref, shot).point(lambda v: min(255, v * 4)), (w * 2, 0))
    return out.resize((w * 6, h * 2), Image.Resampling.NEAREST)


def selftest() -> int:
    """The comparison on made-up images: same passes, a shift of color or of shapes fails."""
    base = Image.new("RGB", REF_SIZE, (40, 40, 60))
    for x in range(0, REF_SIZE[0], 20):  # stripes and a block, so the hash has edges
        base.paste((200, 180, 60), (x, 0, x + 8, REF_SIZE[1]))
    base.paste((220, 60, 60), (50, 30, 110, 70))
    tinted = Image.eval(base, lambda v: min(255, v + 12))  # everything a little lighter
    moved = base.copy()
    moved.paste((40, 40, 60), (50, 30, 110, 70))
    moved.paste((220, 60, 60), (10, 10, 70, 50))
    cases = [
        ("an identical image passes", base, True),
        ("a global color change fails", tinted, False),
        ("moved shapes fail", moved, False),
    ]
    fails = 0
    for name, img, want in cases:
        ok, bits, col = compare(base, img, MAX_HASH_BITS, MAX_COLOR_DIFF)
        good = ok == want
        fails += 0 if good else 1
        print(f"  {'ok  ' if good else 'FAIL'} {name} (hash {bits} bits, color {col:.2f})")
    _, bits, _ = compare(base, tinted, MAX_HASH_BITS, MAX_COLOR_DIFF)
    if bits > MAX_HASH_BITS:
        print("  FAIL the tint should get past the hash alone (it is the color term's job)")
        fails += 1
    return 1 if fails else 0


def main() -> int:
    if sys.argv[1:] == ["selftest"]:
        return selftest()
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["compare", "update"])
    ap.add_argument("rendered", type=Path)
    ap.add_argument("refs", type=Path, nargs="?", default=Path("tests/shots"))
    ap.add_argument("--max-hash-bits", type=int, default=MAX_HASH_BITS)
    ap.add_argument("--max-color-diff", type=float, default=MAX_COLOR_DIFF)
    args = ap.parse_args()

    shots = sorted(p for p in args.rendered.glob("*.png") if not p.stem.endswith(".diff"))
    if not shots:
        print(f"no screenshots in {args.rendered}", file=sys.stderr)
        return 1

    if args.mode == "update":
        args.refs.mkdir(parents=True, exist_ok=True)
        for old in args.refs.glob("*.png"):
            old.unlink()
        for p in shots:
            reduce(Image.open(p)).save(args.refs / p.name, optimize=True)
            print(f"  wrote {args.refs / p.name}")
        return 0

    fails = 0
    names = {p.name for p in shots}
    for p in shots:
        ref_path = args.refs / p.name
        if not ref_path.exists():
            print(f"  FAIL {p.stem}: no reference (tools/shots.sh --update)")
            fails += 1
            continue
        ref = Image.open(ref_path).convert("RGB")
        shot = reduce(Image.open(p))
        ok, bits, col = compare(ref, shot, args.max_hash_bits, args.max_color_diff)
        line = f"{p.stem}: hash {bits}/{HASH_W * HASH_H} bits, color {col:.2f}"
        if ok:
            print(f"  ok   {line}")
        else:
            fails += 1
            diff = p.with_name(p.stem + ".diff.png")
            side_by_side(ref, shot).save(diff)
            print(f"  FAIL {line} (max {args.max_hash_bits} bits, {args.max_color_diff:.2f} color); see {diff}")
    for ref_path in sorted(args.refs.glob("*.png")):
        if ref_path.name not in names:
            print(f"  FAIL {ref_path.stem}: reference with no screenshot rendered")
            fails += 1
    print(f"\n{fails} screenshot check(s) failed" if fails else f"\nall {len(shots)} screenshots match")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
