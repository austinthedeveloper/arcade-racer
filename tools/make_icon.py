"""The game's icon (PR-13): the striped sunset disc from the logo shapes sheet
(ui02_logo_shapes_A_v1.png, top middle) on a night-blue tile with a gold rim,
the title screen's colors. Writes icon.png (the project, window and Web icon),
icon.ico (Windows) and icon.icns (macOS) at the project root.
    python3 tools/make_icon.py assets/concept .
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SHEET = "ui/ui02_logo_shapes_A_v1.png"
DISC_CENTER = (802, 256)  # the disc's chrome ring, measured on the sheet
DISC_RADIUS = 157
SIZE = 1024
NIGHT = (20, 12, 42, 255)  # MenuScreen.NIGHT
GOLD = (255, 210, 58, 255)  # MenuScreen.GOLD
CHROME = (27, 42, 107, 255)  # the frames' outer blue


def disc(sheet: Image.Image, size: int) -> Image.Image:
    """The disc cut out round (dropping its speed lines), `size` pixels across."""
    cx, cy = DISC_CENTER
    r = DISC_RADIUS
    crop = sheet.crop((cx - r, cy - r, cx + r, cy + r)).resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    crop.putalpha(mask.resize((size, size), Image.LANCZOS))
    return crop


def icon(sheet: Image.Image) -> Image.Image:
    # macOS-style margins: the tile is about 80% of the canvas, so it sits with the Dock's icons
    tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    m = 100
    d.rounded_rectangle((m, m, SIZE - m, SIZE - m), radius=185, fill=GOLD)
    d.rounded_rectangle((m + 22, m + 22, SIZE - m - 22, SIZE - m - 22), radius=165, fill=CHROME)
    d.rounded_rectangle((m + 36, m + 36, SIZE - m - 36, SIZE - m - 36), radius=152, fill=NIGHT)
    s = 640
    tile.alpha_composite(disc(sheet, s), ((SIZE - s) // 2, (SIZE - s) // 2))
    return tile


def main() -> None:
    concept = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/concept")
    out = Path(sys.argv[2] if len(sys.argv) > 2 else ".")
    img = icon(Image.open(concept / SHEET).convert("RGBA"))
    img.resize((256, 256), Image.LANCZOS).save(out / "icon.png")
    img.save(out / "icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    img.save(out / "icon.icns")
    print("wrote icon.png, icon.ico, icon.icns in", out)


if __name__ == "__main__":
    main()
