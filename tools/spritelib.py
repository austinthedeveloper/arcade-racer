"""Shared helpers for the sprite tools (make_*_sprites.py): keying the magenta background off
concept sheets, finding the objects on a sheet, cropping and scaling them to pixel art, and
turning a background composite into a seamless parallax strip.

Needs Pillow, numpy and scipy (tools/requirements.txt).
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

# 4-connected neighbourhood for labelling
FOUR = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]])


def rgba(img):
    """The image as an RGBA uint8 array (height, width, 4)."""
    return np.array(img.convert("RGBA"))


def is_key(arr):
    """Magenta key plus the pink fringe the generator leaves around edges, per pixel of an
    (..., 3+) array. Matches pink and purple paint too: car sheets use key_sheet instead."""
    r, g, b = (arr[..., i].astype(np.int16) for i in range(3))
    return ((r > 150) & (b > 150) & (g < 120)) | ((r - g > 90) & (b - g > 90))


def key_out(img):
    """Every key-colored pixel made transparent."""
    a = rgba(img)
    a[is_key(a)] = 0
    return Image.fromarray(a)


# --- Keying a sheet on its own background color (car and traffic sheets) -----------------

# Key color distance (sum of RGB differences) from the sheet's background that counts as
# background. The plain magenta key (is_key) also matches pink and purple paint, which left
# holes in the Cyclone and the Zenith.
KEY_DISTANCE = 90
# A background-colored patch inside a car is a gap to see through (between a buggy's tubes,
# under the Mesa's axle) if it is this close to the background on average, whatever its size,
# or if it is framed by dark parts: the median brightest channel of the pixels around it is
# under GAP_FRAME (thin gaps, like under the Mesa's light bar, are mostly shaded magenta).
# Paint is further off and sits in bright paint: the Zenith's iridescent purple averages 40
# or more and its surroundings 200 or more.
GAP_DISTANCE = 40
GAP_FRAME = 200


def _shifts(mask_shape):
    """(destination, source) slice pairs for the four neighbours of every pixel."""
    h, w = mask_shape
    return [
        ((slice(None), slice(0, w - 1)), (slice(None), slice(1, w))),
        ((slice(None), slice(1, w)), (slice(None), slice(0, w - 1))),
        ((slice(0, h - 1), slice(None)), (slice(1, h), slice(None))),
        ((slice(1, h), slice(None)), (slice(0, h - 1), slice(None))),
    ]


def _frame_medians(labels, near, bright, count):
    """Per label, the upper median of `bright` over the pixels that aren't `near` and touch
    the label (each pixel once)."""
    idx = np.arange(labels.size).reshape(labels.shape)
    pairs = []
    for dst, src in _shifts(labels.shape):
        hit = ~near[dst] & (labels[src] > 0)
        pairs.append(labels[src][hit].astype(np.int64) * labels.size + idx[dst][hit])
    pairs = np.unique(np.concatenate(pairs))
    lab = pairs // labels.size
    pix = pairs % labels.size
    vals = bright.reshape(-1)[pix]
    order = np.lexsort((vals, lab))
    lab, vals = lab[order], vals[order]
    medians = np.full(count + 1, 255, dtype=np.int32)
    starts = np.searchsorted(lab, np.arange(count + 1), side="left")
    ends = np.searchsorted(lab, np.arange(count + 1), side="right")
    for k in range(1, count + 1):
        n = ends[k] - starts[k]
        if n:
            medians[k] = vals[starts[k] + n // 2]
    return medians


def key_sheet(img, fringe=1):
    """Keys out the sheet's background color (read from its corner): every patch of it that
    touches the edge or is a real gap (GAP_DISTANCE, GAP_FRAME), plus up to `fringe` pixels
    of magenta-ish fringe around those (is_key, grown one pixel at a time). Pink or purple
    paint stays, unless it touches the background within `fringe` pixels."""
    a = rgba(img)
    h, w = a.shape[:2]
    bg = a[1, 1, :3].astype(np.int16)
    dist = np.abs(a[..., :3].astype(np.int16) - bg).sum(axis=2)
    near = dist < KEY_DISTANCE
    labels, count = ndimage.label(near, structure=FOUR)
    ids = np.arange(1, count + 1)
    edge = np.zeros(count + 1, dtype=bool)
    edge[np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))] = True
    mean = np.zeros(count + 1)
    if count:
        mean[1:] = ndimage.mean(dist, labels, ids)
    gap = mean < GAP_DISTANCE
    frame = _frame_medians(labels, near, a[..., :3].max(axis=2).astype(np.int32), count)
    gap |= frame < GAP_FRAME
    keep = edge | gap
    keep[0] = False
    keyed = keep[labels]
    keyish = is_key(a)
    for _ in range(fringe):
        grow = np.zeros_like(keyed)
        for dst, src in _shifts(keyed.shape):
            grow[dst] |= keyed[src]
        keyed |= grow & keyish
    a[keyed] = 0
    return Image.fromarray(a)


# --- Finding objects on a sheet -----------------------------------------------------------

def label_cells(img, step=2):
    """4-connected opaque regions on the alpha mask downsampled by `step`: (labels, count),
    labels numbered from 1 in raster order of their first cell, 0 for empty."""
    small = img.getchannel("A").resize((img.size[0] // step, img.size[1] // step), Image.NEAREST)
    return ndimage.label(np.array(small) > 0, structure=FOUR)


def components(img, step=2, min_area=400):
    """Connected opaque regions of at least `min_area` cells, left to right, as
    (full-res box, label) pairs, plus the label grid and its step."""
    labels, count = label_cells(img, step)
    out = []
    if count:
        areas = ndimage.sum(np.ones_like(labels), labels, np.arange(1, count + 1))
        for k, sl in enumerate(ndimage.find_objects(labels), start=1):
            if areas[k - 1] >= min_area:
                ys, xs = sl
                out.append(((xs.start * step, ys.start * step, xs.stop * step, ys.stop * step), k))
    return sorted(out, key=lambda b: b[0][0]), labels, step


def cell_boxes(labels):
    """Every label's box in cells and its area: [(x0, y0, x1, y1, area)], index = label - 1."""
    count = int(labels.max())
    if not count:
        return []
    areas = ndimage.sum(np.ones_like(labels), labels, np.arange(1, count + 1))
    return [(xs.start, ys.start, xs.stop, ys.stop, int(areas[k]))
            for k, (ys, xs) in enumerate(ndimage.find_objects(labels))]


