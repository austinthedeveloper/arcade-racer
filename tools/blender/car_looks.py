"""What differs from car to car in tools/blender/render_car.py (CP-1). No Blender in here, so
the tests can read it.

forward: the axis the model's nose points along after import (Tripo's come in nose toward the
camera, -y).
glow_green: the green share of the red, (over, under), at which a texel counts as a lamp. The
lower limit of 0.05 keeps pure red out of the glow, for a red body like the Vega's; a car whose
lamps are the pure red ones and whose body isn't red takes 0 there (or less: "over" is strict).
glow_color: the hue a lamp glows in, red green blue; None for the texture's own.
hue: a turn of the paint's hue, in whole turns (the Bruiser's texture is purpler than its art).
cabin_wall: (y, half width, z0, z1), an invisible wall across the cabin that clears what's seen
through a model's glassless windows, in shares of its size, y from its middle toward the nose;
None for no wall (render_car.py, add_cabin_wall).
tilt: the camera's degrees below level. Steeper sits better on the road, until the bumper hides
the tires: the Bruiser's tail is long and its fenders deep, so it goes first.
"""

DEFAULTS = {"forward": "y", "glow_green": (0.05, 0.9), "glow_color": None, "hue": 0.0, "cabin_wall": None, "tilt": 15.0}
LOOKS = {
    "vega": {"forward": "-y"},
    "bruiser": {"forward": "-y", "glow_green": (-0.01, 0.9), "glow_color": (1.0, 0.015, 0.0), "hue": -0.04, "cabin_wall": (0.04, 0.3, 0.5, 0.9), "tilt": 9.0},
}


def look(car):
    """The settings for `car`, by its strip name; DEFAULTS for one not listed."""
    return {**DEFAULTS, **LOOKS.get(car, {})}
