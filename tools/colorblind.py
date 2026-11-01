#!/usr/bin/env python3
"""Shows a screenshot as it looks with the common color vision deficiencies.

The Machado, Oliveira and Fernandes (2009) simulation at full severity, in linear RGB:
the same matrices as scripts/ui/color_vision.gd, which the HUD palette test uses (AC-4).

  python3 tools/colorblind.py shot.png                      # shot_deuteranopia.png next to it
  python3 tools/colorblind.py shot.png --all --out=/tmp/cb  # all three plus a contact sheet
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

MATRICES = {
    "protanopia": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    "deuteranopia": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    "tritanopia": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}


def to_linear(srgb):
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def to_srgb(lin):
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def simulate(img: Image.Image, deficiency: str) -> Image.Image:
    rgb = np.asarray(img.convert("RGB"), dtype=np.float64) / 255.0
    lin = to_linear(rgb) @ np.array(MATRICES[deficiency]).T
    out = to_srgb(np.clip(lin, 0.0, 1.0))
    return Image.fromarray(np.round(out * 255.0).astype(np.uint8), "RGB")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("shot")
    ap.add_argument("--deficiency", choices=sorted(MATRICES), default="deuteranopia")
    ap.add_argument("--all", action="store_true", help="all three, and a sheet with the original")
    ap.add_argument("--out", help="directory for the results (default: next to the shot)")
    args = ap.parse_args()
    src = Path(args.shot)
    out_dir = Path(args.out) if args.out else src.parent
    out_dir.mkdir(parents=True, exist_ok=True)
    img = Image.open(src)
    names = sorted(MATRICES) if args.all else [args.deficiency]
    views = [img.convert("RGB")]
    for name in names:
        sim = simulate(img, name)
        path = out_dir / f"{src.stem}_{name}.png"
        sim.save(path)
        views.append(sim)
        print(path)
    if args.all:
        sheet = Image.new("RGB", (img.width * 2, img.height * 2))
        for i, v in enumerate(views):
            sheet.paste(v, ((i % 2) * img.width, (i // 2) * img.height))
        path = out_dir / f"{src.stem}_sheet.png"
        sheet.save(path)
        print(path, "(original, then", ", ".join(names) + ")")
    return 0


if __name__ == "__main__":
    sys.exit(main())
