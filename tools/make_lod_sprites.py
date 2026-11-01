#!/usr/bin/env python3
"""Write the reduced copies (CP-9, spritelib.write_lods) of every roadside sprite in the
manifest from the sprites as they are, then rewrite the manifest. make_stage_sprites.py and
make_drawn_props.py write them as they build; this redoes them without the concept sheets,
after a change to the LOD numbers or filter in spritelib.py.

Usage:
    python3 tools/make_lod_sprites.py <project_dir>
"""
import json
import os

import manifest
from spritelib import cli_args, write_lods


def main():
    (project_dir,) = cli_args(__doc__, 1)
    with open(os.path.join(project_dir, manifest.PATH)) as f:
        roadside = json.load(f)["roadside"]
    count = 0
    for name, entry in roadside.items():
        steps = write_lods(os.path.join(project_dir, "assets", "sprites", entry["file"]))
        count += len(steps)
        if steps:
            print(name, steps)
    print(count, "reduced copies")
    manifest.write(project_dir)


if __name__ == "__main__":
    main()
