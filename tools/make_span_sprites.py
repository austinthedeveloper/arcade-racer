#!/usr/bin/env python3
"""Build the road-spanning sprites (tunnels, bridges, arches, race gates) from their
concept images (assets/prompts/roadside/drive-through.md and shared.md).

Each concept image holds one piece, straight-on, with the opening the road runs through
keyed out. The game finds the opening itself (SpriteLibrary.find_opening), so this only
keys, crops and scales.

Usage:
    python3 tools/make_span_sprites.py <concept_dir> <project_dir>
"""
import os
import sys

from PIL import Image

import manifest
from spritelib import key_out, pixelate_down

WIDTH = 640  # texture width; a span fills the screen when the car is under it

# output id: (concept file in roadside/, how the game draws it). The game reads the second
# part from the manifest (tools/manifest.py): "fill" is the color beside the span (and above
# it, for a "ceiling" like a tunnel ring); "banner" is where gate text goes, as fractions of
# the sprite (x, y, w, h).
SPANS = {
    "neon_tunnel": ("dt_neon_tunnel_entrance_A_v1.png", {"fill": "#140b26"}),
    "neon_tunnel_ring": ("dt_neon_tunnel_ring_A_v1.png", {"fill": "#140b26", "ceiling": True}),
    "neon_gantry": ("dt_neon_gantry_A_v1.png", {}),
    "covered_bridge": ("dt_timber_bridge_entrance_A_v1.png", {}),
    "covered_bridge_truss": ("dt_timber_bridge_truss_A_v1.png", {"fill": "#2a1a10", "ceiling": True}),
    "redrock_arch": ("dt_redrock_arch_A_v1.png", {}),
    "bayou_truss": ("dt_bayou_truss_A_v1.png", {}),
    "harvest_trestle": ("dt_harvest_trestle_A_v1.png", {}),
    "thunder_overpass": ("dt_thunder_overpass_A_v1.png", {}),
    "skyline_pylon": ("dt_skyline_pylon_A_v2.png", {}),
    "palm_arch": ("dt_palm_arch_A_v1.png", {}),
    "checkpoint_gate": ("shared_checkpoint_gate_A_v1.png", {"banner": [0.2, 0.09, 0.6, 0.2]}),
    "start_gantry": ("shared_start_gantry_A_v1.png", {"banner": [0.27, 0.33, 0.46, 0.13]}),
    "finish_gantry": ("skyline_finish_A_v1.png", {}),
}


def make_span(path, out_path):
    keyed = key_out(Image.open(path))
    keyed = keyed.crop(keyed.getbbox())
    sprite = pixelate_down(keyed, WIDTH / keyed.width)
    sprite = sprite.crop(sprite.getbbox())
    sprite.save(out_path)
    print("span", os.path.basename(out_path), sprite.size)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    concept_dir, project_dir = sys.argv[1], sys.argv[2]
    out_dir = os.path.join(project_dir, "assets", "sprites", "spans")
    os.makedirs(out_dir, exist_ok=True)
    for name, (src, _) in SPANS.items():
        make_span(os.path.join(concept_dir, "roadside", src), os.path.join(out_dir, name + ".png"))
    manifest.write(project_dir)


if __name__ == "__main__":
    main()
