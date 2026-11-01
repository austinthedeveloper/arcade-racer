#!/usr/bin/env python3
"""Build the power-up sprites from the round 4/5 concept sheets (assets/prompts/powerups).

- Road pickups: nitro can, time clock, ram plate, ghost, and the spinning mystery hubcap.
- HUD icons for the held slot, and the empty slot frame.
- Effects: the pickup sparkle, the ram impact, the clock burst, and the hubcap reveal.

Usage:
    python3 tools/make_powerup_sprites.py <concept_dir> <project_dir>
"""
import os

from spritelib import cli_args, slice_objects, sprite_dir

# (sheet, texture height of its tallest piece, names in reading order; None skips a piece)
SHEETS = [
    ("pu01_pickups_A_v1.png", 72, ["pickup_nitro", "pickup_clock", "pickup_ram", "pickup_ghost", None]),
    ("pu01_mystery_A_v2.png", 72, ["pickup_mystery_1", "pickup_mystery_2", "pickup_mystery_3"]),
    ("pu02_icons_A_v2.png", 30, ["icon_nitro", "icon_clock", "icon_ram", "icon_ghost", "icon_mystery", "icon_slot"]),
    ("pu03_effects_A_v1.png", 96, ["fx_sparkle", "fx_ram", None, None, None, "fx_clock"]),
    ("pu04_hubcap_reveal_A_v2.png", 72, ["reveal_1", "reveal_2", "reveal_3", "reveal_4", None, None]),
]


def main():
    concept_dir, project_dir = cli_args(__doc__, 2)
    out_dir = sprite_dir(project_dir, "powerups")
    for sheet, height, names in SHEETS:
        for name, sprite in slice_objects(os.path.join(concept_dir, "powerups", sheet), names, height):
            if name is None:
                continue
            sprite.save(os.path.join(out_dir, name + ".png"))
            print(name, sprite.size)


if __name__ == "__main__":
    main()
