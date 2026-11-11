"""tools/playtest_report.py (EQ-25): a folder of playtest logs into a per-stage chart."""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import playtest_report  # noqa: E402

FIXTURES = os.path.join(os.path.dirname(HERE), "tests", "fixtures", "playtest")


class PlaytestReport(unittest.TestCase):
    def test_loads_the_logs_and_skips_the_rest(self):
        logs, skipped = playtest_report.load(FIXTURES)
        self.assertEqual(len(logs), 3)
        self.assertEqual(sorted(n for n, _ in skipped), ["broken.json", "notes.json"])

    def test_per_stage_stretches_and_crashes(self):
        stages = playtest_report.by_stage(playtest_report.load(FIXTURES)[0])
        self.assertEqual(playtest_report.ordered(stages), ["palm_coast", "redrock"])
        palm = stages["palm_coast"]
        self.assertEqual(palm["runs"], 2)
        self.assertEqual(palm["results"], {"finish": 1, "time_up": 1})
        self.assertAlmostEqual(palm["mean_lost"][1], 2.0)  # (1.8 + 2.2) / 2
        self.assertEqual(palm["crashes"], {1: 2, 3: 1})  # 25000 and 24100 in stretch 1, 61000 in 3
        self.assertEqual(palm["stretches"], 6)  # 100000 long in stretches of 20000, the line in the sixth
        self.assertEqual(playtest_report.worst(palm, 1), [(1, 2.0, 2)])
        self.assertEqual(palm["finish_times"], [71.5])

    def test_html_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = os.path.join(tmp, "r.html")
            self.assertEqual(playtest_report.main([FIXTURES, "--out=" + out]), 0)
            with open(out, encoding="utf-8") as f:
                text = f.read()
        self.assertIn("<h2>Palm Coast</h2>", text)
        self.assertIn("<h2>Redrock</h2>", text)
        self.assertIn("2 crashes", text)
        self.assertIn("stretch 1: 2.00 s lost", text)
        self.assertIn("Skipped: broken.json, notes.json", text)
        self.assertLess(text.index("Palm Coast"), text.index("Redrock"), "in stage order")

    def test_an_empty_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = os.path.join(tmp, "r.html")
            self.assertEqual(playtest_report.main([tmp, "--out=" + out]), 0)
            with open(out, encoding="utf-8") as f:
                self.assertIn("No playtest logs", f.read())
        self.assertEqual(playtest_report.main([os.path.join(FIXTURES, "nope")]), 1)

    def test_png_per_stage(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("no Pillow")
        stages = playtest_report.by_stage(playtest_report.load(FIXTURES)[0])
        with tempfile.TemporaryDirectory() as tmp:
            paths = playtest_report.write_pngs(stages, tmp)
            self.assertEqual([os.path.basename(p) for p in paths], ["playtest_palm_coast.png", "playtest_redrock.png"])
            with Image.open(paths[0]) as img:
                self.assertEqual(img.size, (760, 180))


if __name__ == "__main__":
    unittest.main()