def mask_crop(img, box, labels, step, members):
    """`img` cropped to `box` (full-res), keeping only pixels whose label cell is one of
    `members`, then trimmed to what is left."""
    part = rgba(img.crop(box))
    ph, pw = part.shape[:2]
    full = np.zeros((ph, pw), dtype=labels.dtype)
    ys = (box[1] + np.arange(ph)) // step
    xs = (box[0] + np.arange(pw)) // step
    oky, okx = ys < labels.shape[0], xs < labels.shape[1]
    sub = labels[np.ix_(ys[oky], xs[okx])]
    full[np.ix_(np.nonzero(oky)[0], np.nonzero(okx)[0])] = sub
    part[~np.isin(full, list(members))] = 0
    out = Image.fromarray(part)
    return out.crop(out.getbbox())


def overlap(a, b):
    """Area of the intersection of two boxes over the smaller box's area."""
    ix = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    smaller = min((a[2] - a[0]) * (a[3] - a[1]), (b[2] - b[0]) * (b[3] - b[1]))
    return ix * iy / max(1, smaller)


def union(a, b):
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


def group_objects(boxes, min_area=400):
    """Groups components into objects: big components seed objects, and every other
    component (pebbles, grass tufts, a detached sign) joins the object whose box holds most
    of it. Members are indexes into `boxes`."""
    seeds = [i for i, b in enumerate(boxes) if b[4] >= min_area]
    # Two big components that mostly overlap are one object (a sign above its posts)
    groups = []
    for i in sorted(seeds, key=lambda i: -boxes[i][4]):
        for g in groups:
            if overlap(g["box"], boxes[i]) > 0.5:
                g["members"].append(i)
                g["box"] = union(g["box"], boxes[i])
                break
        else:
            groups.append({"members": [i], "box": boxes[i][:4]})
    for i, b in enumerate(boxes):
        if i in seeds:
            continue
        best = max(groups, key=lambda g: overlap(g["box"], b), default=None)
        if best is not None and overlap(best["box"], b) > 0.5:
            best["members"].append(i)
    _merge_stacked(groups)
    return in_reading_order(groups)


