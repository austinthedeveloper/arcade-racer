"""Self-tests for the sprite tools' shared helpers (spritelib.py), on small made-up images.

    python3 -m unittest discover -s tools -p "test_*.py"

tools/test.sh runs them when Pillow, numpy and scipy are installed.
"""
import os
import tempfile
import unittest

import numpy as np
from PIL import Image

import spritelib as sl

MAGENTA = (255, 0, 255, 255)


def sheet(size, rects, bg=MAGENTA):
    """A sheet of `size` on `bg` with each (box, color) in `rects` filled in."""
    img = Image.new("RGBA", size, bg)
    for box, color in rects:
        img.paste(color, box)
    return img


class Keying(unittest.TestCase):
    def test_is_key_matches_magenta_and_its_fringe_only(self):
        px = np.array([[[255, 0, 255], [200, 60, 190], [255, 255, 255], [20, 200, 40], [255, 140, 0]]])
        self.assertEqual(sl.is_key(px).tolist(), [[True, True, False, False, False]])

    def test_key_out_clears_the_key(self):
        a = sl.rgba(sl.key_out(sheet((8, 4), [((2, 0, 4, 4), (10, 200, 40, 255))])))
        self.assertEqual(a[0, 0].tolist(), [0, 0, 0, 0])
        self.assertEqual(a[0, 2].tolist(), [10, 200, 40, 255])

    def test_near_key_hue_wants_the_hue_and_some_color(self):
        # shadowed magenta, violet paint, dark grey, red
        px = np.array([[[90, 20, 92], [120, 60, 220], [40, 30, 40], [200, 20, 20]]])
        self.assertEqual(sl.near_key_hue(px, MAGENTA).tolist(), [[True, False, False, False]])

    def test_key_sheet_peels_a_shadowed_key_line_two_pixels_deep(self):
        # A green car with a two-pixel line of dark magenta under it, then a third row of it
        rows = [((4, 4, 12, 8), (20, 160, 40, 255)), ((4, 8, 12, 11), (90, 20, 92, 255))]
        a = sl.rgba(sl.key_sheet(sheet((16, 16), rows), fringe=0, spill=0))
        self.assertEqual(a[9:11, 6, 3].tolist(), [0, 0], "two pixels in from the background")
        self.assertEqual(a[8, 6, 3], 255, "the third stays")
        self.assertEqual(a[6, 6].tolist(), [20, 160, 40, 255], "the car stays")

    def test_despill_neutralises_a_pink_outline_only_near_the_background(self):
        # A grey car whose outline pixel and next one in carry magenta spill
        rows = [((2, 2, 14, 14), (120, 120, 120, 255)), ((2, 2, 14, 3), (150, 100, 140, 255)),
                ((2, 6, 14, 7), (150, 100, 140, 255))]
        a = sl.rgba(sl.key_sheet(sheet((16, 16), rows), fringe=0, hue_fringe=0, spill=2))
        self.assertEqual(a[2, 8].tolist(), [110, 100, 100, 255], "red and blue drop to green's level")
        self.assertEqual(a[6, 8].tolist(), [150, 100, 140, 255], "further in it is paint")

    def test_despill_leaves_blue_and_red(self):
        a = np.array([[[60, 90, 200, 255], [200, 30, 30, 255]]], dtype=np.uint8)
        sl.despill(a, np.ones((1, 2), dtype=bool))
        self.assertEqual(a[0, :, :3].tolist(), [[60, 90, 200], [200, 30, 30]])

    def test_recolor_hue_turns_purple_in_the_box_only(self):
        img = sheet((4, 2), [((0, 0, 4, 2), (160, 40, 220, 255)), ((3, 0, 4, 2), (230, 200, 30, 255))])
        a = sl.rgba(sl.recolor_hue(img, (0.0, 0.0, 1.0, 0.5), (240, 340), 212))
        h, c = sl.hue(a)
        self.assertAlmostEqual(h[0, 0], 212, delta=2)
        self.assertEqual(a[0, 0, :3].max(), 220, "brightness kept")
        self.assertEqual(a[1, 0].tolist(), [160, 40, 220, 255], "outside the box")
        self.assertEqual(a[0, 3].tolist(), [230, 200, 30, 255], "yellow is not in the hue range")

    def test_hard_alpha_is_all_or_nothing(self):
        img = Image.new("RGBA", (3, 1))
        img.putdata([(9, 9, 9, 10), (9, 9, 9, 140), (9, 9, 9, 255)])
        a = sl.rgba(sl.hard_alpha(img, 140))
        self.assertEqual(a[0, :, 3].tolist(), [0, 255, 255])
        self.assertEqual(a[0, 0].tolist(), [0, 0, 0, 0])


