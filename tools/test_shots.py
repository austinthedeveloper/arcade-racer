"""tools/shots.py: a reference must be stored reduced, or a matching shot fails on its hash."""
import os
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import shots  # noqa: E402


def run(*args):
    return subprocess.run([sys.executable, os.path.join(HERE, "shots.py"), *args], capture_output=True, text=True)


class ReferenceSize(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rendered = os.path.join(self.tmp.name, "rendered")
        self.refs = os.path.join(self.tmp.name, "refs")
        os.makedirs(self.rendered)
        os.makedirs(self.refs)
        shot = Image.new("RGBA", (640, 360), (200, 120, 60, 255))
        for x in range(0, 640, 40):
            shot.paste((20, 30, 90, 255), (x, 0, x + 20, 360))
        shot.save(os.path.join(self.rendered, "menu_cars.png"))
        self.shot = shot

    def tearDown(self):
        self.tmp.cleanup()

    def test_a_reduced_reference_matches_its_shot(self):
        shots.reduce(self.shot).save(os.path.join(self.refs, "menu_cars.png"))
        r = run("compare", self.rendered, self.refs)
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_a_reference_copied_in_full_size_is_refused_by_name(self):
        # Regression: CI's artifact copied straight into tests/shots/ failed on 24 hash bits
        self.shot.save(os.path.join(self.refs, "menu_cars.png"))
        r = run("compare", self.rendered, self.refs)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("reference is 640x360", r.stdout)


if __name__ == "__main__":
    unittest.main()
