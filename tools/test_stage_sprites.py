"""Self-tests for make_stage_sprites.py's background layers, on small made-up images.

    python3 -m unittest discover -s tools -p "test_*.py"
"""
import os
import tempfile
import unittest

import numpy as np
from PIL import Image

import make_stage_sprites as ms


def gradient_sky(size):
    """A smooth top-to-bottom sky, purple to orange."""
    w, h = size
    t = np.linspace(0, 1, h)[:, None]
    rgb = np.stack([80 + 170 * t, 30 + 100 * t, 150 - 120 * t], axis=2).repeat(w, axis=1)
    return rgb.astype(np.uint8)


class Layers(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.dir.cleanup()

    def test_key_sky_keeps_the_city_and_drops_what_floats(self):
        a = gradient_sky((60, 40))
        a[25:, 10:30] = (20, 30, 90)  # a block of towers standing on the bottom edge
        a[18:25, 15:18] = (240, 220, 120)  # a lit spire on top of it
        a[5:8, 40:44] = (255, 255, 255)  # a firework in the sky
        keyed = np.array(ms.key_sky(Image.fromarray(a)))
        alpha = keyed[..., 3]
        self.assertEqual(alpha[2, 2], 0, "sky")
        self.assertEqual(alpha[30, 20], 255, "the towers")
        self.assertEqual(alpha[20, 16], 255, "the spire on them")
        self.assertEqual(alpha[6, 41], 0, "the firework floats, so it goes")
        self.assertEqual(alpha[30, 50], 0, "sky down to the bottom beside the towers")

    def test_layers_are_mirrored_strips_cropped_to_their_content(self):
        path = os.path.join(self.dir.name, "far.png")
        img = Image.new("RGB", (400, 200), (255, 0, 255))
        img.paste((40, 90, 40), (0, 120, 400, 200))  # hills along the bottom
        img.paste((90, 60, 30), (20, 80, 60, 120))  # a barn on them, at the left
        img.save(path)
        strip = ms.cut_layer(path, "far", key="sheet")
        width = ms.LAYER_WIDTH["far"]
        self.assertEqual(strip.shape[1], 2 * width, "the art then its mirror")
        self.assertEqual(strip.shape[0], round(120 * width / 400), "cropped from the barn's roof down")
        self.assertTrue((strip[:, :width] == strip[:, width:][:, ::-1]).all(), "the second half mirrors the first")
        self.assertEqual(strip[0, -1, 3], 0, "magenta keyed out")
        self.assertEqual(strip[-1, 0, 3], 255, "the hills are solid")

    def test_the_sky_is_opaque_and_a_fixed_height(self):
        path = os.path.join(self.dir.name, "sky.png")
        Image.fromarray(gradient_sky((300, 100))).save(path)
        strip = ms.cut_layer(path, "sky")
        self.assertEqual(strip.shape[:2], (ms.SKY_HEIGHT, 2 * 3 * ms.SKY_HEIGHT))
        self.assertTrue((strip[..., 3] == 255).all())

    def test_every_stage_has_the_three_layers(self):
        for stage, spec in ms.STAGES.items():
            if "background" in spec:
                self.assertEqual(set(spec["background"]), set(ms.LAYERS), stage)


if __name__ == "__main__":
    unittest.main()
