#!/usr/bin/env python3
"""Build placeholder game sprites for the road prototype.

- Slices the round 1 palm concept sheet into individual keyed sprites.
- Turns the Palm Coast background concept into a seamless parallax strip.
- Draws a few simple pixel-art props (billboard, lifeguard tower, umbrella, lamp, hotel, bush).

These are stand-ins until production art exists.

Usage:
    python3 tools/make_placeholder_sprites.py <concept_dir> <project_dir>
"""
import os
import sys

from PIL import Image, ImageDraw

PALM_NAMES = ["palm_tall_a", "palm_tall_b", "palm_lean", "palm_short_a", "palm_short_b", "palm_fan", "palm_cluster"]
PALM_TARGET_HEIGHT = 190  # tallest palm, in texture pixels


def is_key(r, g, b):
    """Magenta key plus the pink fringe the generator leaves around edges."""
    return (r > 150 and b > 150 and g < 120) or (r - g > 90 and b - g > 90)


def key_out(img):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if is_key(r, g, b):
                px[x, y] = (0, 0, 0, 0)
    return img


def components(img, step=2, min_area=400):
    """Connected opaque regions (on a downsampled mask), as full-res bounding boxes, left to right."""
    alpha = img.getchannel("A")
    w, h = img.size[0] // step, img.size[1] // step
    small = alpha.resize((w, h), Image.NEAREST).load()
    seen = [[False] * w for _ in range(h)]
    label = [[-1] * w for _ in range(h)]
    boxes = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or small[sx, sy] == 0:
                continue
            stack, area, cells = [(sx, sy)], 0, []
            seen[sy][sx] = True
            x0, y0, x1, y1 = sx, sy, sx, sy
            while stack:
                x, y = stack.pop()
                area += 1
                cells.append((x, y))
                x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and small[nx, ny] > 0:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if area >= min_area:
                for x, y in cells:
                    label[y][x] = len(boxes)
                boxes.append(((x0 * step, y0 * step, (x1 + 1) * step, (y1 + 1) * step), len(boxes)))
    return sorted(boxes, key=lambda b: b[0][0]), label, step


def pixelate_down(img, scale):
    w, h = img.size
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    rgb = img.convert("RGBA").resize((nw, nh), Image.BOX)
    px = rgb.load()
    for y in range(nh):
        for x in range(nw):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 140 else (0, 0, 0, 0)
    return rgb


def make_palms(concept_dir, out_dir):
    sheet = Image.open(os.path.join(concept_dir, "roadside", "palm-coast_palms_A_v1.png"))
    keyed = key_out(sheet)
    crops = []
    boxes, label, step = components(keyed)
    for box, comp in boxes:
        part = keyed.crop(box)
        px = part.load()
        for y in range(part.height):
            for x in range(part.width):
                ly, lx = (box[1] + y) // step, (box[0] + x) // step
                if ly >= len(label) or lx >= len(label[0]) or label[ly][lx] != comp:
                    px[x, y] = (0, 0, 0, 0)
        crops.append(part.crop(part.getbbox()))
    tallest = max(c.height for c in crops)
    scale = PALM_TARGET_HEIGHT / tallest
    os.makedirs(out_dir, exist_ok=True)
    for name, crop in zip(PALM_NAMES, crops):
        sprite = pixelate_down(crop, scale)
        sprite.save(os.path.join(out_dir, name + ".png"))
        print("palm", name, sprite.size)


