"""Self-tests for tools/colorblind.py (run by tools/test.sh)."""

import re
import unittest
from pathlib import Path

from PIL import Image

import colorblind


class ColorblindTest(unittest.TestCase):
    def test_greys_stay_grey(self):
        img = Image.new("RGB", (3, 1))
        img.putpixel((0, 0), (0, 0, 0))
        img.putpixel((1, 0), (128, 128, 128))
        img.putpixel((2, 0), (255, 255, 255))
        for name in colorblind.MATRICES:
            sim = colorblind.simulate(img, name)
            for x in range(3):
                a, b = img.getpixel((x, 0)), sim.getpixel((x, 0))
                self.assertTrue(all(abs(p - q) <= 2 for p, q in zip(a, b)), f"{name}: {a} -> {b}")

    def test_red_and_green_run_together_for_deuteranopia(self):
        img = Image.new("RGB", (2, 1))
        img.putpixel((0, 0), (208, 48, 48))
        img.putpixel((1, 0), (106, 138, 32))
        sim = colorblind.simulate(img, "deuteranopia")
        before = sum((p - q) ** 2 for p, q in zip(img.getpixel((0, 0)), img.getpixel((1, 0)))) ** 0.5
        after = sum((p - q) ** 2 for p, q in zip(sim.getpixel((0, 0)), sim.getpixel((1, 0)))) ** 0.5
        self.assertLess(after, before * 0.5)

    def test_same_matrices_as_the_game(self):
        gd = (Path(__file__).parent.parent / "scripts/ui/color_vision.gd").read_text()
        numbers = [float(n) for n in re.findall(r"-?\d+\.\d{6}", gd)]
        ours = [v for name in ("protanopia", "deuteranopia", "tritanopia") for row in colorblind.MATRICES[name] for v in row]
        self.assertEqual(numbers, ours)


if __name__ == "__main__":
    unittest.main()