def _merge_stacked(groups, max_gap=12):
    """Joins a part that sits on top of or under another part (a sign on its pole, a
    dome on its tower): one box's columns lie mostly within the other's, with at most a
    small vertical gap between them. Boxes are in label-grid cells (half the sheet's pixels)."""
    merged = True
    while merged:
        merged = False
        for a in groups:
            for b in groups:
                if a is b:
                    continue
                ax0, ay0, ax1, ay1 = a["box"]
                bx0, by0, bx1, by1 = b["box"]
                shared = min(ax1, bx1) - max(ax0, bx0)
                narrower = min(ax1 - ax0, bx1 - bx0)
                gap = max(ay0, by0) - min(ay1, by1)
                if shared > 0.8 * narrower and gap < max_gap:
                    a["members"] += b["members"]
                    a["box"] = union(a["box"], b["box"])
                    groups.remove(b)
                    merged = True
                    break
            if merged:
                break


def in_reading_order(groups):
    """Rows top to bottom (a row is every object overlapping the one above it vertically),
    left to right within a row."""
    rows = []
    for g in sorted(groups, key=lambda g: g["box"][1]):
        if rows and g["box"][1] < rows[-1]["bottom"]:
            rows[-1]["items"].append(g)
            rows[-1]["bottom"] = max(rows[-1]["bottom"], g["box"][3])
        else:
            rows.append({"items": [g], "bottom": g["box"][3]})
    return [g for row in rows for g in sorted(row["items"], key=lambda g: g["box"][0])]


def slice_row(keyed, shape=None):
    """A keyed sheet's big objects (components) left to right, each trimmed, with pixels of
    its neighbours inside its box cleared. For sheets of one row: cars, the palms. `shape`,
    if given, is the same sheet keyed more lightly: objects are found on it, so a part that
    `keyed` cut loose (a mirror on a stalk of fringe) still belongs to its object."""
    boxes, labels, step = components(keyed if shape is None else shape)
    return [mask_crop(keyed, box, labels, step, {comp}) for box, comp in boxes]


def slice_objects(path, names, target_height, row=False):
    """A sheet of objects on magenta (roadside props, power-ups), keyed and cut into one
    sprite per object in reading order, scaled so the tallest is `target_height` pixels.
    [(name, sprite)]; a None name is still cut (so the rest line up) but meant to be skipped.
    `row`: cut with slice_row instead, for a single row whose objects overlap (the palms)."""
    keyed = key_out(Image.open(path))
    if row:
        crops = slice_row(keyed)
        if len(crops) != len(names):
            raise SystemExit("%s: found %d objects, expected %d (%s)" % (path, len(crops), len(names), names))
        scale = target_height / max(c.height for c in crops)
        return [(name, pixelate_down(c, scale)) for name, c in zip(names, crops)]
    labels, step = label_cells(keyed)[0], 2
    boxes = cell_boxes(labels)
    groups = group_objects(boxes)
    if len(groups) != len(names):
        raise SystemExit("%s: found %d objects, expected %d (%s)" % (path, len(groups), len(names), names))
    crops = [mask_crop(keyed, tuple(v * step for v in g["box"]), labels, step, {m + 1 for m in g["members"]})
             for g in groups]
    scale = target_height / max(c.height for c in crops)
    return [(name, pixelate_down(c, scale)) for name, c in zip(names, crops)]


# --- Scaling and backgrounds --------------------------------------------------------------

def hard_alpha(img, threshold):
    """Alpha at or above `threshold` made opaque, the rest cleared to (0, 0, 0, 0)."""
    a = rgba(img)
    solid = a[..., 3] >= threshold
    a[solid, 3] = 255
    a[~solid] = 0
    return Image.fromarray(a)


def pixelate_down(img, scale):
    """Scaled down by box filtering, with hard alpha edges."""
    w, h = img.size
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    return hard_alpha(img.convert("RGBA").resize((nw, nh), Image.BOX), 140)


def make_background(path, horizon, out_path, width=1280, colors=96):
    """The composite above its horizon row as a seamless strip: scaled to `width`, then
    followed by its mirror image so the ends meet."""
    src = Image.open(path).convert("RGB")
    strip = src.crop((0, 0, src.width, horizon))
    height = round(strip.height * width / strip.width)
    strip = strip.resize((width, height), Image.BOX)
    seamless = Image.new("RGB", (width * 2, height))
    seamless.paste(strip, (0, 0))
    seamless.paste(strip.transpose(Image.FLIP_LEFT_RIGHT), (width, 0))
    seamless = seamless.quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    seamless.save(out_path)
    print("background", out_path, seamless.size)