def make_background(concept_dir, out_path):
    src = Image.open(os.path.join(concept_dir, "backgrounds", "palm-coast_composite_A_v1.png")).convert("RGB")
    horizon = 584  # sea horizon / beach line in the concept
    strip = src.crop((0, 0, src.width, horizon))
    width = 1280
    height = round(strip.height * width / strip.width)
    strip = strip.resize((width, height), Image.BOX)
    seamless = Image.new("RGB", (width * 2, height))
    seamless.paste(strip, (0, 0))
    seamless.paste(strip.transpose(Image.FLIP_LEFT_RIGHT), (width, 0))
    seamless = seamless.quantize(colors=96, method=Image.MEDIANCUT).convert("RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    seamless.save(out_path)
    print("background", seamless.size)


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def make_billboard(path):
    img, d = canvas(96, 76)
    for x in (18, 74):
        d.rectangle((x, 44, x + 4, 75), fill=(70, 52, 40))
        d.rectangle((x + 1, 44, x + 1, 75), fill=(110, 84, 62))
    d.rectangle((0, 0, 95, 50), fill=(40, 34, 52))
    top, bottom = (255, 120, 60), (255, 214, 110)
    for y in range(3, 48):
        t = (y - 3) / 44
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line((3, y, 92, y), fill=c)
    d.ellipse((34, 16, 62, 44), fill=(255, 244, 190))
    for y in range(30, 48, 4):
        d.line((3, y, 92, y), fill=(240, 96, 70))
    d.rectangle((3, 40, 92, 47), fill=(30, 110, 150))
    d.line((14, 47, 18, 18), fill=(40, 30, 40), width=2)
    for dx, dy in ((-8, -2), (8, -2), (-6, 3), (7, 4), (0, -5)):
        d.line((18, 18, 18 + dx, 18 + dy), fill=(40, 30, 40), width=2)
    d.rectangle((0, 0, 95, 50), outline=(20, 16, 28))
    img.save(path)


def make_lifeguard(path):
    img, d = canvas(60, 76)
    leg = (220, 220, 230)
    for x in (10, 46):
        d.line((x, 40, x + (4 if x < 30 else -4), 75), fill=leg, width=3)
    d.line((12, 58, 46, 58), fill=leg, width=2)
    d.rectangle((6, 38, 54, 42), fill=(200, 200, 210))
    d.rectangle((10, 18, 50, 38), fill=(120, 200, 220))
    d.rectangle((16, 22, 44, 32), fill=(40, 70, 100))
    d.polygon([(4, 18), (56, 18), (46, 6), (14, 6)], fill=(220, 50, 50))
    d.line((4, 18, 56, 18), fill=(150, 30, 30))
    d.line((52, 40, 60, 75), fill=(200, 180, 140), width=3)
    d.line((28, 6, 28, 0), fill=(90, 70, 50))
    d.polygon([(28, 0), (36, 2), (28, 4)], fill=(255, 190, 40))
    img.save(path)


def make_umbrella(path):
    img, d = canvas(44, 40)
    d.line((22, 8, 22, 39), fill=(240, 240, 240), width=2)
    d.pieslice((2, 0, 42, 22), 180, 360, fill=(230, 60, 60))
    for i, x in enumerate(range(2, 42, 8)):
        if i % 2:
            d.pieslice((2, 0, 42, 22), 180 + i * 36, 180 + (i + 1) * 36, fill=(250, 250, 245))
    d.rectangle((6, 34, 38, 39), fill=(60, 150, 220))
    d.line((6, 36, 38, 36), fill=(250, 220, 90))
    img.save(path)


def make_lamp(path):
    img, d = canvas(24, 100)
    d.rectangle((10, 12, 13, 99), fill=(60, 66, 80))
    d.rectangle((8, 92, 15, 99), fill=(45, 50, 62))
    d.line((12, 12, 4, 6), fill=(60, 66, 80), width=3)
    d.rectangle((0, 4, 8, 8), fill=(250, 240, 200))
    d.line((12, 12, 20, 6), fill=(60, 66, 80), width=3)
    d.rectangle((16, 4, 23, 8), fill=(250, 240, 200))
    img.save(path)


def make_hotel(path):
    img, d = canvas(128, 100)
    d.rectangle((4, 10, 123, 99), fill=(250, 196, 196))
    d.rectangle((4, 10, 123, 16), fill=(240, 150, 160))
    d.rectangle((50, 0, 78, 12), fill=(250, 196, 196))
    d.rectangle((54, 3, 74, 9), fill=(70, 200, 210))
    for row in range(4):
        for col in range(7):
            x = 12 + col * 16
            y = 22 + row * 16
            d.rectangle((x, y, x + 8, y + 9), fill=(80, 160, 200))
            d.line((x, y + 10, x + 8, y + 10), fill=(255, 255, 255))
    d.rectangle((4, 86, 123, 90), fill=(60, 180, 170))
    for x in range(4, 124, 8):
        d.polygon([(x, 90), (x + 8, 90), (x + 4, 94)], fill=(60, 180, 170))
    d.rectangle((54, 90, 74, 99), fill=(60, 40, 50))
    img.save(path)


def make_bush(path):
    img, d = canvas(40, 24)
    d.ellipse((0, 6, 22, 24), fill=(46, 120, 50))
    d.ellipse((14, 2, 40, 24), fill=(56, 140, 58))
    d.ellipse((8, 0, 28, 18), fill=(70, 160, 66))
    for x, y in ((10, 6), (20, 4), (28, 10), (6, 14), (32, 16), (16, 12)):
        d.rectangle((x, y, x + 2, y + 2), fill=(240, 80, 120))
    img.save(path)


def main():
    concept_dir, project_dir = sys.argv[1], sys.argv[2]
    roadside = os.path.join(project_dir, "assets", "sprites", "roadside", "palm_coast")
    make_palms(concept_dir, roadside)
    make_background(concept_dir, os.path.join(project_dir, "assets", "sprites", "backgrounds", "palm_coast_far.png"))
    make_billboard(os.path.join(roadside, "billboard.png"))
    make_lifeguard(os.path.join(roadside, "lifeguard_tower.png"))
    make_umbrella(os.path.join(roadside, "umbrella.png"))
    make_lamp(os.path.join(roadside, "lamp_post.png"))
    make_hotel(os.path.join(roadside, "hotel.png"))
    make_bush(os.path.join(roadside, "bush.png"))


if __name__ == "__main__":
    main()
