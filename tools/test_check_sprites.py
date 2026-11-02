"""Self-tests for tools/check_sprites.py (EQ-19): pictures are compared by pixel, not byte.

    python3 -m unittest discover -s tools -p "test_*.py"
"""
import io
import unittest

from PIL import Image

import check_sprites as cs


def png(img, level=6):
    buf = io.BytesIO()
    img.save(buf, "PNG", compress_level=level)
    return buf.getvalue()


def picture(size=(6, 4), color=(200, 40, 90, 255)):
    return Image.new("RGBA", size, color)


class PixelDiff(unittest.TestCase):
    def test_same_pixels_in_other_bytes_match(self):
        a, b = png(picture(), 1), png(picture(), 9)
        self.assertNotEqual(a, b)
        self.assertIsNone(cs.pixel_diff(a, b))

    def test_one_level_off_still_matches(self):
        # macOS and Linux round a few pixels one level apart with the same libraries
        img = picture()
        img.putpixel((3, 2), (201, 40, 90, 255))
        self.assertIsNone(cs.pixel_diff(png(picture()), png(img)))

    def test_one_pixel_two_levels_off_differs(self):
        img = picture()
        img.putpixel((3, 2), (202, 40, 90, 255))
        self.assertEqual(cs.pixel_diff(png(picture()), png(img)), "1 of 24 pixels differ, by up to 2")

    def test_a_new_size_differs(self):
        self.assertEqual(cs.pixel_diff(png(picture()), png(picture((6, 5)))), "size 6x5, was 6x4")

    def test_every_icon_size_is_compared(self):
        def ico(img):
            buf = io.BytesIO()
            img.save(buf, "ICO", sizes=[(16, 16), (32, 32)])
            return buf.getvalue()
        big = picture((32, 32))
        self.assertEqual(len(cs.frames(ico(big))), 2)
        self.assertIsNone(cs.pixel_diff(ico(big), ico(big)))
        self.assertIsNotNone(cs.pixel_diff(ico(big), ico(picture((32, 32), (0, 0, 0, 255)))))


class FileDiff(unittest.TestCase):
    def test_manifest_key_order_does_not_matter(self):
        self.assertIsNone(cs.file_diff("m.json", b'{"a": 1, "b": 2}', b'{"b": 2, "a": 1}'))
        self.assertEqual(cs.file_diff("m.json", b'{"a": 1}', b'{"a": 2}'), "content differs")

    def test_every_sprite_tool_is_run(self):
        import glob
        import os
        tools = {os.path.basename(p) for p in glob.glob(os.path.join(cs.PROJECT, "tools", "make_*.py"))}
        # Sounds and the 3D car renders (Blender) are outside the sprite rebuild
        # (make_model_inputs only cuts the pictures for a model, into build/).
        expected = tools - {"make_audio.py", "make_car_renders.py", "make_model_inputs.py"}
        self.assertEqual({t[0] for t in cs.TOOLS}, expected)


if __name__ == "__main__":
    unittest.main()
