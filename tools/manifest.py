#!/usr/bin/env python3
"""Write assets/sprites/manifest.json: every roadside sprite, road-spanning sprite and traffic
vehicle the game loads, with the numbers it needs to place and collide with them. The specs
in the make_*_sprites.py tools are the source; SpriteLibrary and CarSprites read this file.

Every sprite tool rewrites it after building. Run it on its own after changing a number in a
spec (a world height, a collide fraction) without rebuilding the art.

Usage:
    python3 tools/manifest.py <project_dir>
"""
import json
import os
import sys

PATH = os.path.join("assets", "sprites", "manifest.json")


def build(project_dir="."):
    """The manifest for the sprites in `project_dir`: a roadside sprite with reduced copies
    (spritelib.lod_steps of its height) lists them under "lod"."""
    # Imported here: the tools import this module too
    from make_car_sprites import TRAFFIC
    from make_drawn_props import DRAWN
    from make_span_sprites import SPANS, solid_part
    from make_stage_sprites import STAGES

    roadside = {}
    for name, (_, world_h, collide) in DRAWN.items():
        roadside[name] = {"file": "roadside/palm_coast/%s.png" % name, "world_h": world_h, "collide": collide}
    for stage, spec in STAGES.items():
        for _, _, objects, *_ in spec["sheets"]:
            for obj in objects:
                if obj is not None:
                    name, world_h, collide = obj
                    roadside[name] = {"file": "roadside/%s/%s.png" % (stage, name), "world_h": world_h,
                                      "collide": collide}
    spans = {}
    for name, (_, look) in SPANS.items():
        spans[name] = {"file": "spans/%s.png" % name, "fill": look.get("fill"),
                       "ceiling": look.get("ceiling", False), "banner": look.get("banner")}
        if solid_part(look) is not None:
            spans[name]["solid"] = solid_part(look)
    traffic = {}
    for _, _, world_per_px, names in TRAFFIC:
        for name in names:
            if name is not None:
                traffic[name] = {"file": "traffic/%s.png" % name, "world_per_px": world_per_px}
    for entry in roadside.values():
        steps = sprite_lods(project_dir, entry["file"])
        if steps:
            entry["lod"] = steps
    return {"roadside": roadside, "spans": spans, "traffic": traffic}


def sprite_lods(project_dir, file):
    """The reduced copies (CP-9) of a sprite in assets/sprites: the steps spritelib.lod_steps
    gives its height on disk that are written (tools/make_lod_sprites.py)."""
    from PIL import Image
    from spritelib import lod_path, lod_steps
    path = os.path.join(project_dir, "assets", "sprites", file)
    if not os.path.exists(path):
        return []
    with Image.open(path) as img:
        return [s for s in lod_steps(img.height) if os.path.exists(lod_path(path, s))]


def dumps(manifest):
    """One entry per line, so a change shows up as a one-line diff."""
    sections = []
    for key, entries in manifest.items():
        lines = ['    %s: %s' % (json.dumps(name), json.dumps(entry)) for name, entry in entries.items()]
        sections.append('  %s: {\n%s\n  }' % (json.dumps(key), ",\n".join(lines)))
    return "{\n%s\n}\n" % ",\n".join(sections)


def write(project_dir):
    path = os.path.join(project_dir, PATH)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(dumps(build(project_dir)))
    print("manifest", path)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    write(sys.argv[1])
