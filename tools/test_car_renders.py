"""Self-tests for the render-to-strip pass (make_car_renders.py, CP-1), on small made-up renders.

    python3 -m unittest discover -s tools -p "test_*.py"
"""
import os
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "blender"))

import car_looks  # noqa: E402
import make_car_renders as mcr
import make_model_inputs as mmi
import spritelib as sl

RED = (200, 30, 20, 255)


def render(size, box, color=RED):
    """A transparent render of `size` with `box` filled: a car standing in."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    img.paste(color, box)
    return img


class Pass(unittest.TestCase):
    def test_trim_cuts_to_the_car(self):
        self.assertEqual(mcr.trim(render((40, 30), (5, 8, 25, 20))).size, (20, 12))

    def test_trim_ignores_faint_alpha(self):
        img = render((40, 30), (5, 8, 25, 20))
        img.putpixel((0, 0), (255, 255, 255, mcr.ALPHA_CUT - 1))
        self.assertEqual(mcr.trim(img).size, (20, 12))

    def test_outline_darkens_the_edge_and_keeps_the_size(self):
        a = sl.rgba(mcr.outline(render((7, 7), (1, 1, 6, 6))))
        self.assertEqual(a.shape[:2], (7, 7))
        self.assertEqual(a[1, 3, :3].tolist(), [round(c * mcr.OUTLINE_DARKEN) for c in RED[:3]])
        self.assertEqual(a[3, 3].tolist(), list(RED))
        self.assertEqual(a[0, 0].tolist(), [0, 0, 0, 0])

    def test_quantize_shares_one_palette_and_keeps_alpha(self):
        a = render((10, 10), (0, 0, 5, 10), (250, 0, 0, 255))
        b = render((10, 10), (5, 0, 10, 10), (0, 0, 250, 255))
        out = mcr.quantize([a, b], colors=4)
        colors = set()
        for img in out:
            px = sl.rgba(img)
            colors |= {tuple(p[:3]) for p in px[px[..., 3] > 0]}
        self.assertLessEqual(len(colors), 4)
        self.assertEqual(sl.rgba(out[0])[0, 9, 3], 0)
        self.assertEqual(sl.rgba(out[1])[0, 9, 3], 255)

    def test_the_level_straight_frame_sets_the_scale(self):
        self.assertAlmostEqual(mcr.render_scale(render((400, 300), (100, 100, 300, 200)), 180), 0.9)


class Glass(unittest.TestCase):
    def test_a_hole_in_the_car_fills_with_glass_top_to_bottom(self):
        img = render((20, 20), (2, 2, 18, 18))
        img.paste((0, 0, 0, 0), (5, 5, 15, 15))
        a = sl.rgba(mcr.fill_glass(img))
        self.assertEqual(a[5, 10].tolist(), list(mcr.GLASS_TOP) + [255])
        self.assertEqual(a[14, 10].tolist(), list(mcr.GLASS_BOTTOM) + [255])
        self.assertEqual(a[3, 10].tolist(), list(RED), "the car itself is left alone")

    def test_clear_pixels_open_to_the_outside_stay_clear(self):
        img = render((20, 20), (2, 2, 18, 18))
        img.paste((0, 0, 0, 0), (8, 2, 12, 12))  # a notch from the top edge of the car
        a = sl.rgba(mcr.fill_glass(img))
        self.assertEqual(a[5, 10, 3], 0)
        self.assertEqual(a[0, 0, 3], 0)

    def test_a_car_with_no_holes_comes_back_the_same(self):
        img = render((20, 20), (2, 2, 18, 18))
        self.assertEqual(sl.rgba(mcr.fill_glass(img)).tolist(), sl.rgba(img).tolist())


class ContactShadow(unittest.TestCase):
    def car_with_pipes(self):
        """Tires down to row 37 at the edges, a tail pipe down to the bottom in the middle."""
        img = render((40, 40), (4, 4, 36, 24))
        for box in ((4, 24, 10, 38), (30, 24, 36, 38), (18, 24, 22, 40)):
            img.paste(RED, box)
        return img

    def test_the_shadow_fills_under_the_car_down_to_the_bottom(self):
        a = sl.rgba(mcr.contact_shadow(self.car_with_pipes()))
        self.assertEqual(a[39, 6].tolist(), list(mcr.CONTACT_SHADE), "under a tire")
        self.assertEqual(a[30, 14].tolist(), list(mcr.CONTACT_SHADE), "between tire and pipe")
        self.assertEqual(a[37, 6].tolist(), list(RED), "the tire stays")
        self.assertEqual(a[39, 20].tolist(), list(RED), "the pipe stays")

    def test_it_stops_at_the_car_near_the_ground_not_the_fenders(self):
        img = self.car_with_pipes()
        img.paste(RED, (0, 4, 4, 24))  # a fender out past the tires, up off the road
        a = sl.rgba(mcr.contact_shadow(img))
        self.assertEqual(a[39, 2, 3], 0)

    def test_nothing_in_the_band_nothing_added(self):
        img = render((40, 40), (4, 4, 36, 16))
        self.assertEqual(sl.rgba(mcr.contact_shadow(img)).tolist(), sl.rgba(img).tolist())


class Looks(unittest.TestCase):
    def test_the_bruisers_red_lamps_count_and_the_vegas_red_body_does_not(self):
        self.assertLess(car_looks.look("bruiser")["glow_green"][0], 0.0)
        self.assertGreater(car_looks.look("vega")["glow_green"][0], 0.0)

    def test_a_car_not_listed_gets_the_defaults(self):
        self.assertEqual(car_looks.look("nosuch"), car_looks.DEFAULTS)

    def test_every_look_sets_only_known_settings(self):
        for car, look in car_looks.LOOKS.items():
            self.assertLessEqual(set(look), set(car_looks.DEFAULTS), car)


class Strips(unittest.TestCase):
    def test_no_palette_cut_by_default_keeps_smooth_paint(self):
        self.assertEqual(mcr.COLORS, 0)
        with tempfile.TemporaryDirectory() as d:
            ramp = Image.new("RGBA", (400, 200), (0, 0, 0, 255))
            for x in range(400):
                ramp.paste((x // 2, 40, 200, 255), (x, 0, x + 1, 200))
            for p in mcr.PITCHES:
                for i in range(mcr.FRAMES):
                    ramp.save(os.path.join(d, "%s_%d.png" % (p, i)))
            path = mcr.make_strips(d, "test", os.path.join(d, "strips"))[0]
            px = sl.rgba(mcr.load(path))
            self.assertGreater(len({tuple(c[:3]) for c in px[px[..., 3] > 0]}), 64)

    def test_three_strips_of_seven_cells_at_one_scale(self):
        with tempfile.TemporaryDirectory() as d:
            for p in mcr.PITCHES:
                for i in range(mcr.FRAMES):
                    # A taller car nose-up, a wider one turned; the level straight one is 360 wide
                    h = {"level": 120, "up": 150, "down": 100}[p]
                    w = 360 + abs(i - 3) * 20
                    render((600, 400), (100, 300 - h, 100 + w, 300)).save(os.path.join(d, "%s_%d.png" % (p, i)))
            paths = mcr.make_strips(d, "test", os.path.join(d, "strips"))
            self.assertEqual([os.path.basename(p) for p in paths],
                             ["test_steer.png", "test_steer_up.png", "test_steer_down.png"])
            # Body width 180 at scale 0.5: the hardest turn is 420 wide in the render, 210 here
            self.assertEqual(mcr.load(paths[0]).size, (210 * 7, 60))
            self.assertEqual(mcr.load(paths[1]).height, 75)
            self.assertEqual(mcr.load(paths[2]).height, 50)


class ModelInputs(unittest.TestCase):
    def test_center_part_moves_the_part_to_the_middle_and_cleans_its_side(self):
        img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        img.paste((30, 60, 200, 255), (5, 10, 35, 30))  # the car, across x 5..34
        img.paste((250, 20, 20, 255), (24, 14, 30, 20))  # a part off to the right
        a = sl.rgba(mmi.center_part(img, (0.55, 0.3, 0.8, 0.55)))
        mid = 19
        self.assertEqual(a[17, mid, :3].tolist(), [250, 20, 20], "the part is on the middle")
        self.assertEqual(a[17, 28, :3].tolist(), [30, 60, 200], "its old place is body again")
        self.assertEqual(a[12, 28, :3].tolist(), [30, 60, 200])

    def test_views_cut_back_front_left_and_mirror_the_right(self):
        sheet = Image.new("RGB", (300, 100), (255, 0, 255))
        sheet.paste((200, 30, 20), (10, 30, 70, 80))  # back
        sheet.paste((30, 200, 20), (100, 30, 160, 80))  # front
        sheet.paste((20, 30, 200), (190, 40, 290, 80))  # side, nose left
        sheet.paste((250, 250, 250), (190, 40, 200, 80))  # a white nose
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "views.png")
            sheet.save(path)
            v = mmi.views(path)
        self.assertEqual(sorted(v), ["back", "front", "left", "right"])
        for img in v.values():
            self.assertEqual(img.width, img.height)
        self.assertEqual(sl.rgba(v["back"])[v["back"].height // 2, v["back"].width // 2, :3].tolist(), [200, 30, 20])
        self.assertEqual(sl.rgba(v["left"])[0, 0, 3], 0)
        # The white nose is on the left of the left view and the right of the right view
        row = v["left"].height // 2
        self.assertEqual(sl.rgba(v["left"])[row, v["left"].width // 2 - 45, :3].tolist(), [250, 250, 250])
        self.assertEqual(sl.rgba(v["right"])[row, v["right"].width // 2 + 44, :3].tolist(), [250, 250, 250])


if __name__ == "__main__":
    unittest.main()
