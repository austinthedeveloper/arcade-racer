"""What differs from car to car in tools/blender/render_car.py (CP-1). No Blender in here, so
the tests can read it.

forward: the axis the model's nose points along after import (Tripo's come in nose toward the
camera, -y).
glow_green: the green share of the red, (over, under), at which a texel counts as a lamp. It has to
fit the car, or the paint lights up too. The default's 0.05 keeps pure red out, for a red body like
the Vega's. Its 0.9 takes in orange and amber, so an orange or yellow body wants RED_ONLY; a body
with no red or yellow in it wants ANY_RED; a car with no lamps to speak of, NO_LAMPS.
glow_blue: how much blue a lamp texel may have, as a share of its red; a washed-out lamp wants more.
glow_color: the hue a lamp glows in, red green blue; None for the texture's own.
hue: a turn of the paint's hue, in whole turns (the Bruiser's texture is purpler than its art).
saturation, gamma: how much richer the paint goes. Gamma works channel by channel, so it deepens
a saturated blue well but turns orange red; leave it at 1 on anything warm.
neutral: the saturation under which a texel is chrome or white, fading out by the second number,
and keeps no color. A pastel paint needs it low, or it goes grey.
hue_band: a color the model got wrong, moved in the strip pass: {"hues": (from, to), "by",
"saturation"}, degrees (red 0, yellow 60, green 120, blue 240), "by" a turn, saturation a multiple.
Only that band moves, so red stripes and lamps stay red; a turn of `hue` would take them to pink.
exposure: in stops. The sun is bright enough for dark paint; a light one clips past white, and
beige goes yellow.
cabin_wall: (y, half width, z0, z1), an invisible wall across the cabin that clears what's seen
through a model's glassless windows, in shares of its size, y from its middle toward the nose;
None for no wall (render_car.py, add_cabin_wall).
raise_part: a part to lift, as the concept art does, when it would hide behind the car at this
camera: {"half_width", "y": (from, to), "z", "by", "ramp"}, shares of the car's size, x and y from
its middle (+y toward the nose), z and by from the ground up. Everything in that box above z goes
up by `by`, easing in over the first `ramp` above z so the part stretches, not tears. None: no part.
remove_part: a part to cut out of the model, {"x": (from, to), "y": ..., "z": ...}, shares of the car's
size as in raise_part; the Skipper's views show its flag mirrored, so Tripo built two.
tilt: the camera's degrees below level. Steeper sits better on the road, until the bumper hides
the tires: the Bruiser's tail is long and its fenders deep, so it goes first.
"""

RED_ONLY = (-0.01, 0.12)
ANY_RED = (-0.01, 0.9)
NO_LAMPS = (2.0, 3.0)
RED_LAMP = (1.0, 0.012, 0.0)  # glow_color; green goes up fast at this strength, past red to orange

DEFAULTS = {"forward": "y", "glow_green": (0.05, 0.9), "glow_blue": 0.2, "glow_color": None, "hue": 0.0, "saturation": 1.15, "gamma": 1.0,
            "neutral": (0.08, 0.18), "exposure": -0.5, "hue_band": None, "raise_part": None, "remove_part": None, "cabin_wall": None, "tilt": 15.0}
LOOKS = {
    "vega": {"forward": "-y", "tilt": 7.0, "saturation": 1.35, "gamma": 1.4, "exposure": -0.25},
    **{car: {"forward": "-y", **extra} for car, extra in {
        "kestrel": {"tilt": 7.0, "glow_green": RED_ONLY, "glow_color": RED_LAMP, "hue_band": {"hues": (45.0, 80.0), "by": -20.0}},
        "sol": {"tilt": 7.0, "saturation": 1.4, "glow_green": ANY_RED, "glow_color": RED_LAMP},
        "mesa": {"tilt": 9.0, "glow_green": RED_ONLY, "glow_color": RED_LAMP},
        "phantom": {"tilt": 7.0, "glow_green": ANY_RED, "glow_color": RED_LAMP},
        "tempest": {"tilt": 7.0, "saturation": 1.3, "exposure": 0.0, "glow_green": ANY_RED, "glow_color": RED_LAMP,
                    "hue_band": {"hues": (90.0, 140.0), "by": -30.0, "saturation": 1.35}},
        "skipper": {"tilt": 9.0, "saturation": 1.3, "glow_green": NO_LAMPS,
                    "remove_part": {"x": (-1.0, 1.0), "y": (0.0, 1.0), "z": (0.72, 2.0)}},
        "halo": {"tilt": 5.0, "saturation": 0.8, "glow_green": ANY_RED, "glow_blue": 0.75, "glow_color": RED_LAMP},
        "cyclone": {"tilt": 9.0, "saturation": 1.6, "exposure": 0.35},
        "hauler": {"tilt": 5.0, "exposure": -0.5, "glow_green": (0.3, 0.7),
                   "hue_band": {"hues": (45.0, 80.0), "by": -25.0, "saturation": 0.7}},
        "zenith": {"tilt": 7.0, "saturation": 1.4, "exposure": 0.0, "glow_green": ANY_RED, "glow_color": RED_LAMP},
    }.items()},
    "bruiser": {"forward": "-y", "glow_green": (-0.01, 0.9), "glow_color": (1.0, 0.015, 0.0), "hue": -0.04, "saturation": 1.6, "gamma": 1.7,
                "neutral": (0.25, 0.45), "exposure": 0.0, "cabin_wall": (0.04, 0.3, 0.5, 0.9),
                "raise_part": {"half_width": 0.14, "y": (0.2, 0.38), "z": 0.68, "by": 0.1, "ramp": 0.06},
                "tilt": 9.0},
}


def part_lift(x, y, z, part):
    """How far `part` (raise_part) lifts a vertex at (x, y, z), all shares of the car's size:
    0 outside its box, `by` once `ramp` above its floor."""
    if abs(x) > part["half_width"] or not part["y"][0] <= y <= part["y"][1] or z <= part["z"]:
        return 0.0
    return part["by"] * min(1.0, (z - part["z"]) / part["ramp"])


def in_part(x, y, z, part):
    """Whether a vertex at (x, y, z), shares of the car's size, is inside remove_part's box."""
    return part["x"][0] <= x <= part["x"][1] and part["y"][0] <= y <= part["y"][1] and part["z"][0] <= z <= part["z"][1]


def look(car):
    """The settings for `car`, by its strip name; DEFAULTS for one not listed."""
    return {**DEFAULTS, **LOOKS.get(car, {})}