class Boxes(unittest.TestCase):
    def test_overlap_is_over_the_smaller_box(self):
        self.assertEqual(sl.overlap((0, 0, 10, 10), (2, 2, 4, 4)), 1.0)
        self.assertEqual(sl.overlap((0, 0, 10, 10), (5, 0, 15, 10)), 0.5)
        self.assertEqual(sl.overlap((0, 0, 2, 2), (5, 5, 6, 6)), 0.0)

    def test_union(self):
        self.assertEqual(sl.union((0, 5, 4, 8), (2, 1, 9, 6)), (0, 1, 9, 8))

    def test_reading_order_is_rows_then_left_to_right(self):
        g = lambda *box: {"box": box}
        groups = [g(50, 0, 60, 10), g(0, 40, 10, 50), g(0, 2, 10, 12), g(30, 41, 40, 52)]
        order = [x["box"] for x in sl.in_reading_order(groups)]
        self.assertEqual(order, [(0, 2, 10, 12), (50, 0, 60, 10), (0, 40, 10, 50), (30, 41, 40, 52)])


class Scaling(unittest.TestCase):
    def test_pixelate_down_scales_and_keeps_hard_edges(self):
        out = sl.pixelate_down(sheet((40, 20), [((0, 0, 20, 20), (200, 0, 0, 255))], bg=(0, 0, 0, 0)), 0.25)
        self.assertEqual(out.size, (10, 5))
        self.assertTrue(set(np.array(out)[..., 3].ravel().tolist()) <= {0, 255})

    def test_pixelate_down_never_goes_below_a_pixel(self):
        self.assertEqual(sl.pixelate_down(Image.new("RGBA", (3, 3)), 0.01).size, (1, 1))


class Slicing(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.dir.cleanup()

    def test_slice_objects_cuts_in_reading_order_and_scales_to_the_tallest(self):
        path = os.path.join(self.dir.name, "sheet.png")
        sheet((400, 200), [((220, 20, 300, 180), (0, 160, 60, 255)),  # tall, on the right
                           ((20, 100, 120, 160), (230, 200, 30, 255))]).save(path)  # short, on the left
        out = sl.slice_objects(path, ["sign", "tree"], 40)
        self.assertEqual([name for name, _ in out], ["sign", "tree"])
        sign, tree = out[0][1], out[1][1]
        self.assertEqual(tree.size, (20, 40))
        self.assertEqual(sign.size, (25, 15))
        self.assertEqual(np.array(tree)[20, 10].tolist(), [0, 160, 60, 255])

    def test_slice_objects_wants_the_named_count(self):
        path = os.path.join(self.dir.name, "one.png")
        sheet((200, 200), [((40, 40, 160, 160), (0, 0, 200, 255))]).save(path)
        with self.assertRaises(SystemExit):
            sl.slice_objects(path, ["a", "b"], 40)

    def test_make_background_is_a_mirrored_strip(self):
        src = os.path.join(self.dir.name, "composite.png")
        img = Image.new("RGB", (200, 100), (10, 20, 30))
        img.paste((250, 250, 0), (0, 0, 20, 50))  # a mark at the left, above the horizon
        img.save(src)
        out = os.path.join(self.dir.name, "bg", "far.png")
        sl.make_background(src, 50, out, width=100, colors=8)
        strip = np.array(Image.open(out).convert("RGB")).astype(int)
        self.assertEqual(strip.shape, (25, 200, 3))
        self.assertTrue((strip[:, :100] == strip[:, 100:][:, ::-1]).all(), "the second half mirrors the first")
        self.assertLess(np.abs(strip[10, 0] - [250, 250, 0]).max(), 30, "the mark kept its color")


class Cli(unittest.TestCase):
    def test_cli_args_checks_the_count(self):
        self.assertEqual(sl.cli_args("usage", 2, argv=["a", "b"]), ["a", "b"])
        with self.assertRaises(SystemExit):
            sl.cli_args("usage", 2, argv=["a"])
        with self.assertRaises(SystemExit):
            sl.cli_args("usage", 2, argv=["a", "b", "c"])
        self.assertEqual(sl.cli_args("usage", 2, more=True, argv=["a", "b", "c"]), ["a", "b", "c"])
        with self.assertRaises(SystemExit):
            sl.cli_args("usage", 2, more=True, argv=["a"])

    def test_sprite_dir_makes_the_folder(self):
        with tempfile.TemporaryDirectory() as project:
            path = sl.sprite_dir(project, "roadside", "neon")
            self.assertEqual(path, os.path.join(project, "assets", "sprites", "roadside", "neon"))
            self.assertTrue(os.path.isdir(path))
            self.assertEqual(sl.sprite_dir(project, "roadside", "neon"), path, "already there is fine")


class LevelOfDetail(unittest.TestCase):
    def test_lod_steps_for_tall_sprites_only(self):
        self.assertEqual(sl.lod_steps(40), [], "short: none")
        self.assertEqual(sl.lod_steps(64), [2, 4], "tall: a half and a quarter")
        self.assertEqual(sl.lod_steps(200), [2, 4])

    def test_reduce_averages_with_alpha_weighting(self):
        # A red square on a transparent black surround: halved, its edge pixels mix only red
        img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        img.paste((255, 0, 0, 255), (1, 1, 7, 7))
        small = np.array(sl.reduce_sprite(img, 2))
        self.assertEqual(small.shape[:2], (4, 4))
        solid = small[..., 3] == 255
        self.assertFalse(solid[0, 0], "a quarter-covered corner (alpha 64, under LOD_ALPHA) drops")
        self.assertTrue((small[solid][:, :3] == [255, 0, 0]).all(), "no darkening from the transparent surround")
        self.assertTrue(((small[..., 3] == 0) | (small[..., 3] == 255)).all(), "hard alpha")
        self.assertTrue(solid[1:3, 1:3].all(), "the middle stays solid")

    def test_reduce_averages_colors(self):
        img = Image.new("RGBA", (2, 2), (0, 0, 0, 255))
        img.paste((200, 100, 0, 255), (0, 0, 1, 2))
        self.assertEqual(tuple(np.array(sl.reduce_sprite(img, 2))[0, 0]), (100, 50, 0, 255), "a box average")

    def test_write_lods_beside_the_sprite_and_clears_stale_ones(self):
        with tempfile.TemporaryDirectory() as d:
            tall = os.path.join(d, "palm.png")
            Image.new("RGBA", (30, 100), (0, 200, 0, 255)).save(tall)
            self.assertEqual(sl.write_lods(tall), [2, 4])
            self.assertEqual(Image.open(sl.lod_path(tall, 2)).size, (15, 50))
            self.assertEqual(Image.open(sl.lod_path(tall, 4)).size, (8, 25))
            self.assertEqual(sl.lod_path(tall, 4), os.path.join(d, "lod", "palm_4.png"))
            Image.new("RGBA", (30, 40), (0, 200, 0, 255)).save(tall)  # rebuilt short
            self.assertEqual(sl.write_lods(tall), [])
            self.assertFalse(os.path.exists(sl.lod_path(tall, 2)), "stale copies removed")


if __name__ == "__main__":
    unittest.main()
